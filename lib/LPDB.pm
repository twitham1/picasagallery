# LPDB.pm

# ABSTRACT: LPDB = Local Picture Database, like for picasagallery

package LPDB;
use strict;
use warnings;
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
    $conf->{dbfile} or warn "{dbfile} required\n" and return undef;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$conf->{dbfile}",  "", "",
			   { RaiseError => 1 },) or die $DBI::errstr;
    $self->{dbh} = $dbh;
    return bless $self, $class;
}

# create the database
sub create {
    my $self = shift;
    my $dbh = $self->{dbh};
    $dbh->do(
	"
	CREATE TABLE IF NOT EXISTS files(
	fileid INTEGER NOT NULL PRIMARY KEY, -- alias to fast: rowid, oid, _rowid_
	filename TEXT UNIQUE NOT NULL
	-- FOREIGN KEY(pictureid) REFERENCES pictures(id),
	);
	CREATE UNIQUE INDEX filenames ON files(filename);
	");
    $dbh->commit;
}

1;				# LPDB.pm
