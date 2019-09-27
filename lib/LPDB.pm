# LPDB.pm

# ABSTRACT: LPDB = Local Picture metadata in sqlite

package LPDB;
use strict;
use warnings;
use Carp;
use DBI;
# use DBIx::Class;

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
    $conf->{dbfile} or carp "{dbfile} required" and return undef;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$conf->{dbfile}",  "", "",
			   { RaiseError => 1, AutoCommit => 1 })
	or die $DBI::errstr;
    $self->{dbh} = $dbh;
    return bless $self, $class;
}

sub dbh {
    return $_[0]->{dbh};
}

# create the database
sub create {
    my $self = shift;
    my $dbh = $self->dbh;
    $dbh->do(
	"
	CREATE TABLE IF NOT EXISTS files(
	fileid INTEGER PRIMARY KEY NOT NULL, -- alias to fast: rowid, oid, _rowid_
	filename TEXT UNIQUE NOT NULL
	);
	CREATE UNIQUE INDEX filenames ON files(filename);
	");
    $dbh->do(
	"
	CREATE TABLE IF NOT EXISTS pictures(
	width	INTEGER,
	height	INTEGER,
	bytes	INTEGER,
	rotation INTEGER,	-- 0, 90, 180, 270 CW
	updated	INTEGER,	-- file timestamp
	time	INTEGER,	-- time picture taken (0 or updated if unknown?)
	fileid	INTEGER PRIMARY KEY NOT NULL,
	FOREIGN KEY(fileid) REFERENCES files(fileid)
	);
	");
    $dbh->commit;
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

1;				# LPDB.pm
