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

my $rs = $schema->resultset('File');
my $row = $rs->find_or_create({
    filename => 'hello_world',
 			      });
isa_ok($row, 'LPDB::Schema::Result::File', 'expected file row');

$lpdb->disconnect;

done_testing();
