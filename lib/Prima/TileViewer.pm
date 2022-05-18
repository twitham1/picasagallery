=head1 NAME

Prima::TileViewer - resizable cells for Prima::Listviewer

=head1 DESCRIPTION

This class extends C<Prima::ListViewer> to help C<LPDB> implement an
image thumbnail browser.  Adds methods for resizing list items.
Number keys now scroll to tenths of the list, handy for long lists.

=cut

package Prima::TileViewer;

use strict;
use warnings;
use Prima::Lists;

use vars qw(@ISA);
@ISA = qw(Prima::ListViewer);

# rectangular items, vertical scroll only, bright hilite
sub profile_default {
    my $def = $_[0]-> SUPER::profile_default;
    my %prf = (
	hiliteBackColor	=> cl::Green,
	itemWidth	=> 320,
	itemHeight	=> 320,
	autoHeight	=> 0,
	autoWidth	=> 0,
	multiColumn	=> 1,
	vertical	=> 0,
	drawGrid	=> 0,
	dragable	=> 0,
	hScroll		=> 0,
	autoHScroll	=> 0,
	crops		=> 0,
	borderWidth	=> 0,
	);
    @$def{keys %prf} = values %prf;
    return $def;
}

# allow remote control number pad to scroll to tenths of large pages
sub on_keydown {
    my ($self, $code, $key, $mod) = @_;
    my $c = $code & 0xFF;
    if ($c >= ord '0' and $c <= ord '9' and $self->{count}) {
	$self->focusedItem(int(($code - ord '0') / 10 * $self->{count}));
	$self->clear_event;
	return;
    }
    $self->SUPER::on_keydown( $code, $key, $mod);
}

sub on_mousewheel		# zoom in/out or scroll
{
    my($self, $mod, $x, $y, $z) = @_;
    if ($mod & km::Ctrl) {
	$z < 0 ? $self->smaller : $self->bigger;
	$self->clear_event;
	return;
    }
    $self->SUPER::on_mousewheel($mod, $x, $y, $z);
}

=head2 Methods

=over

=item smaller

Zoom out on content: adds one column to make the items smaller.  Item
aspect ratio remains constant.

=cut

sub smaller {
    my($self, $c) = @_;
    my $wide = $self->width;
    my $old = $self->itemWidth;
    $c ||= $self->{active_columns} + 1; # maximize in one more column
    $c > 3 or $c = 4;
    my @i = $self->indents;	# border / scrollbar indents
    my $new = int(($self->width - $i[0] - $i[2]) / $c);
    $new > 100 or $new = 100;
    $self->itemWidth(int $new);
    $self->itemHeight(int $self->itemHeight * $new / $old);
    $self->font->height($new/12);
    $self->notify('Size', $self->size, $self->size);
}

=item bigger

Zoom in on content: removes one column to make the items bigger.  Item
aspect ratio remains constant.

=cut

sub bigger {
    my($self, $c) = @_;
    my $old = $self->itemWidth;
    $c ||= $self->{active_columns} - 1; # maximize in one less column
    $c > 3 or $c = 4;
    my @i = $self->indents;	# border / scrollbar indents
    my $new = int(($self->width - $i[0] - $i[2]) / $c);
    $self->itemWidth(int $new);
    $self->itemHeight(int $self->itemHeight * $new / $old);
    $self->font->height($new/12);
    $self->notify('Size', $self->size, $self->size);
}

1;

=pod

=back

=head1 SEE ALSO
L<Prima::LPDB::ThumbViewer>, L<LPDB>, L<Prima::Lists>

=head1 AUTHOR

Timothy D Witham <twitham@sbcglobal.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2013-2022 Timothy D Witham.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
