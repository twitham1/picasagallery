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

use vars qw(@ISA);
@ISA = qw(Prima::ImageViewer);

sub profile_default
{
    my $def = $_[ 0]-> SUPER::profile_default;
    my %prf = (
	size => [800, 600],
	selectable => 1,
	name => 'IV',
	valignment  => ta::Middle,
	alignment   => ta::Center,
	autoZoom => 1,
	stretch => 0,
	);
    @$def{keys %prf} = values %prf;
    return $def;
}

sub init {
    my $self = shift;
    my %profile = $self->SUPER::init(@_);
    $self->{thumbviewer} = $profile{thumbviewer}; # object to return focus to
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
    $self->owner->font->height($self->width/60); # hack?!!!
}

sub on_paint {
    my($self, $canvas) = @_;
    $self->SUPER::on_paint(@_);
    my $im = $self->image or return;
    $self->owner->NW->text(sprintf("%.0f%% of %d x %d",
				   $self->zoom * 100, $im->width, $im->height),
			   0, 0, $self->get_active_area(2));
    $self->owner->SW->text(scalar localtime $self->picture->time);
    $self->owner->N->text($self->picture->basename);
    $self->owner->S->text($self->picture->caption
			  ? $self->picture->caption : "");
}

sub on_close {
    my $owner = $_[0]->{thumbviewer};
    $owner->selected(1);
    $owner->focused(1);
#    $owner->owner->restore;
    $owner->owner->select;
}
sub on_keydown
{
    my ( $self, $code, $key, $mod) = @_;


    if ($key == kb::Enter) {
	if ($self->autoZoom(!$self->autoZoom)) {
	    $self->apply_auto_zoom;
	} else {
	    $self->zoom(1);
	}
	$self->repaint;
	return;
    }
    if ($key == kb::Prior) {
	$self->zoom($self->zoom * 1.1);
	return;
    }
    if ($key == kb::Next) {
	$self->zoom($self->zoom * 0.9);
	return;
    }
    if ($key == kb::Escape) {	# return focus to caller
	my $owner = $self->{thumbviewer};
	$owner->selected(1);
	$owner->focused(1);
#	$owner->owner->restore;
	$owner->owner->select;
	return;
    }

    return if $self->{stretch};

    return unless grep { $key == $_ } (
	kb::Left, kb::Right, kb::Down, kb::Up
    );

    my $xstep = int($self-> width  / 5) || 1;
    my $ystep = int($self-> height / 5) || 1;

    my ( $dx, $dy) = $self-> deltas;

    $dx += $xstep if $key == kb::Right;
    $dx -= $xstep if $key == kb::Left;
    $dy += $ystep if $key == kb::Down;
    $dy -= $ystep if $key == kb::Up;
    $self-> deltas( $dx, $dy);
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
		       $img-> width, $img-> height, $img-> type & im::BPP);
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
