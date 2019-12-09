# Picasa.pm

# ABSTRACT: perl access to local Picasa picture data (faces, albums, stars, etc.)

# by twitham@sbcglobal.net, 2013-06

# {dirs}{<dir>}{<file>} => { field => value} is the raw .picasa.ini data only
# {pics}{<path>} => { metadata } is all data for each picture, in perl format
# {root}{virtual path} => physicalpath is the virtual hierarchy
# {dir} => { current virtual "directory/" after filtering/navigating }
# {file} => { current virtual focused "file/?" after filtering/navigating }
# {index} => current file index ( should this be in {dir} ? )
# {pindex} => previous file index ( needed by GUI to update browser )
# {album}{<id>} => { field => value } is album information
# {contact}{<id>} => { 'name;email;id' => count } is contact data
# {tags}{name} => count

package Picasa;
use strict;
use warnings;
use File::Find;
use File::Basename;
use Image::ExifTool qw(:Public);
use Data::Dumper;
use Storable;			# for optional metadata cache
use POSIX qw/strftime/;
use Time::HiRes qw(gettimeofday tv_interval); # for profiling

my $db;	    # picasa database pointer needed for File::Find's _wanted.
my $odb;    # old cached db from last run, if any - TODO!!!

my $conf = {		       # override any keys in first arg to new
    reject	=> 'PATTERN OF FILES TO REJECT',
    keep	=> '(?i)\.jpe?g$',	# pattern of files to keep
    datefmt	=> '%Y-%m-%d.%H:%M:%S', # must be sortable order
    update	=> sub {},  # callback after each directory is scanned
    debug	=> 0,	    # diagnostics to STDERR
    filter	=> {},	    # filters
    editpath	=> 0,	# optional sub to return modified virtual path
    sortbyfilename => 0,  # boolean: sort by filename rather than time
    metadata	=> 0,	  # filename of Storable from previous run
};

my $exiftool;	       # for collecting exif data we are interested in
my $modified;	       # mtime of current file

# return new empty picasa database object
sub new {
    my $class = shift;
    my $self;
    if (ref(my $hash = shift)) {	# switch to user's conf + my defaults
	while (my($k, $v) = each %$conf) {
	    $hash->{$k} = $v unless $hash->{$k};
	}
	$conf = $hash;
    }
    $exiftool = new Image::ExifTool;
    $exiftool->Options(FastScan => 1,
		       DateFormat => $conf->{datefmt});
    if (($conf->{metadata} and -f $conf->{metadata})) { # use previous data
	$self = retrieve $conf->{metadata} or
	    die "can't retrieve $conf->{metadata}: $!";
	$self->{done} = 0;	# but move to root first
	$self->{dir} = $self->{file} = $self->filter('/');
	$odb = $self;		# save global pointer to previous data
	$db = {};		# write new db from scratch
	bless($db, $class);	# hack!!!!
    } else {			# use currently scanning data
	$self = $db = $odb = {};
    }
    $db->{index} = $db->{pindex} = $db->{done} = $db->{sofar} = 0;
    $self->{index} = $self->{pindex} = $self->{done} = $self->{sofar} = 0;
    bless ($self, $class);
#    warn Dumper $self;
    return $self;
}

# find pictures and picasa data in given directories
sub recursedirs {
    my $self = shift;
    my $current = $self;
    for (@_) {
	readdb($self, $_);
    }
    unless ($self eq $db) {
	$self = $db;		# now start using new db
	map { $self->{$_} = $current->{$_} } qw/dir file index/;
    }
    $self->{done} = 1;		# data complete!
    &{$conf->{update}};
    return $self;
}

# recursively add given directory or . to picasa database
sub readdb {
    my $self = shift;
    my $dir = shift || '.';
#    $db = $self;
    warn "readdb $dir\n" if $conf->{debug};
    find ({ no_chdir => 1,
	    preprocess => sub { sort @_ },
	    wanted => \&_wanted,
#	    postprocess => $conf->{update},
	  }, $dir);
}

# twiddle location in the virtual tree and selected node (file):

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

sub dirfile { # similar to fileparse, but leave trailing / on directories
    my($path) = @_;
    my $end = $path =~ s@/+$@@ ? '/' : '';
    my($dir, $file) = ('/', '');
    ($dir, $file) = ($1, $2) if $path =~ m!(.*/)([^/]+)$!;
    return "$dir", "$file$end";
}

# move to the virtual location of given picture
sub goto {
    my($self, $pic) = @_;
    $pic =~ s@/+@/@g;
    ($self->{dir}{dir}, $self->{dir}{file}) = dirfile $pic;
    $self->up;
}

# given a virtual path, return all data known about it with current filters
{
    my $sort; my $done = 0;
sub filter {
    my($self, $path, $opt) = @_;
    $self->{root} or return;
    my $t0 = [gettimeofday];
    $opt or $opt = 0;
    my $data = {};
    my @files;			# files of this parent, to find center
    my %child;			# children of this parent
    my %face;			# faces in this path
    my %album;			# albums in this path
    my %tag;			# tags in this path
    my %done;			# files that have been processed
    my @ss;			# slide show pictures
    $path =~ s@/+@/@g;
    ($data->{dir}, $data->{file}) = dirfile $path;
#    warn "filter:$path\n" if $conf->{debug};
    my $begin = $conf->{filter}{age} ? strftime $conf->{datefmt},
    localtime time - $conf->{filter}{age} : 0;
    if (!$sort or !$self->{done} or $self->{done} and !$done) {
	@$sort = sort keys %{$self->{root}};
	$self->{done} and $done = 1;
#	warn "SORTED ", scalar @$sort, " paths, done = $self->{done}, $done\n";
    }
    for my $str (@$sort) { # for each picture file
	next unless 0 == index($str, $path); # match
	next unless my $filename = $self->{root}{$str}; # physical path
	next unless my $this = $self->{pics}{$filename}; # metadata

	unless ($opt eq 'nofilter') {
	    warn "filtering $str for filter ", Dumper $conf->{filter}
	    if $conf->{debug} > 1;
	    next if $conf->{filter}{Stars}	and !$this->{stars};
	    next if $conf->{filter}{Uploads}	and !$this->{uploads};
	    next if $conf->{filter}{Faces}	and !$this->{faces};
	    next if $conf->{filter}{Albums}	and !$this->{albums};
	    next if $conf->{filter}{Captions}	and !$this->{caption};
	    next if $conf->{filter}{Tags}	and !$this->{tags};
	    next if $conf->{filter}{age} and $this->{time} lt $begin;
	}

	if ($opt eq 'slideshow') {
	    push @ss, $str;
	    next;
	}

	warn "looking at ($path) in ($str)\n" if $conf->{debug} > 1;
	if ($opt eq 'nofilter') { # average mtime for directory thumbnails
	    next if $done{$filename}++;
	    $data->{mtime} += $this->{updated};
	} elsif ($str eq $path) { # filename: copy metadata
	    map { $data->{$_} = $this->{$_} } keys %$this;
	} else {		# directory: sum metadata
	    my $rest = substr $str, length $path;
	    $rest =~ s!/.*!/!;
	    $rest and $child{$rest}++; # entries in this directory
	    next if $done{$filename}++;
	    warn "$path: $str ($rest)\n" if $conf->{debug} > 1;
	    for my $num
		(qw/bytes stars uploads faces albums tags width height/) {
		    $data->{$num} += $this->{$num};
	    }
	    map { $face{$_}++ }  keys %{$this->{face}};
	    map { $album{$_}++ } keys %{$this->{album}};
	    map { $tag{$_}++ }   keys %{$this->{tag}};
	    $data->{caption} += $this->{caption} ? 1 : 0;
	}
	push @files, $filename;
	$data->{files}++;

	$data->{time} = $this->{time} and
	    $data->{first} = $filename unless
	    $data->{time} && $data->{time} le $this->{time};

	$data->{endtime} = $this->{time} and
	    $data->{last} = $filename unless
	    $data->{endtime} && $data->{endtime} gt $this->{time};

	next if $opt eq 'nofilter';
	$data->{pixels} += $this->{width} * $this->{height};
    }
    $data->{physical} = $files[$data->{files} / 2]; # middle picture
    if ($data->{files} > 2) {			    # not first or last
    	$data->{physical} = $files[$data->{files} / 2 - 1]
    	    if $data->{physical} eq $data->{first} or
    	    $data->{physical} eq $data->{last};
    	$data->{physical} = $files[$data->{files} / 2 + 1]
    	    if $data->{physical} eq $data->{first} or 
    	    $data->{physical} eq $data->{last};
    }
    my $elapsed = tv_interval($t0);
    warn "filter $path took $elapsed\n" if $conf->{debug};
    if ($opt eq 'nofilter') {
	$data->{mtime} and $data->{mtime} =
	    int($data->{mtime} / $data->{files});
	return $data;
    }
    $opt eq 'slideshow' and return @ss;

    $data->{children} = [sort keys %child]; # maybe sort later? sort by option?
    $data->{face}  or $data->{face}  = \%face;
    $data->{album} or $data->{album} = \%album;
    $data->{tag}   or $data->{tag}   = \%tag;
    warn "filtered $path: ", Dumper $data if $conf->{debug} > 2;

    return $data;
}
}

# add picture to virtual path
sub _addpic2path {
    my($self, $virt, $file) = @_;
    $conf->{editpath} and $virt = &{$conf->{editpath}}($virt);
    $self->{root}{$virt} = $file;
}

# return all directories of the database
sub dirs {
    my $self = shift;
    return keys %{$self->{dirs}};
}

# return the pictures of given directory
sub pictures { # renamed from pics 2019/11, could break old scripts!!!
    my $self = shift;		# but apparently I never used this...
    my $dir = shift or return ();
    return grep !/^[\[<]/, keys %{$self->{dirs}{$dir}};
}

# return the metadata of given picture path
sub pics {
    my $self = shift;
    my $file = shift or return {};
    return $self->{pics}{$file} || {};
}

# return all contacts of the database
sub contacts {
    my $self = shift;
    return keys %{$self->{contact}};
}

# convert contact ID to most common readable name
sub contact2person {
    my($self, $id) = @_;
    my $this = $self->{contact}{$id};
    for my $string (sort { $this->{$b} <=> $this->{$a}
		    } keys %$this) {
	return $1 if $string =~ /^([^;]+);/;
    }
    return (keys %$this)[0] || '';
}

# return a picasa picture object for given $dir $pic
sub picasa {
    my($self, $dir, $pic) = @_;
    return {} unless $dir;
    return $self->{dirs}{$dir} || {} unless $pic;
    return $self->{dirs}{$dir}{$pic} || {};
}

# return hash of { id => [ NW, SE] } of faces in given $dir $pic
sub faces {
    my($self, $dir, $pic, $rot) = @_;
    my $ret = {};
    return $ret unless $dir and $pic;
    my $this = $self->{dirs}{$dir}{$pic};
    return $ret unless $this and $this->{faces};
    for my $string (split ';', $this->{faces}) {
	my($rect, $id) = split ',', $string;
	my($w, $n, $e, $s) = ($self->rect($rect));
#	warn "$w, $n, $e, $s\n";
	if ($rot == 0) {	# most common: no change
	    $ret->{$id} = [$w, $n, $e, $s];
	} elsif ($rot == 90) {
	    $ret->{$id} = [1 - $s, $w, 1 - $n, $e];
	} elsif ($rot == 180) {
	    $ret->{$id} = [1 - $e, 1 - $s, 1 - $w, 1 - $n];
	} elsif ($rot == 270) {
	    $ret->{$id} = [$n, 1 - $e, $s, 1 - $w];
	} else {		# assume no change
	    $ret->{$id} = [$w, $n, $e, $s];
	}
    }
    return $ret;
}

# return hash of {album ids} in $pic
sub albums {
    my($self, $dir, $pic) = @_;
    my $ret = {};
    return $ret unless $dir and $pic;
    my $this = $self->{dirs}{$dir}{$pic};
    return $ret unless $this and $this->{albums};
    map { $ret->{$_}++ } split ',', $this->{albums};
    return $ret;
}

sub star {
    my($self, $dir, $pic) = @_;
    return 0 unless $dir and $pic;
    my $this = $self->{dirs}{$dir}{$pic};
    return 0 unless $this and $this->{star};
    return 1;
}

sub uploads {
    my($self, $dir, $pic) = @_;
    return 0 unless $dir and $pic;
    my $this = $self->{dirs}{$dir}{$pic};
    return scalar grep /^IIDLIST_/, keys %$this;
}

# write the .picasa.ini in given $dir, backing up the original once
sub save {
    my($self, $dir) = @_;
    my $out = "$dir/.picasa.ini";
    -d $dir or mkdir $dir or die "can't mkdir $dir: $!\n";
    my $was = '';
    if (open my $fh, $out) {
	$was .= $_ while (<$fh>);
    }
    my $now = '';
    for my $file (sort keys %{$self->{dirs}{$dir}}) {
	next if $file =~ m@/$@;	# skip subdirs
	next if $file =~ m@^<<\w+>>$@; # skip internal metadata
	my $ref = $self->{dirs}{$dir}{$file};
	$file =~ /^\[.album:(\w+)\]$/ and $ref = $self->{album}{$1};
	if (my @key = sort keys %$ref) {
	    $now .= ($file =~ /\[.+\]/ ? $file : "[$file]") . "\r\n";
	    for my $f (@key) {
		$now .= "$f=$ref->{$f}\r\n";
	    }
	}
    }
    if ($was eq $now) {
#	print "# $out unchanged\n" if $conf->{debug} < 0;
    } else {
	if ($conf->{debug} < 0) {
	    print "# $out ", length($was),
	    " bytes NOT being replaced by ", length($now), " bytes\n";
	    my $tmp;
	    open $tmp, '>', "/tmp/a$$" and print $tmp $was and close $tmp;
	    open $tmp, '>', "/tmp/b$$" and print $tmp $now and close $tmp;
	    print `diff -u /tmp/a$$ /tmp/b$$`;
	    unlink "/tmp/a$$", "/tmp/b$$";
	    return 0;
	}
	print "# $out ", length($was),
	" bytes being replaced by ", length($now), " bytes\n";
	if (-f $out) {		# backup the original, but only once
		my $tmp = $out . '_original';
		rename $out, $tmp or warn "$0: can't rename $out $tmp: $!\n";
	}
	open my $fh, '>', $out or warn "can't write $out: $!\n" and return 0;
	print $fh $now;
	close $fh or warn "can't close $out: $!\n" and return 0;
	unlink $out unless -s $out;
    }
    return 1;
}

# return NW, SE coordinates encoded in $rect
sub rect {
    my($self, $rect) = @_;
    my @out;
    return () unless $rect =~ s/rect64\((\w+)\)/0000000000000000$1/;
    $rect =~ s/.*(\w{16})$/$1/;
    while ($rect =~ s/(....)//) {
	push @out, hex($1) / 65536;
    }
    return @out;
}

# merge $srcdir/$srcpic's data into $dstdir/[$dstpic];
sub merge {
    my($self, $srcdir, $srcpic, $dstdir, $dstpic) = @_;
    $dstpic = $srcpic unless $dstpic;
    for my $c ($srcpic, grep /\[(.album:\w+|Contacts\d*)\]/,
	       keys %{$self->{dirs}{$srcdir}}) {
	my $tmp = $self->_merge($self->{dirs}{$srcdir}{$c},
				$self->{dirs}{$dstdir}{$c});
	$self->{dirs}{$dstdir}{$c} = $tmp if keys %$tmp;
    }
}

# return ref to hash merge of two hash refs, warning of any conflicts
sub _merge {
    my($self, $a, $b) = @_;
    my %keys;
    my $c = {};
    map { $keys{$_}++ } keys %$a, keys %$b;
    for (sort keys %keys) {
	if (defined $a->{$_} and defined $b->{$_}) {
	    if ($a->{$_} eq $b->{$_}) {
		$c->{$_} = $a->{$_};
	    } elsif ($a->{$_} and ! $b->{$_}) {
		$c->{$_} = $a->{$_};
	    } elsif ($b->{$_} and ! $a->{$_}) {
		$c->{$_} = $b->{$_};
	    } else {
		warn "WARN $_: (keep:) $a->{$_} (lose:) $b->{$_}\n" if $conf->{debug};
		$c->{$_} = $a->{$_};
	    }
	} elsif (defined $a->{$_}) {
	    $c->{$_} = $a->{$_};
	} elsif (defined $b->{$_}) {
	    $c->{$_} = $b->{$_};
	} else {
	    warn "WARN $_: this shouldn't happen: both values undefined\n";
	}
    }
#    print Dumper $a, $b, $c;
    return $c;
}

# add a file or directory to the database
sub _wanted {
#    my($file, $dir) = fileparse $_;
    my($dir, $file) = dirfile $_;
    $modified = (stat $_)[9]; 
#    $dir = '' if $dir eq '.';
    if ($file eq '.picasa.ini' or $file eq 'Picasa.ini') {
	&_understand($db, _readfile($_));
	$db->{dirs}{$dir}{'<<updated>>'} = $modified;
	return;
    } elsif ($file =~ /^\..+/ or $file eq 'Originals') { # ignore hidden files
	$File::Find::prune = 1;
	return;
    }
    $File::Find::prune = 1, return if $file =~ /$conf->{reject}/;
    if (-f $_) {
	return unless $file =~ /$conf->{keep}/;
	$db->{dirs}{$dir}{$file} or $db->{dirs}{$dir}{$file} = {};
	my $key = $_;
	$key =~ s@\./@@;
	my $this;		# metadata for this picture
	if ($odb->{pics}{$key}{updated} and
	    $odb->{pics}{$key}{updated} >= $modified) {
	    $this = $db->{pics}{$key} = $odb->{pics}{$key};
	} else {		# update from exif & .picasa.ini data
	    warn "reading $dir$file\n" if $conf->{debug};
	    return unless -f $key and -s $key > 100;
	    my $info = $exiftool->ImageInfo($key);
	    return unless $info;
	    return unless $info->{ImageWidth} && $info->{ImageHeight};
	    my %tags; map { $tags{$_}++ } split /,\s*/,
			  $info->{Keywords} || $info->{Subject} || '';
	    my $or = $info->{Orientation} || '';
	    my $rot = $or =~ /Rotate (\d+)/i ? $1 : 0;
	    $this = $db->{pics}{$key} = $odb->{pics}{$key} = {
		updated	=> $modified,
		tag	=> \%tags,
		bytes	=> -s $key,
		width	=> $info->{ImageWidth},
		height	=> $info->{ImageHeight},
		time	=> $info->{DateTimeOriginal} || $info->{CreateDate}
		|| $info->{ModifyDate} || $info->{FileModifyDate} || 0,
		caption	=> $info->{'Caption-Abstract'}
		|| $info->{'Description'} || '',
		rot => $rot,
	    };
	    if ($rot == 90 || $rot == 270) {
		($this->{width}, $this->{height}) = 
		    ($this->{height}, $this->{width});
	    }
	}
	$this->{face}	= $db->faces($dir, $file, $this->{rot}); # picasa data for this pic
	$this->{album}	= $db->albums($dir, $file);
	$this->{stars}	= $db->star($dir, $file);
	$this->{uploads} = $db->uploads($dir, $file);
	$this->{faces}	= keys %{$this->{face}} ? 1 : 0; # boolean attributes
	$this->{albums}	= keys %{$this->{album}} ? 1 : 0;
	$this->{tags}	= keys %{$this->{tag}} ? 1 : 0;

	$this->{time} =~ /0000/ and
	    warn "bogus time in $_: $this->{time}\n";
	my $year = 0;
	$year = $1 if $this->{time} =~ /(\d{4})/; # year must be first

	my $vname = "$this->{time}-$file"; # sort files chronologically
	$conf->{sortbyfilename} and $vname = $file; # sort by filename

	# add virtual folders of stars, tags, albums, people
	$this->{stars} and
	    $db->_addpic2path("/[Stars]/$year/$vname", $key);

	for my $tag (keys %{$this->{tag}}) { # should year be here???
	    $db->_addpic2path("/[Tags]/$tag/$vname", $key);
	    $db->{tags}{$tag}++; # all tags with picture counts
	}
	for my $id (keys %{$this->{album}}) { # named user albums
	    next unless my $name = $db->{album}{$id}{name};
	    # putting year in this path would cause albums that span
	    # year boundary to be split to multiple places...
	    $db->_addpic2path("/[Albums]/$name/$vname", $key);
	}

	# add faces / people
	for my $id (keys %{$this->{face}}) {
	    next unless my $name = $db->contact2person($id);
	    $db->_addpic2path("/[People]/$name/$year/$vname", $key);
	}

	# add folders (putting year here would split folders into
	# multiple locations (y/f or f/y); maybe this would be ok?)
#	$db->_addpic2path("/[Folders]/$key", $key);
	(my $timekey = $key) =~ s@[^/]+$@$vname@;
	$db->_addpic2path("/[Folders]/$timekey", $key);

	$odb->{sofar}++;	# count of pics read so far

    } elsif (-d $_) {
	$db->{dirs}{$dir}{"$file/"} or
	    $db->{dirs}{$dir}{"$file/"} = {};
    }
    unless ($db->{dir} and $db->{file}) {
    	my $tmp = $db->filter(qw(/));
    	$tmp and $tmp->{children} and $db->{dir} = $db->{file} = $tmp;
    }
    &{$conf->{update}};
}

# return given .picasa.ini file as a hash
sub _readfile {
    my($file) = @_;
    my $data = {};
    my $fh;
    return $data unless open $fh, $file;
    my $section = '';
    my($name, $dir) = fileparse $file;
    $data->{dir} = $dir;
    while (<$fh>) {
	chomp;
	s/\r*\n*$//;
	s/\&\#(\d{3});/sprintf "%c", oct($1)/eg; # will this corrupt if we write it out later?
	if (/^\[([^\]]+)\]/) {
	    $section = $1;
	} elsif (my($k, $v) = split '=', $_, 2) {
	    $data->{$section}{$k} = $v;
	}
    }
    close $fh or warn $!;
    return $data;
}

# add given .picasa.ini $ini to $pic database
sub _understand {
    my($pic, $ini) = @_;
    for my $k (keys %$ini) {
	if ($k =~ /^Contacts/) {
	    for my $id (keys %{$ini->{$k}}) {
		$pic->{contact}{$id}{$ini->{$k}{$id}}++;
	    }
	} elsif ($k =~ /^\.album:(\w+)$/) {
	    $pic->{dirs}{$ini->{dir}}{"[$k]"} = 1;
	    $pic->{album}{$1} =
		&_merge(undef, $pic->{album}{$1}, $ini->{$k});
	    next;
	} elsif ($k eq 'dir') {
	    next;
	}
	$pic->{dirs}{$ini->{dir}}{
	    -f "$ini->{dir}/$k" ? $k : "[$k]"} = $ini->{$k};
    }
}

1;				# return true
__END__

=pod

=head1 NAME

Picasa - perl access to local Picasa picture database (faces, albums,
stars, etc.)

=head1 SYNOPSIS

    use Picasa;
    use Data::Dumper;

    my $picasa = Picasa->new();		# new hash of metadata
    $picasa = $picasa->recursedirs(@ARGV || '.'); # find info
    print Dumper $picasa->filter('/');  # show total metadata

=head1 DESCRIPTION

The Picasa library recurses through directories collecting information
from .picasa.ini (optional) and image files into a perl hash.  Data
includes image bytes, width, height, captions, tags, original
timestamp and updated timestamp.  Optional .picasa.ini files from
Picasa software may add detected face rectangles, album entries, stars
and upload flags.  This data is used to build a virtual tree that
organizes the images by Folders, Albums, People, Stars and Tags.
Methods are provided to then navigate and filter this tree of images.

The caller can easily store this data structure in a L<Storable> file
on disk.  If one is passed in on future runs, it is used as a cache
and the data is updated only for changed and new files.

L<picasagallery> (see also) is the primary user of this library,
providing a keyboard driven Picasa aware image browser.  But it is
also possible to use this library for other operations such as linking
images into an alternate directory structure and merging the
.picasa.ini files as needed while doing so.  Look in the examples
directory for sample code.

=head1 METHODS

WARNING: The methods are currently incomplete; picasagallery is using
some direct object access.  Extracting metadata also currently
requires looking into the data hash.  Future versions might fix this,
but see also C<TODO> below.

=over

=item new(%confighash)

Create the Picasa database object and return it.  It is mostly empty
unless $conf->{metadata} points to a file that contains a L<Storable>
from a previous run.  In this case, the object returned already
includes this data.

We'll refer to the resulting $Picasa::conf hashref as $conf below.

=item recursedirs(directories)

Recurse the given directories (using L<File::Find>).  The configured
$conf->{update} sub is called after every directory and file is
processed.  While running the current update is incomplete so it is
done in a copy of the original data.  Upon completion, this newly
updated object is returned.  For this reason, the caller should
reassign the returned reference:

    $picasa = $picasa->recursedirs(@ARGV || '.');

=item next, prev, down, up

These methods navigate the current selection which is a single
directory or file in the virtual filesystem.  The original location is
/ or the root of the tree.  Its children are the various organizations
of the images by Albums, People, Folders and so on.

next and prev move to the next or previous item in the current
directory.  These take an optional integer argument, the number of
steps to move in that direction.  They are a no-op if the beginning or
end of the list is reached.

down navigates into the selected child of the current directory.  This
can be another directory or a single image.  up then navigates to the
parent directory of the current selection.

The return value of all moves is a hash summary of all filtered images
below that point in the tree.  For directories width, height, bytes,
files are all sums and the caller can divide by files to get averages.
Of course for image files, the metrics are for that one image.

=item filtermove

Filter the images, returning a summary hash of all images below.

$conf->{filter} must first be edited with {Filter => 1} pairs for all
needed attributes.  Current filters include: Tags, Captions, Albums,
Faces, Stars, Uploads and age.  If an image has the attribute it is
included in navigation and the summary return, else it is excluded.
For age, the image must be younger than the given age, in sortable
$conf->{datefmt}.

Filtering can eliminate all images below the current selection.  If
this happens, this method navigates up until matching images are
found.  If all are excluded, the result is being in the / root.

=item merge(sourcedir sourceimage destdir [destimage])

Merge metadata about sourceimage in sourcedir into destdir.  This is
used for merging pictures from multiple directories into a common one.
The destination image is assumed to have the same filename unless a
new one is given.  Note that this is only merging metadata in the
hash, it is not touching any files.  See C<save> next:

=item save(directory)

Actually update the .picasa.ini file in the given directory.  This
would be done in the destination directory after the above C<merge>.
The caller would also need to actually link or copy the image in this
case.  See the examples directory for sample code to do this.

If the output is unchanged, the .picasa.ini file will not be written.
If there is any change, the file will be backed up with an _original
extension, but only one time.  The _original file will not be
overwritten on multiple calls.

This is the only function that can modify data on disk, all others are
read-only.  If $conf->{debug} is negative, even this one will not
write a new file.  Instead a difference is shown.

=back

There are several other methods used internally, which could be useful
to code.  See the source code and example directory for more.

=head1 TODO

Some of this is now obsoleted by an L<LPDB> SQLite database.

=head1 SEE ALSO

L<picasagallery>, https://en.wikipedia.org/wiki/Picasa

=head1 AUTHOR

Timothy D Witham <twitham@sbcglobal.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2013-2020 Timothy D Witham.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
