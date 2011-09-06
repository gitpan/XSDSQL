#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 4;
BEGIN { use_ok('blx::xsdsql::ut') };
BEGIN {  $ENV{REGRESSION_TEST}=$0; use_ok('blx::xsdsql::IStream') };
BEGIN {  $ENV{REGRESSION_TEST}=$0; use_ok('blx::xsdsql::OStream') };
BEGIN {  system('cd t && REGRESSION_TEST=0 ./test.pl'); ok($? == 0)  };
