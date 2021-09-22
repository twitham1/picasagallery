=head1 NAME

Prima::ThumbViewer - Browse a tree of image thumbnails from LPDB

=head1 DESCRIPTION

This class connects C<Prima::TileViewer> to an C<LPDB> database,
presenting its paths and pictures in an interactive thumbnail browser.

=cut

package Prima::LPDB::ThumbViewer;

use strict;
use warnings;
use LPDB::Tree;
use LPDB::Thumbnail;
use Prima::TileViewer;
use Prima::Image::Magick qw/:all/;

use vars qw(@ISA);
@ISA = qw(Prima::TileViewer);

# sub profile_default {
#     my $def = $_[0]-> SUPER::profile_default;
#     my %prf = (
# 	);
#     @$def{keys %prf} = values %prf;
#     return $def;
# }

sub init {
    my $self = shift;
    my(%hash) = @_;
    $self->{lpdb} = $hash{lpdb} or die "lpdb object required";
    $self->{tree} = new LPDB::Tree($self->{lpdb});
    $self->{thumb} = new LPDB::Thumbnail($self->{lpdb});
    my %profile = $self-> SUPER::init(@_);
    $self->items( [ $self->recurse(0) ]); # fix this to read first level of DB right!!!
    $self->focusedItem(0);
    $self-> setup_indents;
    $self->hScroll($profile{hScroll});
    $self-> reset;
    $self-> reset_scrolls;
    # warn join "\n", map { $self->{$_} } qw/lpdb tree thumb items/, "\n";
    # my @foo = @{$self->{items}};
    # warn "items: @foo\n";
    return %profile;
}

# # fix this hack!!!!
sub recurse {
    my($self, $id, $indent) = @_;
    my @id;
    my($path, $file) = $self->{tree}->pathpics($id || 0);
    push @id, @$file if @$file;
    for my $n (@$path) {
	push @id, $self->recurse($self->{tree}->node($n)->path_id);
    }
    return @id;
}

sub on_drawitem
{
    my ($self, $canvas, $idx, $x1, $y1, $x2, $y2, $sel, $foc, $pre, $col) = @_;

    my $tree = $self->{tree};
    my $th = $self->{thumb};
    my $pic = $tree->node($self->{items}[$idx]);
    my $thumb = $th->get($pic->file_id);
    $thumb or return "warn: can't get thumb!\n";
    my $im = magick_to_prima($thumb);
    my $bk = $sel ? $self-> hiliteBackColor : cl::Back;
    $bk = $self-> prelight_color($bk) if $pre;
    $canvas-> backColor( $bk );
    $canvas-> clear( $x1, $y1, $x2, $y2);
    $canvas-> color( $sel ? $self-> hiliteColor : cl::Fore);
    {		# source image -> destination, preserving aspect ratio
	my $dw = $x2 - $x1;
	my $dh = $y2 - $y1;
	my $b = $sel || $foc || $pre ? 0 : $dw / 30;
	$dw -= $b * 2;
	$dh -= $b * 2;
	my($sw, $sh) = ($im->width, $im->height);
	my @out;
	my $src = $sw / $sh;	# aspect ratios
	my $dst = $dw / $dh;
	my $sx = my $sy = my $dx = my $dy = 0;
	# this copy is used for rectangle overlay in crop mode
	my($DX, $DY, $DW, $DH) = ($dx, $dy, $dw, $dh);
	if ($src > $dst) {	# image wider than cell: pad top/bot
	    $DY = ($DH - $DW / $src) / 2;
	    $DH = $DW / $src;
	} else {	      # image taller than cell: pad left/right
	    $DX = ($DW - $DH * $src) / 2;
	    $DW = $DH * $src;
	}
	if ($self->{crops}) {	   # crop source to destination
	    if ($src > $dst) { # image wider than cell: crop left/right
		$sx = ($sw - $sh * $dst) / 2;
		$sw = $sh * $dst;
	    } else {		# image taller than cell: crop top/bot
		$sy = ($sh - $sw / $dst) / 2;
		$sh = $sw / $dst;
	    }
	} else {		# pad source to destination
	    ($dx, $dy, $dw, $dh) = ($DX, $DY, $DW, $DH);
	}
	$canvas->put_image_indirect($im, $x1 + $b + $dx, $y1 + $b + $dy,
				    $sx, $sy, $dw, $dh, $sw, $sh,
				    $self->rop)
	    or warn "put_image failed: $@\n";
	if (!$b) {
	    my($x, $y, $w, $h);
	    if ($self->{crops}) { # show original aspect rectangle
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

	$canvas->textOpaque(!$b);
	$b += 5;		# now text border

	my $str = sprintf "%s\n%dx%d", $pic->basename,
	    $pic->width, $pic->height;
	$canvas->draw_text($str, $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
			   dt::Right|dt::Top|dt::Default); # dt::VCenter
	$pic->caption and
	    $canvas->draw_text($pic->caption, $x1 + $b, $y1 + $b, $x2 - $b, $y2 - $b,
			       dt::Left|dt::Bottom|dt::Default); # dt::VCenter
    }
    $canvas-> rect_focus( $x1, $y1, $x2, $y2 ) if $foc;
}

1;

=pod

=back

=head1 SEE ALSO
L<Prima::Lists>, L<LPDB>

=head1 AUTHOR

Timothy D Witham <twitham@sbcglobal.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2013-2022 Timothy D Witham.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
