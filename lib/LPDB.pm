# ABSTRACT: LPDB = Local Picture metadata in sqlite

package LPDB;

=head1 NAME

LPDB - Local Picture metadata in sqlite

=cut

use strict;
use warnings;
use Carp;
use DBI;
use Image::ExifTool qw(:Public);
use LPDB::Schema;		# from dbicdump dbicdump.conf
use LPDB::Filesystem qw(update);
use Data::Dumper;

my $conf = {		       # override any keys in first arg to new
    reject	=> 'PATTERN OF FILES TO REJECT',
    keep	=> '(?i)\.jpe?g$',	# pattern of files to keep
    # datefmt	=> '%Y-%m-%d.%H:%M:%S', # must be sortable order
    datefmt	=> undef,		# undef == EXIF format
    update	=> sub {},  # callback after each directory is scanned
    debug	=> 0,	    # diagnostics to STDERR
    filter	=> {},	    # filters
    sqltrace	=> 0,	    # SQL to STDERR from DBIx::Class::Storage
    editpath	=> 0,	# optional sub to return modified virtual path
#    sortbyfilename => 0,  # boolean: sort by filename rather than time
#    metadata	=> 0,	  # filename of Storable from previous run
};

# my $exiftool;	       # global for File::Find's wanted

sub new {
    my($class, $hash) = @_;
    my $self = {
	dir => { qw(dir / file /) },
    };
    if (ref $hash) {		# switch to user's conf + my defaults
	while (my($k, $v) = each %$conf) {
	    $hash->{$k} = $v unless $hash->{$k};
	}
	$conf = $hash;
    }
    $ENV{DBIC_TRACE} = $conf->{sqltrace} || 0;

    $self->{conf} = $conf;
    $conf->{dbfile} or carp "{dbfile} required" and return undef;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$conf->{dbfile}",  "", "",
			   { RaiseError => 1, AutoCommit => 1 })
	or die $DBI::errstr;
    $self->{dbh} = $dbh;
    # $exiftool = new Image::ExifTool;
    # $exiftool->Options(FastScan => 1,
    # 		       DateFormat => $conf->{datefmt});

    return bless $self, $class;
}

sub conf {	     # return whole config, or key, or set key's value
    my($self, $key, $value) = @_;
    if (defined $value) {
	$key eq 'sqltrace'
	    and $ENV{DBIC_TRACE} = $value;
	return $self->{conf}{$key} = $value;
    } elsif ($key) {
	return $self->{conf}{$key} || undef;
    }
    return $self->{conf};	# whole configuration hash
}

sub dbh {
    return $_[0]->{dbh};
}

# create the database
sub create {
    my $self = shift;
    my $file = $self->conf('dbfile');
    -s $file and return 1;
    my $sql = 'LPDB.sql';
    for (@INC) {
	my $this = "$_/$sql";
	warn "testing $this\n";
	-f $this and $sql = $this and last;
    }
    warn "create: running sqlite3 $file < $sql\n";
    print `sqlite3 $file < $sql`; # hack!!! any smarter way?
    $sql =~ s/.sql/-views.sql/;
    print `sqlite3 $file < $sql`; # add the views
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

# stats of given result set
sub stats {
    my $self = shift;
    my $rs = shift;
    my $num = $rs->count
	or return {};
    my($first, $middle, $last) = map { $_->filename }
    ($rs->all)[0, $num/2, -1];	# smarter way to get these?
    my $bytes = $rs->get_column('bytes');
    my $width = $rs->get_column('width');
    my $height = $rs->get_column('height');
    my $time = $rs->get_column('time');
    return {
	files => $num,
	bytes => $bytes->sum,
	width => $width->sum,
	height => $height->sum,
	begintime => $time->min,
	endtime => $time->max,
	first => $first,
	middle => $middle,
	last => $last,
    };
}

# # tags of 1 picture
# sub tags {
#     my $self = shift;
#     my $file = shift;
#     my $schema = $self->schema;
#     my $rs = $schema->resultset('Picture')->search(
# 	{ filename => $file },
# 	{ columns => ['file_id']});
#     my $single = $rs->single;
#     my @tags = $single->tags;
#     return map { $_->tag } @tags;
# }

# pass stat name and 'dir' to get the parent, else get the 'file'
sub stat {
    my $self = shift;
    my $stat = shift || 'files';
    my $which = shift || 'file';
    return $self->{$which}{stats}{$stat} || 0,
	$self->{$which}{stats}{$stat} || 0,
}
sub bytes { shift->stat('bytes', @_) }
sub files { shift->stat('files', @_) }
sub width { shift->stat('width', @_) }
sub height { shift->stat('height', @_) }
sub tagged { shift->stat('tagged', @_) }
sub captioned { shift->stat('captioned', @_) }

sub children {			# pass dir or file
    my $self = shift;
    my $which = shift || 'file';
    return $self->{$which}{children} || [];
}

# verbatim from Picasa.pm
sub dirfile { # similar to fileparse, but leave trailing / on directories
    my($path) = @_;
    my $end = $path =~ s@/+$@@ ? '/' : '';
    my($dir, $file) = ('/', '');
    ($dir, $file) = ($1, $2) if $path =~ m!(.*/)([^/]+)$!;
    return "$dir", "$file$end";
}

# ------------------------------------------------------------
# adapted from Picasa.pm

# given a virtual path, return all data known about it with current filters
sub filter {
    my($self, $path, $opt) = @_;
    my $schema = $self->schema;
    unless ($self->{root}) {
	my $paths = $schema->resultset('Path')->search();
	while (my $one = $paths->next) {
	    $self->{root}{$one->path} = $one->path_id;
	}
#	print Dumper $self->{root};
    }
    $opt or $opt = 0;
    my $data = {};
#    my @files;			# files of this parent, to find center
    my %child;			# children of this parent
    my %face;			# faces in this path
    my %album;			# albums in this path
    my %tag;			# tags in this path
    my %done;			# files that have been processed
    my @ss;			# slide show pictures
    $path =~ s@/+@/@g;
    ($data->{dir}, $data->{file}) = dirfile $path;
    warn "filter:$path\n" if $conf->{debug};

    my $sort;
    @$sort = keys %{$self->{root}};
    for my $str (@$sort) {
	next unless 0 == index($str, $path); # match
	my $rest = substr $str, length $path;
	$rest =~ s!/.*!/!;
	$rest and $child{$rest}++; # entries in this directory
    }
    $data->{children} = [ sort keys %child ];
    my $virt = $schema->resultset('PathView')->search(
	{ path => { like => "$path%" },
	  # tag => { '!=' => undef }, # example filtering
	  # caption => { '!=' => undef }, # user will toggle these!
	},
	{ group_by => 'file_id', # count each file only once
	  order_by => 'time' }); # in time order

    my $stats = $data->{stats} = $self->stats($virt);

    {
	my $caps = $virt->search({ caption => {'!=', undef} });
	$stats->{captioned} = $caps->count;
	# $caps = $caps->search(undef,
	# 		      { group_by => 'caption',
	# 			order_by => 'caption' });
	# $caps = $caps->get_column('caption');
	# my @caps = $caps->all;
	# $stats->{caption} = \@caps;
    }
    {
	my $tags = $virt->search({ tag => { '!=', undef }});
	$stats->{tagged} = $tags->count;
	# $tags = $tags->search(undef,
	# 		      { group_by => 'tag',
	# 			order_by => 'tag' });
	# $tags = $tags->get_column('tag');
	# my @tags = $tags->all;
	# $stats->{tag} = \@tags;
    }

    #    print Dumper $data;
    
#     my $begin = $conf->{filter}{age} ? strftime $conf->{datefmt},
#     localtime time - $conf->{filter}{age} : 0;
#     if (!$sort or !$self->{done} or $self->{done} and !$done) {
# 	@$sort = sort keys %{$self->{root}};
# 	$self->{done} and $done = 1;
# #	warn "SORTED ", scalar @$sort, " paths, done = $self->{done}, $done\n";
#     }
#     for my $str (@$sort) { # for each picture file
# 	next unless 0 == index($str, $path); # match
# 	next unless my $filename = $self->{root}{$str}; # filename -> path id

#	next unless my $this = $self->{pics}{$filename}; # metadata

# 	unless ($opt eq 'nofilter') {
# 	    warn "filtering $str for filter ", Dumper $conf->{filter}
# 	    if $conf->{debug} > 1;
# 	    next if $conf->{filter}{Stars}	and !$this->{stars};
# 	    next if $conf->{filter}{Uploads}	and !$this->{uploads};
# 	    next if $conf->{filter}{Faces}	and !$this->{faces};
# 	    next if $conf->{filter}{Albums}	and !$this->{albums};
# 	    next if $conf->{filter}{Captions}	and !$this->{caption};
# 	    next if $conf->{filter}{Tags}	and !$this->{tags};
# 	    next if $conf->{filter}{age} and $this->{time} lt $begin;
# 	}

# 	if ($opt eq 'slideshow') {
# 	    push @ss, $str;
# 	    next;
# 	}

# 	warn "looking at ($path) in ($str)\n" if $conf->{debug} > 1;
# 	if ($opt eq 'nofilter') { # average mtime for directory thumbnails
# 	    next if $done{$filename}++;
# 	    $data->{mtime} += $this->{updated};
# 	} elsif ($str eq $path) { # filename: copy metadata
# 	    map { $data->{$_} = $this->{$_} } keys %$this;
# 	} else {		# directory: sum metadata
# 	    my $rest = substr $str, length $path;
# 	    $rest =~ s!/.*!/!;
# 	    $rest and $child{$rest}++; # entries in this directory
# 	    next if $done{$filename}++;
# 	    warn "$path: $str ($rest)\n" if $conf->{debug} > 1;
# 	    for my $num
# 		(qw/bytes stars uploads faces albums tags width height/) {
# 		    $data->{$num} += $this->{$num};
# 	    }
# 	    map { $face{$_}++ }  keys %{$this->{face}};
# 	    map { $album{$_}++ } keys %{$this->{album}};
# 	    map { $tag{$_}++ }   keys %{$this->{tag}};
# 	    $data->{caption} += $this->{caption} ? 1 : 0;
# 	}
# 	push @files, $filename;
# 	$data->{files}++;

# 	$data->{time} = $this->{time} and
# 	    $data->{first} = $filename unless
# 	    $data->{time} && $data->{time} le $this->{time};

# 	$data->{endtime} = $this->{time} and
# 	    $data->{last} = $filename unless
# 	    $data->{endtime} && $data->{endtime} gt $this->{time};

# 	next if $opt eq 'nofilter';
# 	$data->{pixels} += $this->{width} * $this->{height};
#     }
#     $data->{physical} = $files[$data->{files} / 2]; # middle picture
#     if ($data->{files} > 2) {			    # not first or last
#     	$data->{physical} = $files[$data->{files} / 2 - 1]
#     	    if $data->{physical} eq $data->{first} or
#     	    $data->{physical} eq $data->{last};
#     	$data->{physical} = $files[$data->{files} / 2 + 1]
#     	    if $data->{physical} eq $data->{first} or 
#     	    $data->{physical} eq $data->{last};
#     }
#     if ($opt eq 'nofilter') {
# 	$data->{mtime} and $data->{mtime} =
# 	    int($data->{mtime} / $data->{files});
# 	return $data;
#     }
#     $opt eq 'slideshow' and return @ss;

#     $data->{children} = [sort keys %child]; # maybe sort later? sort by option?
#     $data->{face}  or $data->{face}  = \%face;
#     $data->{album} or $data->{album} = \%album;
#     $data->{tag}   or $data->{tag}   = \%tag;
#     warn "filtered $path: ", Dumper $data if $conf->{debug} > 2;

    return $data;
}

# twiddle location in the virtual tree and selected node (file):

# nearly verbatim from Picasa.pm

# move to the virtual location of given picture
sub goto {
    my($self, $pic) = @_;
    $pic =~ s@/+@/@g;
    ($self->{dir}{dir}, $self->{dir}{file}) = dirfile $pic;
    $self->up;
}

# TODO: option to automove to next directory if at end of this one
sub next {
    my($self, $n, $pindexdone) = @_;
    $self->{pindex} = $self->{index} unless $pindexdone;
    $self->{index} += defined $n ? $n : 1;
    my @child = @{$self->{dir}{children}};
    my $child = @child;
    $self->{index} = $child - 1 if $self->{index} >= $child;
    $self->{index} = 0 if $self->{index} < 0;
    $self->{file} = $self->
	filter("$self->{dir}{dir}$self->{dir}{file}$child[$self->{index}]");
}
# TODO: option to automove to prev directory if at beginning of this one
sub prev {
    my($self, $n) = @_;
    $self->{pindex} = $self->{index};
    $self->{index} -= defined $n ? $n : 1;
    my @child = @{$self->{dir}{children}};
    $self->{index} = 0 if $self->{index} < 0;
    $self->{file} = $self->
	filter("$self->{dir}{dir}$self->{dir}{file}$child[$self->{index}]");
}
# back up into parent directory, with current file selected
sub up {
    my($self) = @_;
    my $file = $self->{dir}{file}; # current location should be selected after up
    warn "chdir $self->{dir}{dir}\n" if $conf->{debug};
    $self->{dir} = $self->filter("$self->{dir}{dir}");
    my $index = 0;
    for my $c (@{$self->{dir}{children}}) {
	last if $c eq $file and $file = '!file found!';
	$index++;
    }
    $index = 0 if $file ne '!file found!';
    $self->{pindex} = $self->{index};
    $self->{index} = $index;
    $self->next(0, 1);
}
# step into {file} of current {dir}
sub down {
    my($self) = @_;
    return 0 unless $self->{file}{file} =~ m!/$!;
    warn "chdir $self->{file}{dir}$self->{file}{file}\n" if $conf->{debug};
    $self->{dir} = $self->filter("$self->{file}{dir}$self->{file}{file}");
    $self->{index} = -1;
    $self->next;
    return 1;
}

# reapply current filters, moving up if needed
sub filtermove {
    my($self) = @_;
    while (($self->{dir} = $self->filter("$self->{dir}{dir}$self->{dir}{file}")
	    and !$self->{dir}{files})) {
	$self->up;
	last if $self->{dir}{file} eq '/';
    }
    $self->next(0, 1);
}

1;				# LPDB.pm
