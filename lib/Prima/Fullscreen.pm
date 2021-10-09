=head1 NAME

Prima::Fullscreen - Try to toggle a window to full screen

=head1 DESCRIPTION

This approach to fullscreen keeps the window borders but displays them
off-screen.  It may or may not work with random window managers.
Tested only on xfce on Ubuntu 20.04.

=cut

package Prima::Fullscreen;
use strict;
use warnings;
use Prima::Classes;


use vars qw(@ISA);
@ISA = qw(Prima::Object);

{
    my %RNT = (
	%{Prima::Component->notification_types()},
	Activate   => nt::Default,
	Deactivate   => nt::Default,
	);

    sub notification_types { return \%RNT; }
}

sub init {
    my $self = shift;
    my %profile = $self->SUPER::init(@_);
    $self->{window} = $profile{window} or
	die "window required";
    $profile{window}->onDeactivate(sub {
	warn "deactivated @_";
	$_[0]->onTop(0) });
    $profile{window}->onActivate(sub {
	warn "activated @_";
	# $_[0]->fullscreen &&
	$_[0]->onTop(1) });
    return \%profile;
}

my @where;			# memory of non-fullscreen frame
sub fullscreen {
    # my($win, $which) = @_;
    my($self, $which) = @_;
    my $win = $self->owner;
    # my $win = $self->{window};
    my @d = $::application->size;		      # desktop size
    my @w = ($win->frameSize, $win->frameOrigin);     # my size
    my @W = ($win->size, $win->origin);
    unless (defined $which) {
	return $d[0] == $W[0] && $d[1] == $W[1];
    }
    if ($which) {		# going to fullscreen
	@where = @w;		# remember size/origin to return to
	my $x = $w[0] - $W[0];
	my $y = $w[1] - $W[1];
	# this loses Alt-tab control on xfce:
	# $win->borderStyle(bs::None);
	# $win->borderIcons(0);
	# without this, xfce taskbar overlays my fullscreen:
	$win->onTop(1);
	$win->frameSize($d[0] + $x, $d[1] + $y);
	$win->frameOrigin(-$x, $w[3] - $W[3]);
	# $win->onTop(0);
	return 1;
    } elsif (@where) {		# restore orignal frame
	$win->onTop(0);
	# $win->borderIcons(bi::All);
	# $win->borderStyle(bs::Sizeable);
	$win->frameSize(@where[0,1]);
	$win->frameOrigin(@where[2,3]);
	return 0;
    }
}

1;
