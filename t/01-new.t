#!/usr/bin/perl

# create or read test.db

use strict;
use warnings;
use Test::More;
use LPDB;
use Data::Dumper;

my $lpdb = new LPDB;
ok(! defined $lpdb, "no-arg new() returned undef");

$lpdb = new LPDB({dbfile => 'tmp.db'});
isa_ok($lpdb, 'LPDB', "new({dbfile}");

ok($lpdb->create, "created the tables");

my @tables = $lpdb->dbh->tables;
ok(4 < (grep /(pictures)/i, @tables), # includes indexes
   "expected tables exist") or
    diag("tables found: @tables");

$lpdb->disconnect;

done_testing();
