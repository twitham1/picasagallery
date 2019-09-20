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
my $dbh;

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
    $dbh = DBI->connect("dbi:SQLite:dbname=$conf->{dbfile}",  "", "",
			{ RaiseError => 1 },) or die $DBI::errstr;
    return bless $self, $class;
}

1;				# LPDB.pm
