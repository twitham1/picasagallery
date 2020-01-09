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
	cells                 => [['']],

	onKeyDown => sub {
	    my($self, $code, $key, $mod, $repeat) = @_;
	    my @f = $self->focusedCell;
	    if ($key == kb::Right && $f[0] == $self->columns - 1) {
		$f[0] = 0; $f[1]++;
		$self->focusedCell(@f);
		$self->clear_event;
	    } elsif ($key == kb::Left && $f[0] == 0) {
		$f[0] = $self->columns - 1; $f[1]--;
		$self->focusedCell(@f);
		$self->clear_event;
	    }
	    #	warn "key: @_\n";
	},
	onStringify => sub {
	    my ( $self, $col, $row, $ref) = @_;
	    $$ref = $self->cell2index($col, $row);
	},
	onSize => sub {
	    my ( $self, $ox, $oy, $x, $y) = @_;
	    my $idx = $self->cell2index($self->focusedCell);
	    my $n = int($x / $self->constantCellWidth);
	    $n > 1 or $n = 1;
	    $self->columns($n);
	    $self->focusedCell($self->index2cell($idx));
	    $self->reset;
	},
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

# new properties for GridList:

sub items {
    return $_[0]->{items} unless $#_;
    my($self, @items) = @_;
    @items = @{$items[0]} if @items == 1 && ref($items[0]) eq 'ARRAY';
    @items > 0 or warn "items < 1, ignoring" and return;
    $self->{items} = \@items;
    $self->rows(int scalar(@{$self->{items}}) / $self->{columns} + 1);
    warn $self->rows, " rows";
}

# new methods for GridList:

sub smaller {
    my($self) = @_;
    my $old = $self->constantCellWidth;
    my $c = $self->columns + 1; # maximize in one more column
    my @i = $self->indents;	# border / scrollbar indents
    my $new = int(($self->width - $i[0] - $i[2]) / $c);
    $new > 50 or $new = 50;
    $self-> constantCellWidth(int $new);
    $self-> constantCellHeight(int $self->constantCellHeight * $new / $old);
    $self->notify('Size', $self->size, $self->size);
}
sub bigger {
    my($self) = @_;
    my $old = $self->constantCellWidth;
    my $c = $self->columns - 1; # maximize in one less column
    $c > 0 or $c = 1;
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



# I can't get this to delegate to SUPER...
# sub on_keydown {
#     my($self, $code, $key, $mod, $repeat) = @_;
#     $self->SUPER::on_keydown(@_);
#     my @f = $self->focusedCell;
#     if ($key == kb::Right && $f[0] == $self->columns - 1) {
# 	#	    warn "right at right\n";
# 	$f[0] = 0; $f[1]++;
# 	# if ($f[1] > $self->rows - 1) {
# 	# 	$f[1] = $self->rows - 1;
# 	# 	$f[0]
# 	$self->focusedCell(@f);
# #	$self->clear_event;
#     } elsif ($key == kb::Left && $f[0] == 0) {
# 	# warn "left at left\n";
# 	$f[0] = $self->columns - 1; $f[1]--;
# 	$self->focusedCell(@f);
# #	$self->clear_event;
#     }
#     warn "hello there @_";
#     $self->SUPER::on_keydown(@_);
#     #	warn "key: @_\n";
# }
    
    # onMeasure => sub {
    # 	my ( $self, $axis, $index, $ref) = @_;
    # 	# if ( defined $user_breadths[$axis]-> {$index} ) {
    # 	# 	$$ref = $user_breadths[$axis]-> {$index};
    # 	# } else {
    # 	# 	$$ref = ( 11 - ( $index % 11)) * 15;
    # 	# 	$$ref = 15 if $$ref < 15;
    # 	# }
    # 	$$ref = $axis ? 100 : 150;
    # },
    # # onSetExtent => sub {
    # # 	my ( $self, $axis, $index, $breadth) = @_;
    # # 	$user_breadths[$axis]-> {$index} = $breadth;
    # # },
# sub draw_cells {
#     my ( $self, $canvas,
# 	 $col, $row, $type,
# 	 $x1, $y1, $x2, $y2,
# 	 $X1, $Y1, $X2, $Y2,
# 	 $sel, $foc, $pre) = @_;

#     warn "draw_cell: @_";

#     my $im = $main::im;		# hack!!! fix this!!!

#     #	warn "onDrawCell: @_\n";
#     my $bk = $sel ? $self-> hiliteBackColor :
# 	( $type ? $self-> indentCellBackColor : cl::Back);
#     $bk = $self-> prelight_color($bk) if $pre;
#     $canvas-> backColor( $bk );
#     $canvas-> clear( $x1, $y1, $x2, $y2);
#     $canvas-> color( $sel ? $self-> hiliteColor :
# 		     ( $type ? $self-> indentCellColor : cl::Fore));
#     # $canvas->put_image($X1 + 10, $Y2 - $im->height - 10, $im)
#     #     or warn "put_image failed: $@\n";
#     my($x, $y) = &scale($im, 130, 130);
#     $canvas->put_image_indirect($im, $X1 + 10, $Y2 - $y - 10, 0, 0, $x, $y,
# 				$im->width, $im->height, $self->rop)
# 	or warn "put_image failed: $@\n";
#     my $n = $row * 7 + $col;
#     $canvas-> text_out( "$n: $col.$row", $X1+10, $Y1+10);
#     $canvas-> text_out( "hello world", $X1+5, ($Y1+$Y2)/2);
#     $canvas-> rect_focus( $x1, $y1, $x2, $y2 ) if $foc;
# }

# sub on_getrange {
#     my ( $self, $axis, $index, $min, $max) = @_;
#     $$min = 50;
# }
# sub on_stringify {
#     my ( $self, $col, $row, $ref) = @_;
#     $$ref = "$col.$row";
# }

# sub get_cell_alignment {
#     my ( $self, $col, $row, $ha, $va) = @_;
#     $$ha = ta::Center;
#     $$va = ta::Middle;
# }
