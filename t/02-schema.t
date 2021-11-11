#!/usr/bin/perl

# use the schema

use strict;
use warnings;
use Test::More;
use LPDB;
use LPDB::Schema;
use Data::Dumper;

my $lpdb = new LPDB({dbfile => 'tmp.db',
		     thumbfile => 'tmp-thumbs.db',
		     # sqltrace => 1,
		     # debug => 1,
		    });
my $schema = $lpdb->schema;

# correct summary of the test data
my $top = {
    'begintime' => 1437243235,
	'bytes' => 18847967,
	'caption' => 3,
	'children' => [
	    'test/'
	],
	'dir' => '/',
	'dirs' => 1,
	'endtime' => 1572035220,
	'file' => '[Folders]/',
	'files' => 10,
	'first' => 'test/tall.jpg',
	'firstid' => 10,
	'height' => 20262,
	'last' => 'test/screencapture.jpg',
	'lastid' => 8,
	'middleid' => 3,
	'modified' => '15595852476',
	'physical' => 'test/edited_unsaved.jpg',
	'pixels' => 61952862,
	'tags' => 6,
	'time' => '15276446154',
	'width' => 31353
};


isa_ok($schema, 'LPDB::Schema', 'expected schema');

$lpdb->update('test');
$lpdb->goto('/');		# in /, sitting at [Folders]/
# is_deeply($lpdb->{file}, $top,
# 	  'total stat data structure')
#     or diag explain $lpdb->{file};
is($lpdb->files, 11, 'total file count');
is($lpdb->dirs, 2, 'total directory count');
# is($lpdb->stat('time', 1), 1527644615, 'average time of all files');
# is($lpdb->sums, '18 MB (62 MP) in 10 files in 1 dirs', 'overall sums');
# is($lpdb->averages, "1841 KB (6195 KP) 3135 x 2026 (1.547)",
#    'Folders averages');
my $children = $lpdb->children('dir');
is("@$children", "[Folders]/ [Tags]/ [Timeline]/", 'Virtual FS root');
is($lpdb->bytes, 21853510 , 'bytes of [Folders]/');
$lpdb->next;			# move to Tags
$lpdb->down;			# step in, now in [Tags]/ Gracelyn
is($lpdb->width, 10047, 'Tags/Gracelyn width');
$lpdb->goto('/[Tags]/Simon/');
# is($lpdb->height, 7931, 'Tags/Simon sum height');
# is($lpdb->height(1), 1983, 'Tags/Simon avg height');
# is($lpdb->bytes(1), 2240151, 'Tags/Simon avg bytes');
# is($lpdb->averages, "2188 KB (7509 KP) 3348 x 1983 (1.689)",
#    'Tags/Simon averages');
$lpdb->disconnect;
done_testing();
exit;
