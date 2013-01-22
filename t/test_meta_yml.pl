#!/usr/bin/env perl

#
# test META.yml file 
# META.yml is generated from Makefile.PM with name MYMETA.yml
#


use strict;
use warnings qw(FATAL);
use integer;
use English '-no_match_vars';
use Test::More tests => 2;
use Test::CPAN::Meta::YAML;

my $file=defined $ARGV[0] ? $ARGV[0] : '../META.yml';

unless (-r $file) {
	print STDERR "file $file is not readable\n";
	exit 1;
}

#meta_spec_ok('META.yml','1.3',$msg);
#meta_spec_ok(undef,'1.3',$msg);

meta_spec_ok($file,undef);
exit 0;
