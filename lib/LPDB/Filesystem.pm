package LPDB::Filesystem;

=head1 NAME

LPDB::Filesystem - update sqlite from local picture metadata

=cut

# TODO: maybe split to Files / Pictures (exif)

use strict;
use warnings;
use File::Find;
use Date::Parse;
use POSIX qw/strftime/;
use Image::ExifTool qw(:Public);
use LPDB::Schema;
use base 'Exporter::Tiny';
our @EXPORT = qw(update create);

my $exiftool;	  # global hacks for File::Find !!!  We'll never
my $schema;	  # find more than once per process, so this is OK.
my $conf;
my $done = 0;			# records processed
my $tty = -t STDERR;

# create the database from lib/LPDB/*.sql
sub create {
    my $self = shift;
    my $db = $self->conf('dbfile');
    my $thumb = $self->conf('thumbfile');
    my %sql = ('database.sql' => $db,
	       'views.sql'    => $db,
	       'thumbs.sql'   => $thumb);
    # warn "$db already exists!" and return if -f $db;
    # warn "$thumb already exists!" and return if -f $thumb;
    for my $base (sort keys %sql) { # find the .sql in @INC
	for my $path (@INC) {
	    my $sql = "$path/LPDB/$base";
	    if (-f $sql) {
		my $db = $sql{$base};
		warn "create: running sqlite3 $db < $sql\n";
		print `sqlite3 $db < $sql`; # hack!!! any smarter way?
		last;
	    }
	}
    }
    return 1;
}

sub status {
    $tty or return;
    print STDERR "\r$done    @_      ";
}
END {
    print STDERR "\n";
}

# recursively add given directory or . to LPDB
sub update {
    my($self, @dirs) = @_;
    @dirs or @dirs = ('.');
    $schema = $self->schema;
    $conf = $self->conf;
    unless ($exiftool) {
	$exiftool = new Image::ExifTool;
	$exiftool->Options(FastScan => 1);
    }
    status "update @dirs";
    $schema->txn_begin;
    find ({ no_chdir => 1,
	    preprocess => sub { sort @_ },
	    wanted => \&_wanted,
#	    postprocess => $conf->{update},
	  }, @dirs);
    $schema->txn_commit;
}

# add a directory and its parents to the Directories table
{
    my %id;			# cache: {path} = id
    sub _savedirs {		# recursive up to root /
	my($this) = @_;
	$this =~ m@/$@ or return;
	unless ($id{$this}) {
	    status ' ' x 60, "saving dir $this";
	    my $obj = $schema->resultset('Directory')->find_or_new(
		{ directory => $this });
	    unless ($obj->in_storage) { # pre-existing?
		my($dir, $file) = LPDB::dirfile $this;
		$obj->parent_id(&_savedirs($dir));
		$obj->insert;
	    }
	    $id{$this} = $obj->dir_id;
	}
	return $id{$this};
    }
}

# update time range of a directory
sub _dirtimes {
    my($id, $time) = @_;
    my $row = $schema->resultset('Directory')->find(
	{ dir_id => $id },
	{ columns => [qw/dir_id begin end/]});
    $row->begin($time)
	unless $row->begin and $row->begin < $time;
    $row->end($time)
	unless $row->end and $row->end > $time;
    $row->is_changed
	? $row->update
	: $row->discard_changes;
}

# add a path and its parents to the virtual Paths table
{
    my %id;			# cache: {path} = id
    sub _savepath {		# recursive up to root /
	my($this) = @_;
	$this =~ m@/$@ or return;
	unless ($id{$this}) {
	    status "saving path $this";
	    my $obj = $schema->resultset('Path')->find_or_new(
		{ path => $this });
	    unless ($obj->in_storage) { # pre-existing?
		my($dir, $file) = LPDB::dirfile $this;
		$obj->parent_id(&_savepath($dir));
		$obj->insert;
	    }
	    $id{$this} = $obj->path_id;
	}
	return $id{$this};
    }
}
# connect a picture id to one logical path, creating it as needed
sub _savepathfile {
    my($path, $id) = @_;
    my $path_id = &_savepath($path);
    $schema->resultset('PicturePath')->find_or_create(
	{ path_id => $path_id,
	  file_id => $id });
}

# add a file or directory to the database, adapted from Picasa.pm
sub _wanted {
    my($dir, $file) = LPDB::dirfile $_;
    my $modified = (stat $_)[9];
    $dir =~ s@\./@@;
    #    $dir = '' if $dir eq '.';
    status "checking: $modified $_";
    if ($file eq '.picasa.ini' or $file eq 'Picasa.ini') {
	# &_understand($db, _readfile($_));
	# $db->{dirs}{$dir}{'<<updated>>'} = $modified;
	return;
    } elsif ($file =~ /^\..+/ or # ignore hidden files, and:
	     $file eq 'Originals' or
	     $file =~ /$conf->{reject}/) { 
	$File::Find::prune = 1;
	return;
    }
#    my $guard = $schema->txn_scope_guard; # DBIx::Class::Storage::TxnScopeGuard
    unless (++$done % 100) {	# fix this!!! make configurable??...
	$schema->txn_commit;
	status "committed $done";
	$schema->txn_begin;
    }
    if (-f $_) {
	return unless $file =~ /$conf->{keep}/;
	my $key = $_;
	$key =~ s@\./@@;
	return unless -f $key and -s $key > 100;
	my $dir_id = &_savedirs($dir);
	my $row = $schema->resultset('Picture')->find_or_create(
	    { dir_id => $dir_id,
	      basename => $file },
	    { columns => [qw/modified/]});
	return if $row->modified || 0 >= $modified; # unchanged
	my $info = $exiftool->ImageInfo($key);
	return unless $info;
	return unless $info->{ImageWidth} and $info->{ImageHeight};
	my $or = $info->{Orientation} || '';
	my $rot = $or =~ /Rotate (\d+)/i ? $1 : 0;
	my $swap = $rot == 90 || $rot == 270 || 0; # 
	my $time = $info->{DateTimeOriginal} || $info->{CreateDate}
	|| $info->{ModifyDate} || $info->{FileModifyDate} || 0;
	$time =~ s/: /:0/g;	# fix corrupt: 2008:04:23 19:21: 4
	$time = str2time $time;
	
	$row->bytes(-s $_);
	$row->modified($modified);
	$row->rotation($rot);
	$row->width($swap ? $info->{ImageHeight} : $info->{ImageWidth});
	$row->height($swap ? $info->{ImageWidth} : $info->{ImageHeight});
	$row->time($time);
	$row->caption($info->{'Caption-Abstract'}
		      || $info->{'Description'} || undef);
	$row->is_changed
	    ? $row->update
	    : $row->discard_changes;

	&_dirtimes($dir_id, $time);

	&_savepathfile("/[Folders]/$dir", $row->file_id);

	&_savepathfile(strftime("/[Timeline]/Years/%Y/",
				localtime $time), $row->file_id);
	&_savepathfile(strftime("/[Timeline]/Months/%Y/%m-%b/",
				localtime $time), $row->file_id);

	my %tags; map { $tags{$_}++ } split /,\s*/,
		      $info->{Keywords} || $info->{Subject} || '';
	for my $tag (keys %tags) {
	    my $rstag = $schema->resultset('Tag')->find_or_create(
		{ tag => $tag });
	    $schema->resultset('PictureTag')->find_or_create(
		{ tag_id => $rstag->tag_id,
		  file_id => $row->file_id });
	    &_savepathfile("/[Tags]/$tag/", $row->file_id);
	}

	# 	$this->{face}	= $db->faces($dir, $file, $this->{rot}); # picasa data for this pic
	# 	$this->{album}	= $db->albums($dir, $file);
	# 	$this->{stars}	= $db->star($dir, $file);
	# 	$this->{uploads} = $db->uploads($dir, $file);
	# 	$this->{faces}	= keys %{$this->{face}} ? 1 : 0; # boolean attributes
	# 	$this->{albums}	= keys %{$this->{album}} ? 1 : 0;
	# 	$this->{tags}	= keys %{$this->{tag}} ? 1 : 0;

	# 	$this->{time} =~ /0000/ and
	# 	    warn "bogus time in $_: $this->{time}\n";
	# 	my $year = 0;
	# 	$year = $1 if $this->{time} =~ /(\d{4})/; # year must be first

	# 	my $vname = "$this->{time}-$file"; # sort files chronologically
	# 	$conf->{sortbyfilename} and $vname = $file; # sort by filename

	# 	# add virtual folders of stars, tags, albums, people
	# 	$this->{stars} and
	# 	    $db->_addpic2path("/[Stars]/$year/$vname", $key);

	# 	for my $tag (keys %{$this->{tag}}) { # should year be here???
	# 	    $db->_addpic2path("/[Tags]/$tag/$vname", $key);
	# 	    $db->{tags}{$tag}++; # all tags with picture counts
	# 	}
	# 	for my $id (keys %{$this->{album}}) { # named user albums
	# 	    next unless my $name = $db->{album}{$id}{name};
	# 	    # putting year in this path would cause albums that span
	# 	    # year boundary to be split to multiple places...
	# 	    $db->_addpic2path("/[Albums]/$name/$vname", $key);
	# 	}

	# 	# add faces / people
	# 	for my $id (keys %{$this->{face}}) {
	# 	    next unless my $name = $db->contact2person($id);
	# 	    $db->_addpic2path("/[People]/$name/$year/$vname", $key);
	# 	}

	# 	# add folders (putting year here would split folders into
	# 	# multiple locations (y/f or f/y); maybe this would be ok?)
	# #	$db->_addpic2path("/[Folders]/$key", $key);
	# 	(my $timekey = $key) =~ s@[^/]+$@$vname@;
	# 	$db->_addpic2path("/[Folders]/$timekey", $key);

	# 	$odb->{sofar}++;	# count of pics read so far

    } elsif (-d $_) {
	# $db->{dirs}{$dir}{"$file/"} or
	#     $db->{dirs}{$dir}{"$file/"} = {};
    }
#    $guard->commit;	       # DBIx::Class::Storage::TxnScopeGuard
    # unless ($db->{dir} and $db->{file}) {
    # 	my $tmp = $db->filter(qw(/));
    # 	$tmp and $tmp->{children} and $db->{dir} = $db->{file} = $tmp;
    # }
    &{$conf->{update}};
}

1;				# LPDB::Filesystem.pm
