package LPDB;

=head1 NAME

LPDB::Write - write local picture metadata to sqlite

=cut

use strict;
use warnings;
use DBI;
use File::Find;
use Date::Parse;
use POSIX qw/strftime/;
use Image::ExifTool qw(:Public);
use LPDB::Schema;

my $exiftool;	  # global hacks for File::Find !!! but we'll never
my $schema;	  # find more than once per process, so this will work
my $conf;
my $i = 0;

# recursively add given directory or . to picasa database
sub update {
    my $self = shift;
    my $dir = shift || '.';
    $schema = $self->schema;
    $conf = $self->conf;
    unless ($exiftool) {
	$exiftool = new Image::ExifTool;
	$exiftool->Options(FastScan => 1,
			   DateFormat => $conf->{datefmt});
    }
    warn "update $dir\n" if $conf->{debug};
    $schema->txn_begin;
    find ({ no_chdir => 1,
	    preprocess => sub { sort @_ },
	    wanted => \&_wanted,
#	    postprocess => $conf->{update},
	  }, $dir);
    $schema->txn_commit;
}

# add a file or directory to the database, adapted from Picasa.pm
sub _wanted {
    my($dir, $file) = LPDB::dirfile $_;
    my $modified = (stat $_)[9]; 
    #    $dir = '' if $dir eq '.';
    #    warn "checking: $modified\t$_\n";
    if ($file eq '.picasa.ini' or $file eq 'Picasa.ini') {
	# &_understand($db, _readfile($_));
	# $db->{dirs}{$dir}{'<<updated>>'} = $modified;
	return;
    } elsif ($file =~ /^\..+/ or $file eq 'Originals') { # ignore hidden files
	$File::Find::prune = 1;
	return;
    }
    $File::Find::prune = 1, return if $file =~ /$conf->{reject}/;
#    my $guard = $schema->txn_scope_guard; # DBIx::Class::Storage::TxnScopeGuard
    unless (++$i % 1000) {
	$schema->txn_commit;
	$schema->txn_begin;
    }
    if (-f $_) {
	return unless $file =~ /$conf->{keep}/;
	my $key = $_;
	$key =~ s@\./@@;
	return unless -f $key and -s $key > 100;
	my $row = $schema->resultset('Picture')->find_or_create(
	    { filename => $key },
	    { columns => [qw/modified/]});
	return if $row->modified || 0 >= $modified;
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
		      || $info->{'Description'} || '');
	$row->is_changed
	    ? $row->update
	    : $row->discard_changes;

	my $path = "/[Folders]/$dir$file";
	# TODO: make this an internal method or function
	my $rspath = $schema->resultset('Path')->find_or_create(
	    { path => $path });
	    $schema->resultset('PicturePath')->find_or_create(
		{ path_id => $rspath->path_id,
		  file_id => $row->file_id });

	my $tsfile = strftime "%Y/%m-%d-%H:%M:%S.$file",
	    localtime $time;	# made-up file!!!

	my %tags; map { $tags{$_}++ } split /,\s*/,
		      $info->{Keywords} || $info->{Subject} || '';
	for my $tag (keys %tags) {
	    my $rstag = $schema->resultset('Tag')->find_or_create(
		{ string => $tag });
	    $schema->resultset('PictureTag')->find_or_create(
		{ tag_id => $rstag->tag_id,
		  file_id => $row->file_id });
	    my $path = "/[Tags]/$tag/$tsfile";
	    my $rspath = $schema->resultset('Path')->find_or_create(
		{ path => $path });
	    $schema->resultset('PicturePath')->find_or_create(
		{ path_id => $rspath->path_id,
		  file_id => $row->file_id });
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

1;				# LPDB.pm
