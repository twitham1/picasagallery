package LPDB::Thumbnail;

=head1 NAME

LPDB::Thumbnail - thumbnail images of local pictures in sqlite

=cut

use strict;
use warnings;
use Prima;
use LPDB::Schema;
use LPDB::Schema::Object;

sub new {
    my($class, $lpdb) = @_;
    my $self = { schema => $lpdb->schema,
		 tschema => $lpdb->tschema,
		 conf => $lpdb->conf };
    bless $self, $class;
    return $self;
}

sub _aspect {		    # modified from _draw_thumb of ThumbViewer
    my($sw, $sh, $dw, $dh) = @_;
    my $src = $sw / $sh;	# aspect ratios
    my $dst = $dw / $dh;
    if ($src > $dst) {		# image wider than cell: pad top/bot
	$dh = $dw / $src;
    } else {		      # image taller than cell: pad left/right
	$dw = $dh * $src;
    }
    return $dw, $dh;
}

# return thumbnail of given file ID
sub get {
    my($self, $id, $cid, $try) = @_;
    $try ||= 0;
     $try++ > 5
	 and return undef;
#    warn "getting $id from $self\n";
    $cid ||= 0;
    my $tschema = $self->{tschema};
    if (my $this = $tschema->resultset('Thumb')->find(
	    {file_id => $id},
	    {columns => [qw/image/]})) {
	my $data = $this->image;
	unless ($data) {	# try to fix broken save
	    return $self->put($id, $cid) ? $self->get($id, $cid, $try) : undef;
	}
	open my $fh, '<', \$data
	    or die $!;
	binmode $fh;
	my $x = Prima::Image->load($fh)
	    or die $@;
	return $x;
	
    } else {			# not in DB, try to add it
	return $self->put($id, $cid) ? $self->get($id, $cid, $try) : undef;
    }
    return;
}
sub put {
    my($self, $id, $cid) = @_;
    $cid ||= 0;
    # warn "putting $id/$cid in $self\n";
    my $schema = $self->{schema};
    my $picture = $schema->resultset('Picture')->find(
    	{file_id => $id},
	{columns => [qw/basename dir_id width height rotation/]});
    my $path = $picture->pathtofile;
    my $modified = -f $path ? (stat _)[9] : 0;
    my $tschema = $self->{tschema};
    my $row = $tschema->resultset('Thumb')->find_or_create(
	{ file_id => $id,
	  contact_id => $cid });
    $modified and $row->modified || 0 >= $modified and
	return $row->image;	# unchanged
    my $i;
    my $codec;
#    warn "doing $path\n";
    if ($i = Prima::Image->load($path, loadExtras => 1)) {
	# PS: I've read somewhere that ist::Quadratic produces best
	# visual results for the scaled-down images, while ist::Sinc
	# and ist::Gaussian for the scaled-up. /Dmitry Karasik
	$i->scaling(ist::Quadratic);
	if (my $rot = $picture->rotation) {
	    $i->rotate(-1 * $rot);
	}			# 1920/6=320:
	$i->size(_aspect($picture->width, $picture->height, 320, 320));
    } else {		    # generate image containing the error text
	my $e = "$@";
#	warn "hello: ", $e;
	my @s = (320, 320);
	my $b = 10;
	$i = Prima::Image->new(
	    width  => $s[0],
	    height => $s[1],
	    type   => im::bpp8,
	    );
	$i->begin_paint;
	$i->color(cl::Red);
	$i->bar(0, 0, @s);
	$i->color(cl::White);
	$i->font({size => 15, style => fs::Bold});
	$i->draw_text("$path:\n$e",
		      $b, $b, $s[0] - $b, $s[1] - $b,
		      dt::Center|dt::VCenter|dt::Default);
	$i->end_paint;
    }
    $codec = $i->{extras}{codecID} || 1;
    #    warn "codec: $codec";
    my $data;
    open my $fh, '>', \$data
	or die $!;
    binmode $fh;
    $i->save($fh, codecID => $codec)
	or die $@;
    $row->image($data);
    $row->modified($modified ? time : 0);
    $row->update;
    return $row->image;
}

1;				# LPDB::Thumbnail.pm
