# LPDB.pm

# ABSTRACT: LPDB = Local Picture metadata in sqlite

package LPDB;
use strict;
use warnings;
use Carp;
use DBI;
use File::Find;
use Date::Parse;
use Image::ExifTool qw(:Public);
use LPDB::Schema;

# use DBIx::Class;

my $conf = {		       # override any keys in first arg to new
    reject	=> 'PATTERN OF FILES TO REJECT',
    keep	=> '(?i)\.jpe?g$',	# pattern of files to keep
    # datefmt	=> '%Y-%m-%d.%H:%M:%S', # must be sortable order
    datefmt	=> undef,		# undef == EXIF format
    update	=> sub {},  # callback after each directory is scanned
    debug	=> 0,	    # diagnostics to STDERR
    filter	=> {},	    # filters
    editpath	=> 0,	# optional sub to return modified virtual path
#    sortbyfilename => 0,  # boolean: sort by filename rather than time
#    metadata	=> 0,	  # filename of Storable from previous run
};

my $exiftool;	       # for collecting exif data we are interested in

sub new {
    my($class, $hash) = @_;
    my $self = { };
    if (ref $hash) {		# switch to user's conf + my defaults
	while (my($k, $v) = each %$conf) {
	    $hash->{$k} = $v unless $hash->{$k};
	}
	$conf = $hash;
    }
    $self->{conf} = $conf;
    $exiftool = new Image::ExifTool;
    $exiftool->Options(FastScan => 1,
		       DateFormat => $conf->{datefmt});
    $conf->{dbfile} or carp "{dbfile} required" and return undef;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$conf->{dbfile}",  "", "",
			   { RaiseError => 1, AutoCommit => 1 })
	or die $DBI::errstr;
    $self->{dbh} = $dbh;
    return bless $self, $class;
}

sub conf {		    # return value of given key, or whole hash
    my($self, $key, $value) = @_;
    if (defined $value) {
	return $self->{conf}{$key} = $value;
    } elsif ($key) {
	return $self->{conf}{$key} || undef;
    }
    retrun $self->{conf};	# whole configuration hash
}

sub dbh {
    return $_[0]->{dbh};
}

# create the database
sub create {
    my $self = shift;
    my $file = $self->conf('dbfile');
    -s $file and return 1;	# fix this!!!!
    `sqlite3 $file < db.sql`;	# hack!!!
    return 1;
}

sub disconnect {
    my $self = shift;
    my $dbh = $self->dbh;
    $dbh->disconnect;
}

sub schema {
    my $self = shift;
    $self->{schema} or $self->{schema} = LPDB::Schema->connect(
	sub { $self->dbh });
    return $self->{schema};
}

my $schema;  # global hack for File::Find !!! but we'll never find
	     # more than once per process, so this will work

# recursively add given directory or . to picasa database
sub update {
    my $self = shift;
    my $dir = shift || '.';
    $schema = $self->schema;	# global for File::Find's _wanted !!!
#    $db = $self;
    warn "update $dir\n" if $conf->{debug};
    find ({ no_chdir => 1,
	    preprocess => sub { sort @_ },
	    wanted => \&_wanted,
	    #	    postprocess => $conf->{update},
	  }, $dir);
}

sub dirfile { # similar to fileparse, but leave trailing / on directories
    my($path) = @_;
    my $end = $path =~ s@/+$@@ ? '/' : '';
    my($dir, $file) = ('/', '');
    ($dir, $file) = ($1, $2) if $path =~ m!(.*/)([^/]+)$!;
    return "$dir", "$file$end";
}
# add a file or directory to the database, adapted from Picasa.pm
sub _wanted {
    my($dir, $file) = dirfile $_;
    my $modified = (stat $_)[9]; 
    #    $dir = '' if $dir eq '.';
    warn "checking: $modified\t$_\n";
    if ($file eq '.picasa.ini' or $file eq 'Picasa.ini') {
	# &_understand($db, _readfile($_));
	# $db->{dirs}{$dir}{'<<updated>>'} = $modified;
	return;
    } elsif ($file =~ /^\..+/ or $file eq 'Originals') { # ignore hidden files
	$File::Find::prune = 1;
	return;
    }
    $File::Find::prune = 1, return if $file =~ /$conf->{reject}/;
    if (-f $_) {
	return unless $file =~ /$conf->{keep}/;
	my $key = $_;
	$key =~ s@\./@@;
	return unless -f $key and -s $key > 100;
	my $row = $schema->resultset('Picture')->find_or_create(
	    {
		filename	=> $key,
	    });
	return if $row->modified || 0 >= $modified;
	my $info = $exiftool->ImageInfo($key);
	return unless $info;
	return unless $info->{ImageWidth} && $info->{ImageHeight};
	my $or = $info->{Orientation} || '';
	my $rot = $or =~ /Rotate (\d+)/i ? $1 : 0;
	my $swap = $rot == 90 || $rot == 270 || 0;
	my $time = $info->{DateTimeOriginal} || $info->{CreateDate}
	|| $info->{ModifyDate} || $info->{FileModifyDate} || 0;
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

	my %tags; map { $tags{$_}++ } split /,\s*/,
		      $info->{Keywords} || $info->{Subject} || '';
	# 	tag	=> \%tags,
	# 	}
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
    # unless ($db->{dir} and $db->{file}) {
    # 	my $tmp = $db->filter(qw(/));
    # 	$tmp and $tmp->{children} and $db->{dir} = $db->{file} = $tmp;
    # }
    &{$conf->{update}};
}

1;				# LPDB.pm
