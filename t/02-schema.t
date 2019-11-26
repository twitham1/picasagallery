#!/usr/bin/perl

# use the schema

use strict;
use warnings;
use Test::More;
use LPDB;
use LPDB::Schema;
use Data::Dumper;

my $lpdb = new LPDB({dbfile => 'tmp.db',
		     # sqltrace => 1,
		     # debug => 1,
		    });
my $schema = $lpdb->schema;

isa_ok($schema, 'LPDB::Schema', 'expected schema');

$lpdb->update('test');
$lpdb->goto('/');
is($lpdb->files, 10, 'total file count');
my $children = $lpdb->children('dir');
is("@$children", "[Folders]/ [Tags]/", 'Virtual FS root');
is($lpdb->bytes, 18847967, 'bytes of [Folders]/');
$lpdb->next;			# move to Tags
$lpdb->down;			# step in, now Gracelyn
is($lpdb->width, 10047, 'Tags/Gracelyn width');
$lpdb->goto('/[Tags]/Simon/');
print Dumper $lpdb->{file};
is($lpdb->height, 7931, 'Tags/Simon height');
$lpdb->disconnect;
done_testing();
exit;
