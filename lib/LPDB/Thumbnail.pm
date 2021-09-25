package LPDB::Thumbnail;

=head1 NAME

LPDB::Thumbnail - thumbnail images of local pictures in sqlite

=cut

use strict;
use warnings;
use Image::Magick;
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
	my $i = Image::Magick->new;
	my $e = $i->BlobToImage($data);
	$e and warn "($e) for Picture $id, $data" and return;
	return $i;
    } else {			# not in DB, try to add it
	return $self->put($id, $cid) ? $self->get($id, $cid, $try) : undef;
    }
    return;
}
sub put {
    my($self, $id, $cid) = @_;
    $cid ||= 0;
#    warn "putting $id/$cid in $self\n";
    my $schema = $self->{schema};
    my $this = $schema->resultset('Picture')->find(
    	{file_id => $id});
    my $path = $this->pathtofile;
    -f $path or
	warn "$path doesn't exist\n" and return;
    my $modified = (stat $path)[9];
    my $tschema = $self->{tschema};
    my $row = $tschema->resultset('Thumb')->find_or_create(
	{ file_id => $id,
	  contact_id => $cid });
    $row->modified || 0 >= $modified and
	return $row->image;	# unchanged

    # jpegs read 3X faster if we ask for size 2X the thumbnail!
    my @opt = $cid ? () : 	# crop faces at full resolution
	$path =~ /jpe?g$/i ? ('jpeg:size' => '640x640') : ();

    my $i = Image::Magick->new(@opt);
    my $e = $i->Read($path);
    if ($e) {
    	warn $e;      # opts are last-one-wins, so we override colors:
    	$i = Image::Magick->new(qw/magick png24 size 320x320/,
    				qw/background red fill white gravity center/);
    	$i->Read("caption:$e");	# put error message in the image
    }
    $i->AutoOrient;		# automated rot fix via EXIF!!!
    $i->Thumbnail(geometry => '320x320'); # 1920/6=320
    my @b = $i->ImageToBlob;
    $row->modified(time);
    $row->image($b[0]);
    $row->update;

    return $row->image;
}

1;				# LPDB::Thumbnail.pm
