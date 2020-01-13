package LPDB::Thumbnail;

=head1 NAME

LPDB::Thumbnail - thumbnail images of local pictures in sqlite

=cut


use strict;
use warnings;
use Image::Magick;
use LPDB::Schema;

sub new {
    my($class, $lpdb) = @_;
    my $self = { schema => $lpdb->schema,
		 conf => $lpdb->conf };
    bless $self, $class;
    return $self;
}

sub get {
    my($self, $id, $cid) = @_;
    $cid ||= 0;
    my $schema = $self->{schema};
    if (my $this = $schema->resultset('Thumb')->find({file_id => $id})) {
	my $i = Image::Magick->new;
	my $data = $this->image;
	my $e = $i->BlobToImage($data);
	$e and warn $e and return;
#	$i->Display;		# comment this!!!
	return $i;
    } else {			# not in DB, try to add it
	return $self->put($id, $cid) ? $self->get($id, $cid) : undef;
    }
    return;
}
sub put {
    my($self, $id, $cid) = @_;
    $cid ||= 0;
    my $schema = $self->{schema};
    my $this = $schema->resultset('Picture')->find(
	{file_id => $id},
	{prefetch => 'dir' });
    my $path = $this->dir->directory . $this->basename;
    -f $path or warn "$path doesn't exist\n" and return;
    my $modified = (stat $path)[9];
    my $row = $schema->resultset('Thumb')->find_or_create(
	{ file_id => $id,
	  contact_id => $cid });
    return $row->image if $row->modified || 0 >= $modified; # unchanged

    # jpegs read 3X faster if we ask for size 2X the thumbnail!
    my @opt = $cid ? () : 	# crop faces at full resolution
	$path =~ /jpe?g$/i ? ('jpeg:size' => '540x400') : ();

    my $i = Image::Magick->new(@opt);
    my $e = $i->Read($path);
    if ($e) {
    	warn $e;      # opts are last-one-wins, so we override colors:
    	$i = Image::Magick->new(qw/magick png24 size 270x200/,
    				qw/background red fill white gravity center/);
    	$i->Read("caption:$e");	# put error message in the image
    }
    $i->AutoOrient;		# automated rot fix via EXIF!!!
    $i->Thumbnail(geometry => '270x200');
    my @b = $i->ImageToBlob;
    $row->modified(time);
    $row->image($b[0]);
    $row->update;

    return $row->image;
}

1;				# LPDB::Thumbnail.pm
