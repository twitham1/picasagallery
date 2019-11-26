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
    my $self = { };
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
#     return map { $_->string } @tags;
# }

# # tags of gallery
# sub tagsdir {
#     my $self = shift;
#     my $root = shift;
#     my $schema = $self->schema;
#     my $rs = $schema->resultset('Picture')->search(
# 	{ filename => { like => "$root%" } },
# 	{ prefetch => 'picture_tags',
# 	  columns => ['file_id']});
#     my %tag;
#     my $tagged = 0;
#     while (my $pic = $rs->next) {
# 	my @tags = map { $_->string } $pic->tags;
# 	map { $tag{$_}++ } @tags;
# 	print "$pic: @tags\n";
# 	@tags and $tagged++;
#     }
#     my $n = keys %tag;
#     print "$n tags in $tagged pics\n";
#     return $tagged, sort keys %tag;
# }
# sub tagsvir {
#     my $self = shift;
#     my $root = shift;
#     my $schema = $self->schema;

#     my $path = $schema->resultset('Path')->search(
# 	{ path => { like => "$root%" } },
# 	# {
# 	#     prefetch => 'picture_paths',
# 	# }
# 	);
#     my @pathids = map { $_->path_id } $path->all;
#     print "pathids: @pathids\n";

#     # for my $each ($path->all) {
#     # 	print "\t$each\n";	# children: paths
#     # 	for my $pic ($each->picture_paths) {
#     # 	    print "\t\t$pic\n";
#     # 	    for my $this ($pic->file_id) {
#     # 		print "\t\t\t$this\n";
#     # 	    }
#     # 	}
#     # }

#     my $files = $schema->resultset('PicturePath')->search(
#     	{ path_id => \@pathids },
# 	{ group_by => [ 'file_id' ] }
#     	);
#     my @fileids = map { $_->file_id } $files->all;
#     print "fileids: @fileids\n";

#     my $pics = $schema->resultset('Picture')->search(
#     	{ file_id => \@fileids },
#     	);
#     my @pics = $pics->all;
#     print "pics: @pics\n";

#     my $tags = $schema->resultset('PictureTag')->search(
#     	{ file_id => \@fileids },
# 	{ group_by => [ 'tag_id' ] }
#     	);
#     my @tagids = map { $_->tag_id } $tags->all;
#     print "tagids: @tagids\n";

#     my $strings = $schema->resultset('Tag')->search(
#     	{ tag_id => \@tagids },
# 	{ group_by => [ 'tag_id' ] }
#     	);
#     my @tags = map { $_->string } $strings->all;
#     print "tags: @tags\n";

# #     # 	my $id = $ref->path_id;
# #     # 	print "id: $id\n";
# #     # }
# #     # { prefetch => 'picture_paths',
# #     #   columns => ['file_id', 'path_id']});
# #     my %tag;
# #     my $tagged = 0;
# # #    for my $path ($rs->
# #     for my $pic ($rs->files) {
# # 	my $one = $pic->tags;
# # 	warn "ppath: $one\n";
# # 	next;
# # 	my @tags = map { $_->string } $pic->tags;
# # 	map { $tag{$_}++ } @tags;
# # 	print "$pic: @tags\n";
# # 	@tags and $tagged++;
# #     }
# #     my $n = keys %tag;
# #     print "$n tags in $tagged pics\n";
# #     return $tagged, sort keys %tag;
# }

# verbatim from Picasa.pm
sub dirfile { # similar to fileparse, but leave trailing / on directories
    my($path) = @_;
    my $end = $path =~ s@/+$@@ ? '/' : '';
    my($dir, $file) = ('/', '');
    ($dir, $file) = ($1, $2) if $path =~ m!(.*/)([^/]+)$!;
    return "$dir", "$file$end";
}

# ------------------------------------------------------------
# twiddle location in the virtual tree and selected node (file):
# adapted from Picasa.pm

# move to the virtual location of given picture
sub goto {
    my($self, $pic) = @_;
    $pic =~ s@/+@/@g;
    ($self->{dir}{dir}, $self->{dir}{file}) = dirfile $pic;
    $self->up;
}

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
	  # string => { '!=' => undef }, # example filtering
	  # caption => { '!=' => undef }, # user will toggle these!
	},
	{ group_by => 'file_id', # count each file only once
	  order_by => 'time' }); # in time order

    my $stats = $data->{stats} = $self->stats($virt);

    {
	my $caps = $virt->search({ caption => {'!=', undef} });
	$stats->{captioned} = $caps->count;
	$caps = $caps->search(undef,
			      { group_by => 'caption',
				order_by => 'caption' });
	$caps = $caps->get_column('caption');
	my @caps = $caps->all;
	$stats->{caption} = \@caps;
    }
    {
	my $tags = $virt->search({ string => { '!=', undef }});
	$stats->{tagged} = $tags->count;
	$tags = $tags->search(undef,
			      { group_by => 'string',
				order_by => 'string' });
	$tags = $tags->get_column('string');
	my @tags = $tags->all;
	$stats->{tag} = \@tags;
    }

    print Dumper $data;
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

#     return $data;
}
# TODO: option to automove to next directory if at end of this one
sub next {
}
# TODO: option to automove to prev directory if at beginning of this one
sub prev {
}
# back up into parent directory, with current file selected
sub up {
}
# step into {file} of current {dir}
sub down {
}
# reapply current filters, moving up if needed
sub filtermove {
}

1;				# LPDB.pm
