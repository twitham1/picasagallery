# perl access to local Picasa picture database (faces, albums, etc.)

# by twitham@sbcglobal.net, 2013-06

package Picasa;
use File::Find;
use File::Basename;
use Data::Dumper;

my $db;	    # picasa database pointer needed for File::Find's _wanted.

# return new picasa database object of given directories (or empty)
sub new {
    my $class = shift;
    my $self  = {};
    for (@_) {
	readdb($self, $_);
    }
    bless ($self, $class);
    return $self;
}

# recursively add given directory or . to picasa database
sub readdb {
    my $self = shift;
    my $dir = shift || '.';
    $db = $self;
    find ({ wanted => \&_wanted, no_chdir => 1 }, $dir);
}

# return all directories of the database
sub dirs {
    my $self = shift;
    return keys %{$self->{dirs}};
}

# return the pictures of given directory
sub pics {
    my $self = shift;
    my $dir = shift or return ();
    return keys %{$self->{dirs}{$dir}};
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

# return array of [id, name, NW, SE] of faces in given $dir $pic
sub faces {
    my($self, $dir, $pic) = @_;
    my @ret;
    return @ret unless $dir and $pic;
    my $this = $self->{dirs}{$dir}{$pic};
    return @ret unless $this and $this->{faces};
    for my $string (split ';', $this->{faces}) {
	my($rect, $id) = split ',', $string;
	my $name = $self->contact2person($id);
	push @ret, [$id, $name, $self->rect($rect)];
    }
    return @ret;
}

# return array of [id, name, date, location, description] of albums in $pic
sub albums {
    my($self, $dir, $pic) = @_;
    my @ret;
    return @ret unless $dir and $pic;
    my $this = $self->{dirs}{$dir}{$pic};
    return @ret unless $this and $this->{albums};
    for my $id (split ',', $this->{albums}) {
	my $this = $self->{album}{$id};
	push @ret, [$id,
		    $this->{name} || '',
		    $this->{date} || '',
		    $this->{location} || '',
		    $this->{description} || '',
	];
    }
    return @ret;
}

# write the .picasa.ini in given $dir, backing up the original once
sub save {
    my($self, $dir) = @_;
    my $out = "$dir/.picasa.ini";
    mkdir $dir or die "can't mkdir $dir: $!\n" unless -d $dir;
    if (-f $out) {		# backup the original, but only once
	my $tmp = $out . '_original';
	rename $out, $tmp or warn "$0: can't rename $out $tmp: $!\n";
    }
    open my $fh, '>', $out or warn "can't write $out: $!\n" and return 0;
    for my $file (sort keys %{$self->{dirs}{$dir}}) {
	if (my @key = sort keys %{$self->{dirs}{$dir}{$file}}) {
	    print $fh ($file =~ /\[.+\]/ ? $file : "[$file]"), "\r\n";
	    for my $f (@key) {
		print $fh "$f=$self->{dirs}{$dir}{$file}{$f}\r\n";
	    }
	}
    }
    close $fh or warn "can't close $out: $!\n" and return 0;
    unlink $out unless -s $out;
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
		warn "WARN $_: (keep:) $a->{$_} (lose:) $b->{$_}\n";
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
    if ($file eq '.picasa.ini' or $file eq 'Picasa.ini') {
	&_understand($db, _readfile($_));
    } elsif ($file =~ /^\..+/ or $file eq 'Originals') { # ignore hidden files/directories
	$File::Find::prune = 1;
    } elsif (-f $_) {
	$db->{dirs}{$dir}{$file} = {}
	unless $db->{dirs}{$dir}{$file};
    }
}

# return given .picasa.ini file as a hash
sub _readfile {
    my($file) = @_;
    my $data = {};
    my $fh;
#    warn ">$file<\n";
    return $data unless open $fh, $file;
    my $section = '';
    my($name, $dir) = fileparse $file;
    $data->{dir} = $dir;
    while (<$fh>) {
	chomp;
	s/\r*\n*$//;
	s/\&\#(\d{3});/sprintf "%c", oct($1)/eg;
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
	$a->{$k} eq $b->{$k} or warn "$k: (keep:) $a->{$k} (lose:) $b->{$k} ($File::Find::name)\n";
    }
    return $a;
}

1;				# return true
