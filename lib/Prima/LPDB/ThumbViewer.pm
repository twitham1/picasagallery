=head1 NAME

Prima::ThumbViewer - Browse a tree of image thumbnails from LPDB

=head1 DESCRIPTION

This class connects C<Prima::TileViewer> to an C<LPDB> database,
presenting its paths and pictures in an interactive thumbnail browser.
It also opens a C<Prima::LPDB::ImageViewer> to show the pictures.

=cut

package Prima::LPDB::ThumbViewer;

use strict;
use warnings;
use LPDB::Tree;
use LPDB::Thumbnail;
use Prima::TileViewer;
use Prima::FrameSet;
use Prima::Label;
use Prima::Image::Magick qw/:all/;
use POSIX qw/strftime/;
use Prima::LPDB::ImageViewer;

use vars qw(@ISA);
@ISA = qw(Prima::TileViewer);


sub lpdb { $_[0]->{lpdb} }
sub tree { $_[0]->{tree} }
sub thumb { $_[0]->{thumb} }
sub init {
    my $self = shift;
    my(%hash) = @_;
    $self->{lpdb} = $hash{lpdb} or die "lpdb object required";
    $self->{tree} = new LPDB::Tree($self->{lpdb});
    $self->{thumb} = new LPDB::Thumbnail($self->{lpdb});
    $self->{viewer} = undef;

# # Does this speed up thumbnail generation?  It might deadlock more than 1 run at a time
#     $self->{timer} = Prima::Timer->create(
# 	timeout => 3000, # milliseconds
# 	onTick => sub {
# 	    warn "tick!\n";
# 	    $self->{lpdb}->{tschema}->txn_commit;
# 	    $self->{lpdb}->{tschema}->txn_begin;
# 	}
# 	);
#     $self->{lpdb}->{tschema}->txn_begin;
# #    $self->{timer}->start;

    my %profile = $self-> SUPER::init(@_);
    $self->items($self->children(1));
    $self->focusedItem(-1);
    $self->focusedItem(0);
    $self->repaint;
    # warn join "\n", map { $self->{$_} } qw/lpdb tree thumb items/, "\n";
    # my @foo = @{$self->{items}};
    # warn "items: @foo\n";
    $self->selected(1);
    $self->focused(1);
    $self->select;
    return %profile;
}

sub children {
    my($self, $id) = @_;
    my @id;
    my($path, $file) = $self->{tree}->pathpics($id || 0);
    return [ @$path, @$file ];
    # TODO: option for dirs to be first/last/mixed with pics by name or date
}

sub push {	   # navigation path: must push pairs of (focusedItem in path_id)
    push @{$_[0]->{navstack}}, $_[1], $_[2];
}
sub pop {
    return pop @{$_[0]->{navstack}};
}

sub on_selectitem {		# update metadata labels
    my ($self, $idx, $state) = @_;
    my $x = $idx->[0] + 1;
    my $y = $self->count;
    my $this = $self->{items}[$idx->[0]];
    $self->owner->NORTH->NW->text($self->cwd);
    $self->owner->NORTH->NE->text("$x / $y");
    if ($this->isa('LPDB::Schema::Result::Path')) {
	$this->path =~ m{(.*/)(.+/?)};
	$self->owner->NORTH->N->text($2);
	my @p = $this->stack;
	$self->owner->SOUTH->SW->text(scalar localtime $p[0]->time);
	$self->owner->SOUTH->SE->text($p[2] ? scalar localtime $p[2]->time : '');
	$self->owner->SOUTH->S->text($this->picturecount);
    } elsif ($this->isa('LPDB::Schema::Result::Picture')) {
	$self->owner->NORTH->N->text($this->basename);
	$self->owner->SOUTH->SW->text(scalar localtime $this->time);
	$self->owner->SOUTH->SE->text('');
	$self->owner->SOUTH->S->text('');
    }
}
sub cwd {
    my($self, $cwd) = @_;
    $cwd and $self->{cwd} = $cwd;
    return $self->{cwd} || '/';
}
sub on_keydown
{
    my ($self, $code, $key, $mod) = @_;
    my $idx = $self->focusedItem;
    if ($key == kb::Enter && $idx >= 0) {
	my $this = $self->{items}[$idx];
	# warn $self->focusedItem, " is entered\n";
	if ($this->isa('LPDB::Schema::Result::Path')) {
	    $self->push($idx, $this->parent_id);
	    $self->cwd($this->path);
	    $self->items($self->children($this->path_id));
	    $self->focusedItem(-1);
	    $self->repaint;
	    $self->focusedItem(0);
	    $self->repaint;
	} elsif ($this->isa('LPDB::Schema::Result::Picture')) {
	    # show picture in other window and raise it
	    $self->viewer->IV->viewimage($this); # $this->pathtofile);
#	    $self->viewer;
	}
	$self->clear_event;
	return;
    } elsif ($key == kb::Escape && @{$self->{navstack}} > 1) {
	$self->cwd =~ m{(.*/)(.+/?)} and
	    $self->cwd($1);
	$self->items($self->children($self->pop));
	$self->focusedItem(-1);
	$self->repaint;
	$self->focusedItem($self->pop || 0);
	$self->repaint;
	$self->clear_event;
	return;
    }
    $self-> SUPER::on_keydown( $code, $key, $mod);
}
sub on_drawitem
{
    my $self = shift;
    my $this = $self->{items}[$_[1]];
    if ($this->isa('LPDB::Schema::Result::Path')) {
	$self->draw_path(@_);
    } elsif ($this->isa('LPDB::Schema::Result::Picture')) {
	$self->draw_picture(@_);
    }
}

# source -> destination, preserving aspect ratio
sub _draw_thumb {		# pos 0 = full size, pos 1,2,3 = picture stack
    my ($self, $im, $pos, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col) = @_;

    my $bk = $sel ? $self->hiliteBackColor : cl::Back;
    $bk = $self->prelight_color($bk) if $pre;
    $canvas->backColor($bk);
    $canvas->clear($x1, $y1, $x2, $y2) if $pos < 2; # 2 and 3 should stack
    $canvas->color($sel ? $self->hiliteColor : cl::Fore);

    my $dw = $x2 - $x1;
    my $b = $sel || $foc || $pre ? 0 : $dw / 30; # border
    $dw *= 2/3 if $pos;		# 2/3 size for picture stack
    my $dh = $y2 - $y1;
    $dh *= 2/3 if $pos;
    $dw -= $b * 2;
    $dh -= $b * 2;
    my($sw, $sh) = ($im->width, $im->height);
    my @out;
    my $src = $sw / $sh;	# aspect ratios
    my $dst = $dw / $dh;
    my $sx = my $sy = my $dx = my $dy = 0;
    # this copy is used for rectangle overlay in crop mode
    my($DX, $DY, $DW, $DH) = ($dx, $dy, $dw, $dh);
    if ($src > $dst) {		# image wider than cell: pad top/bot
	$DY = ($DH - $DW / $src) / 2;
	$DH = $DW / $src;
    } else {		      # image taller than cell: pad left/right
	$DX = ($DW - $DH * $src) / 2;
	$DW = $DH * $src;
    }
    if ($self->{crops}) {      # crop source to destination
	if ($src > $dst) {    # image wider than cell: crop left/right
	    $sx = ($sw - $sh * $dst) / 2;
	    $sw = $sh * $dst;
	} else {		# image taller than cell: crop top/bot
	    $sy = ($sh - $sw / $dst) / 2;
	    $sh = $sw / $dst;
	}
    } else {			# pad source to destination
	($dx, $dy, $dw, $dh) = ($DX, $DY, $DW, $DH);
    }
    my ($x, $y) = (
	$pos   == 0 ? ($x1 + $b + $dx, $y1 + $b + $dy) # full picture
	: $pos == 1 ? ($x1 + $b, $y2 - $b - $dh) # North West
	: $pos == 2 ? (($x1 + $x2)/2 - $dw/2, ($y1 + $y2)/2 - $dh/2) # center
	: $pos == 3 ? ($x2 - $b - $dw, $y1 + $b) # South East
	: ($x1, $y1));		# should never happen
    $canvas->put_image_indirect($im, $x, $y, $sx, $sy, $dw, $dh, $sw, $sh,
				$self->rop)
	or warn "put_image failed: $@";
    if (!$pos and !$b) {       # overlay rectangle on focused pictures
        my ($x, $y, $w, $h);
        if ($self->{crops}) {	      # show original aspect rectangle
	    $canvas->color(cl::LightRed); # cropped portion
	    $canvas->rectangle($x1 + $DX, $y1 + $DY,
			       $x1 + $DX + $DW, $y1 + $DY + $DH);
	    $canvas->color(cl::Fore);
        }
        # TODO: fix this!!! It is right only for square thumbs:
        ($x, $w) = $DY ? ($DY, $DH) : ($DX, $DW);
        ($y, $h) = $DX ? ($DX, $DW) : ($DY, $DH);
        $canvas->rectangle($x1 + $x, $y1 + $y,
			   $x1 + $x + $w, $y1 + $y + $h);
    }
    return $b;
}
sub draw_path {
    my ($self, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col) = @_;

    my ($thumb, $im);
    my $path = $self->{items}[$idx];
    # my $first = $path->first;
    # $thumb = $self->{thumb}->get($first->file_id);
    # $thumb or return "warn: can't get thumb!\n";
    # $im = magick_to_prima($thumb);
    # my $b = $self->_draw_thumb($im, 1, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col);

    # my $last = $path->last;
    # unless ($first->file_id == $last->file_id) { # same if only one
    # 	$thumb = $self->{thumb}->get($last->file_id);
    # 	$thumb or return "warn: can't get thumb!\n";
    # 	$im = magick_to_prima($thumb);
    # 	$self->_draw_thumb($im, 2, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col);
    # }

    my $b = 0;			# border size
    my @where = (1, 2, 3);
    my($first, $last);
    for my $pic ($path->stack) {
	my $where = shift @where;
	$pic or next;
	my $thumb = $self->{thumb}->get($pic->file_id);
	$thumb or next;
	$first or $first = $pic;
	$last = $pic;
	$im = magick_to_prima($thumb);
	$b = $self->_draw_thumb($im, $where, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col);
    }

    # # TODO: center/top picture is favorite from DB, if any, or cycling random!
    # $self->_draw_thumb($im, 3, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col);

    $canvas->textOpaque(!$b);
    $b += 5;			# now text border
    my $n = $path->picturecount;
    my $str = $path->path;
    $str =~ m{(.*/)(.+/?)};
    $canvas->draw_text("$2\n$n", $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
		       dt::Right|dt::Top|dt::Default);

    # $canvas->draw_text($n, $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
    # 		       dt::Center|dt::VCenter|dt::Default);
    
    $str = strftime("%b %d %Y", localtime $first->time);
    my $end = strftime("%b %d %Y", localtime $last->time);
    $str eq $end or $str .= "\n$end";
    $canvas->draw_text($str, $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
		       dt::Left|dt::Bottom|dt::Default);
    $canvas->rect_focus( $x1, $y1, $x2, $y2 ) if $foc;
}
sub draw_picture {
    my ($self, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col) = @_;

    my $pic = $self->{items}[$idx];
    my $thumb = $self->{thumb}->get($pic->file_id);
    $thumb or return "warn: can't get thumb!\n";
    my $im = magick_to_prima($thumb);
    my $b = $self->_draw_thumb($im, 0, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col);

    $canvas->textOpaque(!$b);
    $b += 5;			# now text border
    # my $str = sprintf "%s\n%dx%d", $pic->basename,
    #     $pic->width, $pic->height;
    # my $str = localtime $pic->time;
    # $canvas->draw_text($str, $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
    # 		   dt::Right|dt::Top|dt::Default); # dt::VCenter
    $pic->caption and
	$canvas->draw_text($pic->caption, $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
			   dt::Center|dt::Bottom|dt::Default); # dt::VCenter
    $canvas->rect_focus( $x1, $y1, $x2, $y2 ) if $foc;
}

# TODO, move this to ImageViewer or ImageWindow or somewhere?

sub viewer {		 # reuse existing image viewer, or recreate it
    my $self = shift;
    if ($self and $self->{viewer} and
	Prima::Object::alive($self->{viewer})) {
	$self->{viewer}->restore
	    if $self->{viewer}->windowState == ws::Minimized;
    } else {
#	$self->{viewer} = Prima::LPDB::ImageViewer->create;
	my $w = $self->{viewer} = Prima::Window->create(
	    text => 'Image Viewer',
	    #	    size => [$::application->size],
	    size => [1600, 900],
#	    selectable => 1,
	    );
	$w->insert(
	    'Prima::LPDB::ImageViewer',
	    name => 'IV',
	    thumbviewer => $self,
	    pack => { expand => 1, fill => 'both' },
	    #    growMode => gm::Client,
	    );
	$w->insert('Prima::Label', name => 'NW', autoHeight => 1,
		   left => 25, top => $w->height - 25,
		   growMode => gm::GrowLoY,
		   text => "north west",
	    );
	$w->insert('Prima::Label', name => 'NE', autoHeight => 1,
		   right => $w->width - 50, top => $w->height - 25,
		   growMode => gm::GrowLoX|gm::GrowLoY,
#		   alignment => ta::Right,
		   text => "north east",
	    );
	$w->insert('Prima::Label', name => 'SE', autoHeight => 1,
		   right => $w->width - 50, bottom => 25,
		   growMode => gm::GrowLoX,
		   text => "south east",
	    );
	$w->insert('Prima::Label', name => 'SW', autoHeight => 1,
		   left => 25, bottom => 25,
		   text => "south west",
	    );
	$w->insert('Prima::Label', name => 'N', autoHeight => 1,
		   left => $w->width / 2, top => $w->height - 25,
		   growMode => gm::XCenter|gm::GrowLoY,
		   alignment => ta::Center,
		   text => "north",
	    );
	$w->insert('Prima::Label', name => 'S', autoHeight => 1,
		   left => $w->width / 2, bottom => 25,
		   growMode => gm::XCenter,
		   alignment => ta::Center,
		   text => "south",
	    );
    }
#    $self->{viewer}->maximize;	# 
    $self->{viewer}->select;
    $self->{viewer}->repaint;
    $self->{viewer};
}

1;

=pod

=back

=head1 SEE ALSO
L<Prima::TileViewer>, L<LPDB>

=head1 AUTHOR

Timothy D Witham <twitham@sbcglobal.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2013-2022 Timothy D Witham.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
