=head1 NAME

Prima::ThumbViewer - Browse a tree of image thumbnails from LPDB

=head1 DESCRIPTION

This class connects C<Prima::TileViewer> to an C<LPDB> database,
presenting its paths and pictures in an interactive thumbnail browser.

=cut

package Prima::LPDB::ThumbViewer;

use strict;
use warnings;
use LPDB::Tree;
use LPDB::Thumbnail;
use Prima::TileViewer;
use Prima::Image::Magick qw/:all/;

use vars qw(@ISA);
@ISA = qw(Prima::TileViewer);

# sub profile_default {
#     my $def = $_[0]-> SUPER::profile_default;
#     my %prf = (
# 	);
#     @$def{keys %prf} = values %prf;
#     return $def;
# }

sub init {
    my $self = shift;
    my(%hash) = @_;
    $self->{lpdb} = $hash{lpdb} or die "lpdb object required";
    $self->{tree} = new LPDB::Tree($self->{lpdb});
    $self->{thumb} = new LPDB::Thumbnail($self->{lpdb});
    my %profile = $self-> SUPER::init(@_);
#     $self->items([1 .. 20]);	# need active_columns to set smaller tile size
#     $self->focusedItem(10);
#     $self->smaller;
# #    $self->repaint;
    $self->items($self->children(1));
    $self->focusedItem(0);
    # $self->reset;
    # $self->smaller(8);
    # $self->reset;
    # $self->smaller(10);
    $self->repaint;
    # warn join "\n", map { $self->{$_} } qw/lpdb tree thumb items/, "\n";
    # my @foo = @{$self->{items}};
    # warn "items: @foo\n";
    return %profile;
}

sub children {
    my($self, $id) = @_;
    my @id;
    my($path, $file) = $self->{tree}->pathpics($id || 0);
    return [ @$path, @$file ];
    # TODO: option for dirs to be first/last/mixed with pics by name or date
}

# sub repaint {
#     $_[0]->bigger;
#     $_[0]->smaller;
#     $_[0]->SUPER::repaint;
# }

sub push {	   # navigation path: must push pairs of (focusedItem in path_id)
    push @{$_[0]->{navstack}}, $_[1], $_[2];
}
sub pop {
    return pop @{$_[0]->{navstack}};
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
	    $self->items($self->children($this->path_id));
	    $self->focusedItem(0);
	    $self->repaint;
	} elsif ($this->isa('LPDB::Schema::Result::Picture')) {
	    # show picture in other window and raise it
	}
	$self->clear_event;
	return;
    } elsif ($key == kb::Escape && @{$self->{navstack}} > 1) {
	$self->items($self->children($self->pop));
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
	: $pos == 1 ? ($x1 + $b + $dx, $y2 - $b - $dh) # NW
	: $pos == 2 ? ($x2 - $b - $dw, $y1 + $b + $dy) # SE
	: $pos == 3 ? (($x1 + $x2)/2 - $dw/2, ($y1 + $y2)/2 - $dh/2) # center
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
    my $first = $path->first;
    $thumb = $self->{thumb}->get($first->file_id);
    $thumb or return "warn: can't get thumb!\n";
    $im = magick_to_prima($thumb);
    my $b = $self->_draw_thumb($im, 1, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col);

    my $last = $path->last;
    unless ($first->file_id == $last->file_id) { # same if only one
	$thumb = $self->{thumb}->get($last->file_id);
	$thumb or return "warn: can't get thumb!\n";
	$im = magick_to_prima($thumb);
	$self->_draw_thumb($im, 2, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col);
    }
    # TODO: center/top picture is favorite from DB, if any
    $self->_draw_thumb($im, 3, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col);

    $canvas->textOpaque(!$b);
    $b += 5;			# now text border
    my $str = $path->path;
    $str =~ m{(.*/)(.+/?)};
    $canvas->draw_text($2, $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
		       dt::Left|dt::Top|dt::Default); # dt::VCenter

    $str = localtime($first->time) . ' - ' . localtime($last->time);
    $canvas->draw_text($str, $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
		       dt::Left|dt::Bottom|dt::Default); # dt::VCenter
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
    my $str = localtime $pic->time;
    $canvas->draw_text($str, $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
    		   dt::Right|dt::Top|dt::Default); # dt::VCenter
    $pic->caption and
	$canvas->draw_text($pic->caption, $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
			   dt::Left|dt::Bottom|dt::Default); # dt::VCenter
    $canvas->rect_focus( $x1, $y1, $x2, $y2 ) if $foc;
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
