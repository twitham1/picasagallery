#!/usr/bin/perl

# use the schema

use strict;
use warnings;
use Test::More;
use LPDB;
use LPDB::Schema;
use Data::Dumper;

my $lpdb = new LPDB({dbfile => 'tmp.db',
		     sqltrace => 1,
		     # debug => 1,
		    });
my $schema = $lpdb->schema;

isa_ok($schema, 'LPDB::Schema', 'expected schema');

$lpdb->update('test');
$lpdb->goto('/');		# in /, sitting at [Folders]/
print Dumper $lpdb->{file};
is($lpdb->files, 10, 'total file count');
is($lpdb->stat('time', 1), 1527644615, 'average time of all files');
is($lpdb->sums, '18 MB (62 MP) in 10 files', 'overall sums');
is($lpdb->averages, "1841 KB (6195 KP) 3135 x 2026 (1.547)",
   'Folders averages');
my $children = $lpdb->children('dir');
is("@$children", "[Folders]/ [Tags]/", 'Virtual FS root');
is($lpdb->bytes, 18847967, 'bytes of [Folders]/');
$lpdb->next;			# move to Tags
$lpdb->down;			# step in, now in [Tags]/ Gracelyn
is($lpdb->width, 10047, 'Tags/Gracelyn width');
$lpdb->goto('/[Tags]/Simon/');
is($lpdb->height, 7931, 'Tags/Simon sum height');
is($lpdb->height(1), 1983, 'Tags/Simon avg height');
is($lpdb->bytes(1), 2240151, 'Tags/Simon avg bytes');
is($lpdb->averages, "2188 KB (7509 KP) 3348 x 1983 (1.689)",
   'Tags/Simon averages');
$lpdb->disconnect;
done_testing();
exit;
