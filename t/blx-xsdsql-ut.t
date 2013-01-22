#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 10;
BEGIN { use_ok('Cwd') };
BEGIN { use_ok('blx::xsdsql::ut') };
BEGIN { use_ok 'XML::Parser','1.21'; };
BEGIN { use_ok 'XML::Writer','0.600'; };
BEGIN { use_ok 'DBI','1.58'; };
BEGIN { use_ok 'Test::Database','1.11.1'; };
BEGIN {  $ENV{REGRESSION_TEST}=$0; use_ok('blx::xsdsql::IStream') };
BEGIN {  $ENV{REGRESSION_TEST}=$0; use_ok('blx::xsdsql::OStream') };
BEGIN { system('which xmldiff > /dev/null 2>&1'); ok($? == 0);  };
BEGIN {
	use Cwd;
	my $cwd=getcwd;
	my $conf=$cwd."/t/test_database_example.conf";
	$conf=''; #use the default
	system("cd t && REGRESSION_TEST=0 TEST_DATABASE_CONFIG='$conf' ./test.pl"); ok($? == 0) 
};
