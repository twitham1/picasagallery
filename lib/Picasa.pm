# Picasa.pm

# perl access to local Picasa picture database (faces, albums, stars, etc.)

# by twitham@sbcglobal.net, 2013-06

# {dirs}{<dir>}{<file>} => { field => value} is the raw .picasa.ini data only
# {pics}{<path>} => { metadata } is all data for each picture, in perl format
# {root}{virtual path} => physicalpath is the virtual hierarchy
# {dir} => { current virtual "directory/" after filtering/navigating }
# {file} => { current virtual focused "file/?" after filtering/navigating }
# {index} => current file index ( should this be in {dir} ? )

package Picasa;
use strict;
use warnings;
use File::Find;
use File::Basename;
use Image::ExifTool qw(:Public);
use Data::Dumper;
use POSIX qw/strftime/;

my $db;	    # picasa database pointer needed for File::Find's _wanted.

my $conf = {		       # override any keys in first arg to new
    reject	=> 'PATTERN OF FILES TO REJECT',
    keep	=> '(?i)\.jpe?g$',	# pattern of files to keep
    datefmt	=> '%Y-%m-%d.%H:%M:%S', # must be sortable order
    update	=> sub {},  # callback after each directory is scanned
    debug	=> 0,	    # diagnostics to STDERR
    filter	=> {},	    # filters
};

my $exiftool;	       # for collecting exif data we are interested in

# return new empty picasa database object
sub new {
    my $class = shift;
    my $self  = { done => 0 };	# data complete?
    bless ($self, $class);
    if (ref $_[0]) {		# switch to user's conf + my defaults
	my $hash = shift;
	while (my($k, $v) = each %$conf) {
	    $hash->{$k} = $v unless $hash->{$k};
	}
	$conf = $hash;
    }
    $exiftool = new Image::ExifTool;
    $exiftool->Options(FastScan => 1,
		       DateFormat => $conf->{datefmt});
    $self->{dir} = $self->{file} = $self->filter('/');
    $self->{index} = 0;
    return $self;
}

# find pictures and picasa data in given directories
sub recursedirs {
    my $self = shift;
    for (@_) {
	readdb($self, $_);
    }
    $self->{done} = 1;		# data complete!
    &{$conf->{update}};
}

# recursively add given directory or . to picasa database
sub readdb {
    my $self = shift;
    my $dir = shift || '.';
    $db = $self;
    warn "readdb $dir\n" if $conf->{debug};
    find ({ no_chdir => 1,
	    preprocess => sub { sort @_ },
	    wanted => \&_wanted,
	    postprocess => $conf->{update},
	  }, $dir);
}

# twiddle location in the virtual tree and selected node (file):

# TODO: option to automove to next directory if at end of this one
sub next {
    my($self, $n) = @_;
    $self->{index} += defined $n ? $n : 1;
    my @child = @{$self->{dir}{children}};
    my $child = @child;
    $self->{index} = $child - 1 if $self->{index} >= $child;
    $self->{index} = 0 if $self->{index} < 0;
    $self->{file} = $self->filter("$self->{dir}{dir}$self->{dir}{file}$child[$self->{index}]");
}
# TODO: option to automove to prev directory if at beginning of this one
sub prev {
    my($self, $n) = @_;
    $self->{index} -= defined $n ? $n : 1;
    my @child = @{$self->{dir}{children}};
    $self->{index} = 0 if $self->{index} < 0;
    $self->{file} = $self->filter("$self->{dir}{dir}$self->{dir}{file}$child[$self->{index}]");
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
    $self->{index} = $index;
    $self->next(0);
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
    $self->next(0);
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
sub filter {
    my($self, $path, $opt) = @_;
    my $data = {};
    my %child;			# children of this parent
    my %face;			# faces in this path
    my %album;			# albums in this path
    my %tag;			# tags in this path
    my %done;			# files that have been processed
    my @ss;			# slide show pictures
    $path =~ s@/+@/@g;
    ($data->{dir}, $data->{file}) = dirfile $path;
    warn "filter:$path->($data->{dir},$data->{file})\n" if $conf->{debug};
    my $begin = $conf->{filter}{age} ? strftime $conf->{datefmt},
    localtime time - $conf->{filter}{age} : 0;
    for my $str (sort keys %{$self->{root}}) { # for each picture file
	next unless 0 == index($str, $path); # match
	next unless my $filename = $self->{root}{$str}; # physical path
	next unless my $this = $self->{pics}{$filename}; # metadata

	unless ($opt and $opt eq 'nofilter') {
	    warn "filtering $str for filter ", Dumper $conf->{filter}
	    if $conf->{debug} > 1;
	    next if $conf->{filter}{Stars}	and !$this->{stars};
	    next if $conf->{filter}{Uploads}	and !$this->{uploads};
	    next if $conf->{filter}{Faces}	and !@{$this->{faces}};
	    next if $conf->{filter}{Albums}	and !@{$this->{albums}};
	    next if $conf->{filter}{Captions}	and !$this->{caption};
	    next if $conf->{filter}{Tags}	and !@{$this->{tags}};
	    next if $conf->{filter}{age} and $this->{time} lt $begin;
	}

	if ($opt and $opt eq 'slideshow') {
	    push @ss, $str;
	    next;
	}

	warn "looking at ($path) in ($str)\n" if $conf->{debug} > 1;
	if ($str eq $path) {	# filename: copy metadata
	    map { $data->{$_} = $this->{$_} } keys %$this;
	} else { 		# directory: sum metadata
	    my $rest = substr $str, length $path;
	    $rest =~ s!/.*!/!;
	    $rest and $child{$rest}++; # entries in this directory
	    next if $done{$filename}++;
	    warn "$path: $str ($rest)\n" if $conf->{debug} > 1;
	    for my $num (qw/bytes stars uploads width height/) {
		$data->{$num} += $this->{$num};
	    }
	    map { $face{$_->[0]}++ } @{$this->{faces}};
	    map { $album{$_}++ } @{$this->{albums}};
	    map { $tag{$_}++ } @{$this->{tags}};
	    $data->{caption} += $this->{caption} ? 1 : 0;
	}
	$data->{pixels} += $this->{width} * $this->{height};
	$data->{files}++;

	$data->{time} = $this->{time} and
	    $data->{first} = $filename unless
	    $data->{time} && $data->{time} lt $this->{time};

	$data->{endtime} = $this->{time} and
	    $data->{last} = $filename unless
	    $data->{endtime} && $data->{endtime} gt $this->{time};

	$data->{physical} and
	    $data->{physical} ne $data->{first} and
	    $data->{physical} ne $data->{last} or
	    $data->{physical} = $filename;
    }
    if ($opt and $opt eq 'slideshow') {
	return @ss;
    }
    $data->{children} = [sort keys %child]; # maybe sort later? sort by option?
    $data->{faces} or $data->{faces} = [keys %face];
    $data->{albums} or $data->{albums} = [keys %album];
    $data->{tags} or $data->{tags} = [keys %tag];
    warn "filtered $path: ", Dumper $data if $conf->{debug} > 2;
    return $data;
}

# add picture to virtual path
sub _addpic2path {
    my($self, $path, $key) = @_;
    $self->{root}{$path} = $key;
}

# return all directories of the database
sub dirs {
    my $self = shift;
    return keys %{$self->{dirs}};
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

# return array of [id, NW, SE] of faces in given $dir $pic
sub faces {
    my($self, $dir, $pic) = @_;
    my @ret;
    return @ret unless $dir and $pic;
    my $this = $self->{dirs}{$dir}{$pic};
    return @ret unless $this and $this->{faces};
    for my $string (split ';', $this->{faces}) {
	my($rect, $id) = split ',', $string;
	push @ret, [$id, $self->rect($rect)];
    }
    return @ret;
}

# return array of album ids in $pic
sub albums {
    my($self, $dir, $pic) = @_;
    return () unless $dir and $pic;
    my $this = $self->{dirs}{$dir}{$pic};
    return () unless $this and $this->{albums};
    return split ',', $this->{albums};
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
    mkdir $dir or die "can't mkdir $dir: $!\n" unless -d $dir;
    my $was = '';
    if (open my $fh, $out) {
	$was .= $_ while (<$fh>);
    }
    my $now = '';
    for my $file (sort keys %{$self->{dirs}{$dir}}) {
	next if $file =~ m@/$@;	# skip subdirs
	next if $file =~ m@^<<\w+>>$@; # skip internal metadata
	if (my @key = sort keys %{$self->{dirs}{$dir}{$file}}) {
	    $now .= ($file =~ /\[.+\]/ ? $file : "[$file]") . "\r\n";
	    for my $f (@key) {
		$now .= "$f=$self->{dirs}{$dir}{$file}{$f}\r\n";
	    }
	}
    }
    if ($was eq $now) {
#	print "# $out unchanged\n";
    } else {
	print "# $out being replaced\n";
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
    my($file, $dir) = fileparse $_;
#    $dir = '' if $dir eq '.';
    if ($file eq '.picasa.ini' or $file eq 'Picasa.ini') {
	&_understand($db, _readfile($_));
	return;
    } elsif ($file =~ /^\..+/ or $file eq 'Originals') { # ignore hidden files
	$File::Find::prune = 1;
	return;
    }
    $File::Find::prune = 1, return if $file =~ /$conf->{reject}/;
    if (-f $_) {
	return unless $file =~ /$conf->{keep}/;
	$db->{dirs}{$dir}{$file} = {}
	unless $db->{dirs}{$dir}{$file};
	my $key = $_;
	$key =~ s@\./@@;
	return unless -f $key and -s $key > 100;
	my $info = $exiftool->ImageInfo($key);
	return unless $info;
	return unless $info->{ImageWidth} && $info->{ImageHeight};
	my $this = $db->{pics}{$key} = {
	    bytes	=> -s $key,
	    width	=> $info->{ImageWidth},
	    height	=> $info->{ImageHeight},
	    time	=> $info->{DateTimeOriginal} || $info->{CreateDate}
	    || $info->{ModifyDate} || $info->{FileModifyDate} || 0,
	    caption	=> $info->{'Caption-Abstract'}
	    || $info->{'Description'} || '',
	    faces	=> [ $db->faces($dir, $file) ],
	    albums	=> [ $db->albums($dir, $file) ],
	    stars	=> $db->star($dir, $file),
	    uploads	=> $db->uploads($dir, $file),
	    tags	=> [ split /,\s*/,
			     $info->{Keywords} || $info->{Subject} || '' ],
	};
	$this->{time} =~ /0000/ and
	    warn "bogus time in $_: $this->{time}\n";
	my $year = 0;
	$year = $1 if $this->{time} =~ /(\d{4})/; # year must be first

	my $vname = "$this->{time}-$file"; # unique virtual filename

	# add virtual folders of stars, tags, albums, people
	$this->{stars} and
	    $db->_addpic2path("/[Stars]/$year/$vname", $key);
	for my $tag (@{$this->{tags}}) { # should year be here???
	    $db->_addpic2path("/[Tags]/$tag/$vname", $key);
	    $db->{tags}{$tag}++; # all tags with picture counts
	}
	for my $id (@{$this->{albums}}) { # named user albums
	    next unless my $name = $db->{album}{$id}{name};
	    # putting year in this path would cause albums that span
	    # year boundary to be in 2 places...
	    $db->_addpic2path("/[Albums]/$name/$vname", $key);
	}

	# add faces / people
	for my $face ($db->faces($dir, $file)) {
	    my($id) = @$face;
	    next unless my $name = $db->contact2person($id);
	    $db->_addpic2path("/[People]/$name/$year/$vname", $key);
	}

	# add folders (putting year here would split folders into
	# multiple locations (y/f or f/y); maybe this would be ok?)
	$db->_addpic2path("/[Folders]/$key", $key);

    } elsif (-d $_) {
	$db->{dirs}{$dir}{"$file/"} = {}
	unless $db->{dirs}{$dir}{"$file/"};
    }
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
	    $pic->{dirs}{$ini->{dir}}{"[$k]"} =
		($pic->{album}{$1}
		 ? &_identical($pic->{album}{$1}, $ini->{$k})
		 : ($pic->{album}{$1} = $ini->{$k}));
	    next;
	} elsif ($k eq 'dir') {
	    next;
	}
	$pic->{dirs}{$ini->{dir}}{
	    -f "$ini->{dir}/$k" ? $k : "[$k]"} = $ini->{$k};
    }
}

# compare two hashes and warn any different content
sub _identical {
    my($a, $b) = @_;
    for my $k (keys %$a, keys %$b) {
	$a->{$k} eq $b->{$k} or
	    $conf->{debug} and
	    warn "$k: (keep:) $a->{$k} (lose:) $b->{$k} ($File::Find::name)\n";
    }
    return $a;
}

1;				# return true
