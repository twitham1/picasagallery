=head1 NAME

Prima::LPDB::ThumbViewer - Browse a tree of image thumbnails from LPDB

=head1 DESCRIPTION

The heart of C<lpgallery>, this class connects C<Prima::TileViewer> to
an C<LPDB> database, presenting its paths and pictures in a keyboard-
driven interactive thumbnail browser.  It also [re]creates a
C<Prima::LPDB::ImageViewer> to display a selected picture.

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
use Prima::Fullscreen;

use vars qw(@ISA);
@ISA = qw(Prima::TileViewer Prima::Fullscreen);

my $lv;
sub profile_default
{
    my $def = $_[ 0]-> SUPER::profile_default;
    my %prf = (
	popupItems => [
	    ['navto' => '~Navigate To' => [
		 # replaced by on_selectitem
		 ['/[Folders]/' => '/[Folders]/' => 'goto'],
	     ]],
	    ['~Sort' => [
		 ['~Paths' => [
		      ['*(pname' => '~Name' => 'sorter'],
		      ['pfirst' => '~First Time' => 'sorter'],
		      ['pmid' => '~Middle Time' => 'sorter'],
		      [')plast' => '~Last Time' => 'sorter'],
		      [],
		      ['*(pasc' => '~Ascending' => 'sorter'],
		      [')pdsc' => '~Descending' => 'sorter'],
		  ]],
		 ['~Gallery Groups' => [
		      ['(gname' => '~Name' => 'sorter'],
		      ['*gfirst' => '~First Time' => 'sorter'],
		      ['glast' => '~Last Time' => 'sorter'],
		      [')gskip' => '~Ungrouped' => 'sorter'],
		      [],
		      ['*(aasc' => '~Ascending' => 'sorter'],
		      [')adsc' => '~Descending' => 'sorter'],
		  ]],
		 ['~Images' => [
		      ['(iname' => '~Name' => 'sorter'],
		      ['*)itime' => '~Time' => 'sorter'],
		      [],
		      ['*(iasc' => '~Ascending' => 'sorter'],
		      [')idsc' => '~Descending' => 'sorter'],
		  ]],
		 ['~Mixed Folders' => [
		      ['*(galsfirst' => '~Galleries First' => 'sorter'],
		      [')picsfirst' => '~Images First' => 'sorter'],
		  ]],

	     ]],
	    [],
	    ['fullscreen', '~Full Screen', 'f', ord 'f' =>
	     sub { $_[0]->fullscreen($_[0]->popup->toggle($_[1]) )}],
	    ['bigger', 'Zoom ~In', 'z', ord 'z' =>
	     sub { $_[0]->bigger }],
	    ['smaller', 'Zoom ~Out', 'q', ord 'q' =>
	     sub { $_[0]->smaller }],
	    [],
	    ['*@croppaths', 'Crop ~Paths', 'Ctrl+Shift+T',
	     km::Ctrl | km::Shift | ord('t') => sub { $_[0]->repaint }],
	    ['@cropimages', 'Crop ~Images', 'Ctrl+E',
	     km::Ctrl | ord('e') => sub { $_[0]->repaint }],
	    [],
	    ['quit', '~Quit', 'Ctrl+Q', '^q' => sub { $::application->close }],
	    # ['quit', '~Quit', 'Ctrl+Q', '^q' => \&myclose ],
	]);
    @$def{keys %prf} = values %prf;
    return $def;
}
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

    # This appears to speed up thumbnail generation, but it might
    # deadlock more than 1 run at a time, a case I never have
    $self->{timer} = Prima::Timer->create(
    	timeout => 5000,	# milliseconds
    	onTick => sub {
    	    # warn "tick!\n";
    	    $self->{lpdb}->{tschema}->txn_commit;
    	    $self->{lpdb}->{tschema}->txn_begin;
    	}
    	);
    $self->{lpdb}->{tschema}->txn_begin;
    $self->{timer}->start;

    my %profile = $self->SUPER::init(@_);

    $self->insert('Prima::Fullscreen', window => $self->owner);

    $self->packForget; # to get packs around the perimeter of the SUPER widget

    my $top = $self->owner->insert('Prima::Label', name => 'NORTH', text => '',
				   transparent => 1, # hack, using label as container
				   pack => { side => 'top', fill => 'x', pad => 5 });
    $top->insert('Prima::Label', name => 'NW', pack => { side => 'left' },
		 text => 'Hit M for Menu');
    $top->insert('Prima::Label', name => 'NE', pack => { side => 'right' },
		 text => 'Enter = select / Escape = back');
    $top->insert('Prima::Label', name => 'N', pack => { side => 'top' },
		 text => 'Use arrow keys to navigate');

    $self->pack(expand => 1, fill => 'both');

    my $bot = $self->owner->insert('Prima::Label', name => 'SOUTH', text => '',
				   transparent => 1, # hack, using label as container
				   pack => { side => 'bottom', fill => 'x', pad => 5 });
    $bot->insert('Prima::Label', name => 'SW', pack => { side => 'left' },
		 text => 'beginning date and time');
    $bot->insert('Prima::Label', name => 'SE', pack => { side => 'right' },
		 text => 'gallery: physical path of images');
    $bot->insert('Prima::Label', name => 'S', pack => { side => 'bottom' },
		 text => 'statistics');

    $self->items($self->children('/'));
    $self->focusedItem(0);
    $self->repaint;
    # $self->selected(1);
    # $self->focused(1);
    $self->select;
    return %profile;
}

sub sorter {	    # applies current sort/filter via children of goto
    my($self, $name, $val) = @_;
    $self->goto($self->current);
}

sub children {			# return children of given text path
    my($self, $parent) = @_;
    my $m = $self->popup;
    my @sort;		      # menu sort options to database order_by
    $m->checked('gname') and push @sort,
    { ($m->checked('gdsc') ? '-desc' : '-asc') => 'dir.directory' };
    $m->checked('gfirst') and push @sort,
    { ($m->checked('gdsc') ? '-desc' : '-asc') => 'dir.begin' },
    { '-asc' => 'dir.directory' };
    $m->checked('glast') and push @sort,
    { ($m->checked('gdsc') ? '-desc' : '-asc') => 'dir.end' },
    { '-asc' => 'dir.directory' };
    # else gskip sorts by files only:
    $m->checked('itime') and push @sort,
    { ($m->checked('idsc') ? '-desc' : '-asc') => 'me.time' };
    $m->checked('iname') and push @sort,
    { ($m->checked('idsc') ? '-desc' : '-asc') => 'me.basename' };
    my($path, $file) = $self->{tree}->pathpics($parent || '/', \@sort);
    my @path = sort {		# sort paths per menu selection
    	($m->checked('pname') ? $a->path cmp $b->path : 0) ||
    	    ($m->checked('pfirst') ? $a->time(0) <=> $b->time(0) : 0) ||
    	    ($m->checked('pmid') ? $a->time(1) <=> $b->time(1) : 0) ||
    	    ($m->checked('plast') ? $a->time(2) <=> $b->time(2) : 0)
    } @$path;
    @path = reverse @path if $m->checked('pdsc');
    return [ $m->checked('picsfirst') ? (@$file, @path) : (@path, @$file) ];
}

sub goto {  # for robot navigation (slideshow) also used by escape key
    my($self, $path) = @_;
    # warn "goto: $path";
    $path =~ m{(.*/)/(.+/?)} or	   # path // pathtofile
	$path =~ m{(.*/)(.+/?)} or # path / basename
	warn "bad path $path" and return;
    $self->cwd($1);
    $self->items($self->children($1));
    $self->focusedItem(-1);
    $self->repaint;
    $self->focusedItem(0);
    my $n = $self->count;
    for (my $i = 0; $i < $n; $i++) { # select myself in parent
	if ($self->{items}[$i]->pathtofile eq $2) {
	    $self->focusedItem($i);
	    last;
	}
    }
    $self->repaint;
}

sub current {			# path to current selected item
    my($self) = @_;
    $self->focusedItem < 0 and return '/';
    my $this = $self->{items}[$self->focusedItem];
    $self->cwd . ($this->basename =~ m{/$} ? $this->basename
		  : '/' . $this->pathtofile);
}

sub _trimfile { (my $t = $_) =~ s{//.*}{}; $t }
sub on_selectitem { # update metadata labels, later in front of earlier
    my ($self, $idx, $state) = @_;
    my $x = $idx->[0] + 1;
    my $y = $self->count;
    my $p = sprintf '%.0f', $x / $y * 100;
    my $this = $self->{items}[$idx->[0]];
    my $id = 0;			# file_id of image only, for related
    $self->owner->NORTH->NW->text($self->cwd);
    $self->owner->NORTH->NE->text("$p% = $x / $y");
    if ($this->isa('LPDB::Schema::Result::Path')) {
	$this->path =~ m{(.*/)(.+/?)};
	$self->owner->NORTH->N->text($2);
	my @p = $this->stack;
	my $span = $p[2] ? $p[2]->time - $p[0]->time : 1;
	my $len =
	    $span > 3*365*86400 ? sprintf('%.0f years',  $span / 365 / 86400)
	    : $span > 90 *86400 ? sprintf('%.0f months', $span/30.4375/86400)
	    : $span > 48 * 3600 ? sprintf('%.0f days',   $span / 86400)
	    : $span >      3600 ? sprintf('%.0f hours',  $span / 3600)
	    : $span >        60 ? sprintf('%.0f minutes', $span / 60)
	    : '1 minute';
	my $n = $this->picturecount;
	my $p = $n > 1 ? 's' : '';
	$self->owner->SOUTH->S->text("$n image$p in $len");
	$self->owner->SOUTH->SE->text($p[2] ? scalar localtime $p[2]->time : '  ');
	$self->owner->SOUTH->SW->text(scalar localtime $p[0]->time);
    } elsif ($this->isa('LPDB::Schema::Result::Picture')) {
	$self->owner->NORTH->N->text($this->basename);
	$self->owner->SOUTH->SE->text($this->dir->directory);
	$self->owner->SOUTH->S->text(sprintf '%dx%d=%.2f  %.1fMP %.0fKB',
				     $this->width , $this->height,
				     $this->width / $this->height,
				     $this->width * $this->height / 1000000,
				     $this->bytes / 1024);
	$self->owner->SOUTH->SW->text(scalar localtime $this->time);
	$id = $this->file_id;
    }
    my $me = $self->current;
    $self->popup->submenu('navto',
			  [ map { [ $me eq $_ ? "*$_" : $_,
				    _trimfile($_), 'goto' ] }
			    $self->{tree}->related($me, $id) ]);
}

sub cwd {
    my($self, $cwd) = @_;
    $cwd and $self->{cwd} = $cwd;
    return $self->{cwd} || '/';
}

sub on_keydown
{
    my ($self, $code, $key, $mod) = @_;
#    warn "keydown  @_";
    my $idx = $self->focusedItem;
    if ($key == kb::Enter && $idx >= 0) {
	my $this = $self->{items}[$idx];
	# warn $self->focusedItem, " is entered\n";
	if ($this->isa('LPDB::Schema::Result::Path')) {
	    $self->cwd($this->path);
	    $self->items($self->children($this->path));
	    $self->focusedItem(-1);
	    $self->repaint;
	    $self->focusedItem(0);
	    $self->repaint;
	} elsif ($this->isa('LPDB::Schema::Result::Picture')) {
	    # show picture in other window and raise it
	    $self->viewer->IV->viewimage($this);
	}
	$self->clear_event;
	return;
    } elsif ($key == kb::Escape) {
	$self->goto($self->cwd);
	$self->clear_event;
	return;
    }
    if ($code == ord 'm' or $code == ord '?' or $code == 13) { # popup menu
	my @sz = $self->size;
	$self->popup->popup(50, $sz[1] - 50); # near top left
	return;
    }
    if ($code == 5) {		# ctrl-e = crops, in menu
	$self->key_down(ord 'c');
	return;
    }
    $self->SUPER::on_keydown( $code, $key, $mod);
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
    if ($pos and $self->popup->checked('croppaths') or
	!$pos and $self->popup->checked('cropimages')) {
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
        if ($self->popup->checked('cropimages')) { # show aspect rectangle
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
    my $str = $pic->width > 1.8 * $pic->height ? '==' # wide / portrait flags
	: $pic->width < $pic->height ? '||' : '';
    $str and
	$canvas->draw_text($str, $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
			   dt::Right|dt::Top|dt::Default);
    $pic->caption and
	$canvas->draw_text($pic->caption, $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
			   dt::Center|dt::Bottom|dt::Default); # dt::VCenter
    $canvas->rect_focus( $x1, $y1, $x2, $y2 ) if $foc;
}

# TODO, move this to ImageViewer or ImageWindow or somewhere?

sub viewer {		 # reuse existing image viewer, or recreate it
    my $self = shift;
    my $iv;
    if ($self and $self->{viewer} and
	Prima::Object::alive($self->{viewer})) {
	$self->{viewer}->restore
	    if $self->{viewer}->windowState == ws::Minimized;
    } else {
	my $w = $self->{viewer} = Prima::Window->create(
	    text => 'Image Viewer',
	    #	    size => [$::application->size],
	    # packPropagate => 0,
	    size => [1600, 900],
	    );
	$w->insert(
	    'Prima::LPDB::ImageViewer',
	    name => 'IV',
	    thumbviewer => $self,
	    pack => { expand => 1, fill => 'both' },
	    # growMode => gm::Client,
	    );
	$w->repaint;
	my $conf = $main::conf || {}; # set by main program
	if ($conf->{imageviewer}) {   # optional startup configuration
	    &{$conf->{imageviewer}}($self->{viewer}->IV);
	}
    }
    # $self->{viewer}->select;
    $self->{viewer}->bring_to_front;
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
