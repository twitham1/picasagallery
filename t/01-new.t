#!/usr/bin/perl -w

# create or read test.db

use strict;
use warnings;
use Test::More;
use LPDB;
use Data::Dumper;

my $lpdb = new LPDB;
ok(! defined $lpdb, "no-arg new() returned undef");

my $lpdb = new LPDB({dbfile => 'tmp.db'});
ok(defined $lpdb, "new({dbfile}) returned something");
ok($lpdb->isa('LPDB'), "   and it's an LPDB");

done_testing();
