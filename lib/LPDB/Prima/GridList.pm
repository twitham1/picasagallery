package LPDB::Prima::GridList;

use strict;
use warnings;
use Prima;
use Prima::Grids;
use Prima::IntUtils;

use vars qw(@ISA);
@ISA = qw(Prima::AbstractGridViewer);

sub profile_default
{
    my $def = $_[ 0]-> SUPER::profile_default;
    my %prf = (
	drawHGrid               => 0,
	drawVGrid               => 0,
	constantCellHeight => 150,
	constantCellWidth => 150,
	hiliteBackColor => cl::Green,
	items => [],
	count => 0,
	cells                 => [['']],
	);
    @$def{keys %prf} = values %prf;
    return $def;
}

sub init
{
    my $self = shift;
    $self-> {cells}      = [];
    $self-> {widths}     = [];
    $self-> {heights}    = [];
    my %profile = $self-> SUPER::init(@_);
#    $self-> cells($profile{cells});
    return %profile;
}

sub on_keydown {
    my($self, $code, $key, $mod, $repeat) = @_;
    $self-> notify(q(MouseUp),0,0,0) if defined $self-> {mouseTransaction};
    return if $mod & km::DeadKey;

    my @f = $self->focusedCell;
    my $idx = $self->cell2index($self->focusedCell);
    if ($key == kb::Right) {
	$idx++;
	$idx < $self->{count} or $idx = $self->{count} -1;
	$self->focusedCell($self->index2cell($idx));
    } elsif ($key == kb::Left) {
	$idx--;
	$idx >= 0 or $idx = 0;
	$self->focusedCell($self->index2cell($idx));
    } elsif ($key == kb::Enter) {
	$self->notify('Click');
    } else {
	$self->SUPER::on_keydown($code, $key, $mod, $repeat);
    }
    #	warn "key: @_\n";
}

sub on_stringify {
    my ( $self, $col, $row, $ref) = @_;
    $$ref = $self->cell2index($col, $row);
}
sub on_size {
    my ( $self, $ox, $oy, $x, $y) = @_;
    my $idx = $self->cell2index($self->focusedCell);
    my $n = int($x / $self->constantCellWidth);
    $n > 1 or $n = 1;
    $self->columns($n);
    $self->focusedCell($self->index2cell($idx));
    $self->reset;
}

# new properties for GridList:

sub items {
    return $_[0]->{items} unless $#_;
    my($self, @items) = @_;
    @items = @{$items[0]} if @items == 1 && ref($items[0]) eq 'ARRAY';
    @items > 0 or warn "items < 1, ignoring" and return;
    $self->{items} = \@items;
    $self->{count} = scalar @items;
    $self->rows(int $self->{count} / $self->{columns} + 1);
    warn "$self->{count} items in $self->{rows} rows";
}

# new methods for GridList:

sub smaller {
    my($self) = @_;
    my $old = $self->constantCellWidth;
    my $c = $self->columns + 1; # maximize in one more column
    my @i = $self->indents;	# border / scrollbar indents
    my $new = int(($self->width - $i[0] - $i[2]) / $c);
    $new > 100 or $new = 100;
    $self-> constantCellWidth(int $new);
    $self-> constantCellHeight(int $self->constantCellHeight * $new / $old);
    $self->notify('Size', $self->size, $self->size);
}
sub bigger {
    my($self) = @_;
    my $old = $self->constantCellWidth;
    my $c = $self->columns - 1; # maximize in one less column
    $c > 1 or $c = 2;
    my @i = $self->indents;	# border / scrollbar indents
    my $new = int(($self->width - $i[0] - $i[2]) / $c);
    $self-> constantCellWidth(int $new);
    $self-> constantCellHeight(int $self->constantCellHeight * $new / $old);
    $self->notify('Size', $self->size, $self->size);
}

sub cell2index {
    my($self, $col, $row) = @_;
    $row * $self->columns + $col;
}
sub index2cell {
    my($self, $idx) = @_;
    ($idx % $self->columns, int $idx / $self->columns);
}
