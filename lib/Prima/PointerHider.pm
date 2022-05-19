=head1 NAME

Prima::PointerHider - Hide the mouse pointer except when moved

=head1 DESCRIPTION

This automatically hides the mouse pointer when it is not in use.
Simply move the mouse to bring it back.

=cut

# TODO: confiugurable time, methods to enable/disable

package Prima::PointerHider;
use strict;
use warnings;
use Prima::Classes;
use Prima::EventHook;

use vars qw(@ISA);
@ISA = qw(Prima::Component);

sub init {
    my $self = shift;
    my %profile = $self->SUPER::init(@_);
    Prima::EventHook::install(sub {
	#	warn "hello mouse @_";
	$::application->pointerVisible(1);
	1;			# propagate the event
			      },
			      event => 'mouse');
    $self->{timer} = Prima::Timer->create(
    	timeout => 4000,	# milliseconds
    	onTick => sub {
	    $::application->pointerVisible(0);
    	}
    	);
    $self->{timer}->start;
    return %profile;
}

1;
