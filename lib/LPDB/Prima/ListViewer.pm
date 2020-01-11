=head1 NAME

LPDB::Prima::ListViewer - resizable cells for Prima::Listviewer

=head1 DESCRIPTION

This class extends C<Prima::ListViewer> to help C<LPDB> implement an
image thumbnail viewer.  Adds methods for resizing list items and
remembering the navigation path down a tree of lists.

=cut

package LPDB::Prima::ListViewer;

use strict;
use warnings;
use Prima;
use Prima::Lists;
use Prima::IntUtils;

use vars qw(@ISA);
@ISA = qw(Prima::ListViewer);

sub profile_default {
    my $def = $_[ 0]-> SUPER::profile_default;
    my %prf = (
	itemWidth	=> 200,
	itemHeight	=> 150,
	hiliteBackColor	=> cl::Green,
	multiColumn	=> 1,
	vertical	=> 0,
	autoWidth	=> 0,
	drawGrid	=> 0,
	dragable	=> 0,
	hScroll	=> 0,
	);
    @$def{keys %prf} = values %prf;
    return $def;
}

=head2 Methods

=over

=item smaller

Zoom out on content: adds one column to make the items smaller.  Item
aspect ratio remains constant.

=cut

sub smaller {
    my($self) = @_;
    my $old = $self->itemWidth;
    my $c = $self->{active_columns} + 1; # maximize in one more column
    my @i = $self->indents;	# border / scrollbar indents
    my $new = int(($self->width - $i[0] - $i[2]) / $c);
    $new > 100 or $new = 100;
    $self-> itemWidth(int $new);
    $self-> itemHeight(int $self->itemHeight * $new / $old);
    $self->notify('Size', $self->size, $self->size);
}

=item bigger

Zoom in on content: removes one column to make the items bigger.  Item
aspect ratio remains constant.

=cut

sub bigger {
    my($self) = @_;
    my $old = $self->itemWidth;
    my $c = $self->{active_columns} - 1; # maximize in one less column
    $c > 1 or $c = 2;
    my @i = $self->indents;	# border / scrollbar indents
    my $new = int(($self->width - $i[0] - $i[2]) / $c);
    $self-> itemWidth(int $new);
    $self-> itemHeight(int $self->itemHeight * $new / $old);
    $self->notify('Size', $self->size, $self->size);
}

1;

=pod

=back

=head1 SEE ALSO
L<Prima::Lists>, L<LPDB>

=head1 AUTHOR

Timothy D Witham <twitham@sbcglobal.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2013-2020 Timothy D Witham.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
