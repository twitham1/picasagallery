#!/usr/bin/perl -w

use strict;
use warnings;
use Test::More tests => 2;
use LPDB;

my $lpdb = new LPDB;

ok(defined $lpdb, "new() returned something");
ok($lpdb->isa('LPDB'), " and it's the right class");

exit 0;
