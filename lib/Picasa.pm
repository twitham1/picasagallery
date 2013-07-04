# perl access to local Picasa picture database (faces, albums, etc.)

# by twitham@sbcglobal.net, 2013-06

# currently read-only but writing should be posssible enhancement

package Picasa;
use File::Find;
use File::Basename;
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
    return {} unless $dir and $pic;
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

# add a file or directory to the database
sub _wanted {
    my($file, $dir) = fileparse $_;
    if ($file eq '.picasa.ini') {
	&_understand($db, _readfile($_));
    } elsif ($file =~ /^\..+/) { # ignore hidden files/directories
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
	$a->{$k} eq $b->{$k} or warn "$k: $a->{$k} ne $b->{$k}\n";
    }
    return $a;
}

1;
