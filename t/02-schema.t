#!/usr/bin/perl

# use the schema

use strict;
use warnings;
use Test::More;
use LPDB;
use LPDB::Schema;
use Data::Dumper;

my $lpdb = new LPDB({dbfile => 'tmp.db'});
my $schema = $lpdb->schema;

isa_ok($schema, 'LPDB::Schema', 'expected schema');

# my $rs = $schema->resultset('Picture');
# my $row = $rs->find_or_create(
#     {
# 	filename => 'hello_world9',
#     }
#     );
# isa_ok($row, 'LPDB::Schema::Result::Picture', 'expected picture row');

$lpdb->update('./test');

my @w = $lpdb->width('test/simon.jpg');
print "simon width: @w\n";
@w = $lpdb->width('test/');
print "test width: @w\n";

my @tags = $lpdb->tags('test/4faces.jpg');
print "tags: @tags\n";

@tags = $lpdb->tags('test/gps.jpg');
print "tags: @tags\n";

$lpdb->disconnect;

done_testing();
__END__
# $row->update(
#     {    
# 	width => 800,
# 	height => 600,
# 	time => 123456,
#     }
#     );
