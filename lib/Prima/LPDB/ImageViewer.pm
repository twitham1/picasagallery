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
	popupItems => [
	    # ['~Menu', 'm', ord 'm'],
	    ['~Zoom' => [
		 ['fullscreen', '~Full Screen', 'f', ord 'f' =>
		  sub { $_[0]->fullscreen($_[0]->popup->toggle($_[1]) )} ],
		 ['*autozoom', '~Auto Zoom', 'a', ord 'a' =>
		  sub { $_[0]->autoZoom($_[0]->popup->toggle($_[1]) )} ],
		 ['bigger', 'Zoom ~In', 'PageUp', ord '=' =>
		  sub { $_[0]->key_down(0, kb::Prior ) }],
		 ['smaller', 'Zoom ~Out', 'PageDown', ord '-' =>
		  sub { $_[0]->key_down(0, kb::Next ) }],
	     ]],
	    ['~Escape' => sub { $_[0]->key_down(0, kb::Escape) } ],
	]);
    @$def{keys %prf} = values %prf;
    return $def;
}

sub init {
    my $self = shift;
    my %profile = $self->SUPER::init(@_);
    my @opt = qw/Prima::Label autoHeight 1/; # transparent 1/; # flickers!

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

sub on_paint { # update metadata label overlays, later in front of earlier
    my($self, $canvas) = @_;
    # TODO:  clear labels if info is toggled off
    $self->SUPER::on_paint(@_);
    my $im = $self->image or return;
    my $th = $self->{thumbviewer};
    my $x = $th->focusedItem + 1;
    my $y = $th->count;
    $self->NORTH->N->text($self->picture->basename);
    $self->NORTH->NW->text(sprintf("%.0f%% of %d x %d", $self->zoom * 100,
				   $im->width, $im->height));
    $self->NORTH->NE->text(sprintf '%.2f  %.1fMP  %d / %d',
			   $im->width / $im->height,
			   $im->width * $im->height / 1000000,
			   $x, $y);
    $self->SOUTH->S->text($self->picture->caption ?
			  $self->picture->caption : '');
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
	$th->key_down($code, kb::Enter);
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

1;

=pod

=back

=head1 SEE ALSO
L<Prima::ThumbViewer>, L<LPDB>

=head1 AUTHOR

Timothy D Witham <twitham@sbcglobal.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2013-2022 Timothy D Witham.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
