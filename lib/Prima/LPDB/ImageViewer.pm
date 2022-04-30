=head1 NAME

Prima::LPDB::ImageViewer - ImageViewer for Prima::LPDB::ThumbViewer

=head1 DESCRIPTION

Like C<Prima::ImageViewer> but with a keyboard driven interface for
C<LPDB>.  A single window is reused to show many images over time and
overlay with metadata.

=cut

package Prima::LPDB::ImageViewer;

use strict;
use warnings;
use Prima::ImageViewer;
use Image::Magick;
use Prima::Image::Magick qw/:all/;
use Prima::Fullscreen;

use vars qw(@ISA);
@ISA = qw(Prima::ImageViewer Prima::Fullscreen);

sub profile_default
{
    my $def = $_[ 0]-> SUPER::profile_default;
    my %prf = (
	size => [1600, 900],
	selectable => 1,
	name => 'IV',
	valignment  => ta::Middle,
	alignment   => ta::Center,
	autoZoom => 1,
	stretch => 0,
	info => 0,
	overlay => 0,
#	buffer => 1,
	popupItems => [
	    ['~Escape' => sub { $_[0]->key_down(0, kb::Escape) } ],
	    ['info', '~Info', 'i', ord 'i' =>
	     sub { $_[0]->info($_[0]->popup->toggle($_[1]) ) }],
	    ['overlay', '~Overlay', 'o', ord 'o' =>
	     sub { $_[0]->overlay($_[0]->popup->toggle($_[1]) ) }],
	    ['~Zoom' => [
		 ['fullscreen', '~Full Screen', 'f', ord 'f' =>
		  sub { $_[0]->fullscreen($_[0]->popup->toggle($_[1]) )} ],
		 # ['*autozoom', '~Auto Zoom', 'a', ord 'a' =>
		 #  sub { $_[0]->autoZoom($_[0]->popup->toggle($_[1]) )} ],
		 ['bigger', 'Zoom ~In', 'z', ord 'z' =>
		  sub { $_[0]->key_down(0, kb::Prior ) }],
		 ['smaller', 'Zoom ~Out', 'q', ord 'q' =>
		  sub { $_[0]->key_down(0, kb::Next ) }],
	     ]],
	]);
    @$def{keys %prf} = values %prf;
    return $def;
}

sub init {
    my $self = shift;
    my %profile = $self->SUPER::init(@_);
    my @opt = qw/Prima::Label autoHeight 1/;

    $self->{thumbviewer} = $profile{thumbviewer}; # object to return focus to

    $self->insert('Prima::Fullscreen', window => $self->owner);

    my $top = $self->insert(@opt, name => 'NORTH', text => ' ',
			    transparent => 1, # hack, using label as container
    			    pack => { side => 'top', fill => 'x', pad => 25 });
    $top->insert(@opt, name => 'NW', pack => { side => 'left' });
    $top->insert(@opt, name => 'NE', pack => { side => 'right' });
    $top->insert(@opt, name => 'N', pack => { side => 'top' });

    my $bot = $self->insert(@opt, name => 'SOUTH', text => ' ',
			    transparent => 1, # hack, using label as container
    			    pack => { side => 'bottom', fill => 'x', pad => 25 });
    $bot->insert(@opt, name => 'SW', pack => { side => 'left', anchor => 's' });
    $bot->insert(@opt, name => 'SE', pack => { side => 'right', anchor => 's' });
    $bot->insert(@opt, name => 'S', pack => { side => 'bottom', anchor => 's' });

    $self->info;		# set info visibility
    return %profile;
}

sub picture { $_[0]->{picture} || undef }
sub viewimage
{
    my ($self, $picture) = @_;
    my $filename = $picture->pathtofile or return;
    my $i = Image::Magick->new;
    my $e = $i->Read($filename);
    if ($e) {
    	warn $e;      # opts are last-one-wins, so we override colors:
    	$i = Image::Magick->new(qw/magick png24 size 320x320/,
    				qw/background red fill white gravity center/);
    	$i->Read("caption:$e");	# put error message in the image
    }
    $i->AutoOrient;		# automated rot fix via EXIF!!!

    if ($self->overlay) {
	$self->alignment($self->alignment == ta::Left ? ta::Right : ta::Left);
	$self->valignment($self->valignment == ta::Top ? ta::Bottom : ta::Top);
    } else {
	$self->valignment(ta::Middle);
	$self->alignment(ta::Center);
    }
    $self->image(magick_to_prima($i));
    $self->{picture} = $picture;
    $self->{fileName} = $filename;
    $self->autoZoom(1);
    $self->apply_auto_zoom;
    $self->repaint;
    $self->selected(1);
    $self->focused(1);
    $self->status;
}

sub on_size {
    my $self = shift;
    #    $self->font->height($self->width/50); # hack?!!!
    $self->apply_auto_zoom if $self->autoZoom;
}

sub overlay {
    my($self, $on) = @_;
    $self->{overlay} = $on
	if defined $on;
    $self->{overlay};
}

sub info {
    my($self, $on) = @_;
    $self->{info} = $on
	if defined $on;
    if ($self->{info}) {
	$self->NORTH->show;
	$self->SOUTH->show;
    } else {
	$self->NORTH->hide;
	$self->SOUTH->hide;
    }
    $self->{info};
}

sub on_paint { # update metadata label overlays, later in front of earlier
    my($self, $canvas) = @_;
    $self->SUPERon_paint(@_);	# hack!!! see below!!!
    my $im = $self->image or return;
    $im = $self->picture or return;
    my $th = $self->{thumbviewer};
    my $x = $th->focusedItem + 1;
    my $y = $th->count;
    $self->NORTH->N->text($self->picture->basename);
    $self->NORTH->NW->text(sprintf("%.0f%% of %dx%d=%.2f",
				   $self->zoom * 100,
				   $im->width, $im->height,
				   $im->width / $im->height));
    $self->NORTH->NE->text(sprintf '%.1fMP %.0fKB %d / %d',
			   $im->width * $im->height / 1000000,
			   $im->bytes / 1024,
			   $x, $y);
    if ($self->picture->caption) {
	$self->SOUTH->S->text($self->picture->caption);
	$self->SOUTH->S->show;
    } else {
	$self->SOUTH->S->text('');
	$self->SOUTH->S->hide;
    }
    # (my $path = $self->picture->dir->directory) =~ s{.*/(.+/)}{$1};
    (my $path = $self->picture->dir->directory) =~s{/}{\n}g;
    $self->SOUTH->SE->text($path);
    $self->SOUTH->SW->text(scalar localtime $self->picture->time);
}

sub on_close {
    my $owner = $_[0]->{thumbviewer};
    $owner or return;
    $owner->selected(1);
    $owner->focused(1);
#    $owner->owner->restore;
    $owner->owner->select;
}
sub on_keydown
{
    my ( $self, $code, $key, $mod) = @_;

    if ($key == kb::Enter) {
	$self->autoZoom(!$self->autoZoom);
	if ($self->autoZoom) {
	    $self->apply_auto_zoom;
	} else {
	    $self->zoom(1);	# scroll to center:
	    my @sz = $self->image->size;
	    my @ar = $self->get_active_area(2);
	    $self->deltaX($sz[0]/2 - $ar[0]/2);
	    $self->deltaY($sz[1]/2 - $ar[1]/2);
	}
	$self->repaint;
	return;
    }
    if ($key == kb::Prior) {
	$self->autoZoom(0);
	$self->zoom($self->zoom * 1.2);
	return;
    }
    if ($key == kb::Next) {
	$self->autoZoom(0);
	$self->zoom($self->zoom / 1.2);
	return;
    }
    if ($key == kb::Escape) {	# return focus to caller
	my $owner = $self->{thumbviewer};
	$owner->selected(1);
	$owner->focused(1);
#	$owner->owner->restore;
	$owner->owner->select;
	$owner->owner->onTop(1)
	    if $owner->fullscreen; # hack!!!! can't get Fullscreen to do it...
	return;
    }
    if ($code == ord 'm' or $code == ord '?' or $code == 13) { # popup menu
	my @sz = $self->size;
	$self->popup->popup($sz[0]/2, $sz[1]/2);
	return;
    }
   if ($code == 9) {		# ctrl-i = info toggle, in menu
	$self->key_down(ord 'i');
    }
    # if ($key == kb::F11) {
    # 	warn "f11 hit";
    # 	$self->fullscreen(!$self->fullscreen);
    # }

    return if $self->{stretch};

    my $c = $code & 0xFF;
    return unless $c >= ord '0' and $c <= ord '9'
	or grep { $key == $_ } (
	kb::Left, kb::Right, kb::Down, kb::Up,
    );

    if ($self->autoZoom) {	# navigate both windows
	my $th = $self->{thumbviewer};
	$th->key_down($code, $key);
	my $idx = $th->focusedItem;
	my $this = $th->{items}[$idx];
	if ($this->isa('LPDB::Schema::Result::Path')) {
	    warn "this node is a path $idx";
	    #    my ($self, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col) = @_;
	    # Prima::LPDB::ThumbViewer::draw_path($self, $self, $idx, 5, 5, 200, 200, 0, 0, 0, 0);
	    # $self->draw_path($self, $idx, 5, 5, 200, 200, 0, 0, 0, 0);
	    $self->key_down($code, kb::Escape);
	} else {
	    $th->key_down($code, kb::Enter);
	}
	$self->clear_event;
	return;
    }

    my $xstep = int($self-> width  / 5) || 1;
    my $ystep = int($self-> height / 5) || 1;

    my ($dx, $dy) = $self-> deltas;

    $dx += $xstep if $key == kb::Right;
    $dx -= $xstep if $key == kb::Left;
    $dy += $ystep if $key == kb::Down;
    $dy -= $ystep if $key == kb::Up;
    $self-> deltas($dx, $dy);
}

sub status
{
    my($self) = @_;
    my $w = $self->owner;
    my $img = $self->image;
    my $str;
    if ($img) {
	$str = $self->{fileName};
	$str =~ s/([^\\\/]*)$/$1/;
	$str = sprintf("%s (%dx%dx%d bpp)", $1,
		       $img->width, $img->height, $img->type & im::BPP);
    } else {
	$str = '.Untitled';
    }
    $w->text($str);
    $w->name($str);
}

# !!! hack !!! this copy from SUPER tweaked only to support image
# !!! {overlay} mode.  This option should be in SUPER instead.
sub SUPERon_paint
{
	my ( $self, $canvas) = @_;
	my @size   = $self-> size;

	$self-> rect_bevel( $canvas, Prima::rect->new(@size)->inclusive,
		width  => $self-> {borderWidth},
		panel  => 1,
		fill   => $self-> {image} ? undef : $self->backColor,
	);
	return 1 unless $self->{image};

	my @r = $self-> get_active_area( 0, @size);
	$canvas-> clipRect( @r);
	$canvas-> translate( @r[0,1]);
	my $imY  = $self-> {imageY};
	my $imX  = $self-> {imageX};
	my $z = $self-> {zoom};
	my $imYz = int($imY * $z);
	my $imXz = int($imX * $z);
	my $winY = $r[3] - $r[1];
	my $winX = $r[2] - $r[0];
	my $deltaY = ($imYz - $winY - $self-> {deltaY} > 0) ? $imYz - $winY - $self-> {deltaY}:0;
	my ($xa,$ya) = ($self-> {alignment}, $self-> {valignment});
	my ($iS, $iI) = ($self-> {integralScreen}, $self-> {integralImage});
	my ( $atx, $aty, $xDest, $yDest);

	if ( $self->{stretch}) {
		$atx = $aty = $xDest = $yDest = 0;
		$imXz = $r[2] - $r[0];
		$imYz = $r[3] - $r[1];
		goto PAINT;
	}

	if ( $imYz < $winY) {
		if ( $ya == ta::Top) {
			$aty = $winY - $imYz;
		} elsif ( $ya != ta::Bottom) {
			$aty = int(($winY - $imYz)/2 + .5);
		} else {
			$aty = 0;
		}
		unless ($self->{overlay}) {
		    $canvas-> clear( 0, 0, $winX-1, $aty-1) if $aty > 0;
		    $canvas-> clear( 0, $aty + $imYz, $winX-1, $winY-1) if $aty + $imYz < $winY;
		}
		$yDest = 0;
	} else {
		$aty   = -($deltaY % $iS);
		$yDest = ($deltaY + $aty) / $iS * $iI;
		$imYz = int(($winY - $aty + $iS - 1) / $iS) * $iS;
		$imY = $imYz / $iS * $iI;
	}

	if ( $imXz < $winX) {
		if ( $xa == ta::Right) {
			$atx = $winX - $imXz;
		} elsif ( $xa != ta::Left) {
			$atx = int(($winX - $imXz)/2 + .5);
		} else {
			$atx = 0;
		}
		unless ($self->{overlay}) {
		    $canvas-> clear( 0, $aty, $atx - 1, $aty + $imYz - 1) if $atx > 0;
		    $canvas-> clear( $atx + $imXz, $aty, $winX - 1, $aty + $imYz - 1) if $atx + $imXz < $winX;
		}
		$xDest = 0;
	} else {
		$atx   = -($self-> {deltaX} % $iS);
		$xDest = ($self-> {deltaX} + $atx) / $iS * $iI;
		$imXz = int(($winX - $atx + $iS - 1) / $iS) * $iS;
		$imX = $imXz / $iS * $iI;
	}

PAINT:
	$canvas-> clear( $atx, $aty, $atx + $imXz, $aty + $imYz) if $self-> {icon};

	# # maybe smooth resize the image here!!!

	# my %copy = ( %{$self->{image}} ); # how to make a copy?
	# my $tmp = \%copy;
	# bless($tmp, 'Prima::Image');
	# use Data::Dumper;
	# print Dumper $self->{image}, $tmp;
	# $tmp->scaling(ist::Gaussian); # should be configurable!!!
	# $tmp->size($imXz, $imYz);
	# return $canvas-> put_image_indirect(
	#     $tmp,
	#     $atx, $aty,
	#     0, 0,
	#     $imXz, $imYz, $imXz, $imYz,
	#     rop::CopyPut
	#     );
	return $canvas-> put_image_indirect(
		$self-> {image},
		$atx, $aty,
		$xDest, $yDest,
		$imXz, $imYz, $imX, $imY,
		rop::CopyPut
	);
}

1;

=pod

=head1 SEE ALSO
L<Prima::ThumbViewer>, L<LPDB>

=head1 AUTHOR

Timothy D Witham <twitham@sbcglobal.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2013-2022 Timothy D Witham.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
