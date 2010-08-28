#!/usr/bin/perl
use strict;
use warnings;
use integer;
use English '-no_match_vars';

use Getopt::Std;
use File::Basename;
use Data::Dumper;
use Carp;

use blx::xsdsql::ut qw(nvl);
use blx::xsdsql::parser;
use blx::xsdsql::generator;
#use blx::xsdsql::streamer;

my %CMD=();
%CMD=(
			drop        => sub {}
			,create     => sub {}
			,addpk      => sub {}
);

my %Opt=();
getopts ('hn:r:',\%Opt) or exit 1;
if ($Opt{h}) {
	print STDOUT "
		$0  [<options>]  <command>  [<xsdfile>...] 
		<options>: 
			-h  - this help
			-d  - emit debug info 
			-n <output_namespace>::<db_namespace> - default sql::pg  (Sql for PostgreSQL)
			-r <root_table_name> - set the root table name  (default ROOT)
		<command>
			drop_table  - generate a drop tables on stdout
			create_table - generate a create tables on stdout
			addpk - generate primary keys on stdout
	"; 
    exit 0;
}

if (scalar(@ARGV) < 1) {
	print STDERR "missing arguments\n";
	exit 1;
}

$Opt{n}='sql::pg' unless defined $Opt{n};

my ($output_namespace,$db_namespace)=$Opt{n}=~/^(\S+)::([^:]+)$/;
unless (defined $db_namespace) {
	print STDERR $Opt{n},": option n is invalid - valid is (<output_namespace>::<db_namespace>)\n";
	exit 1;
}

unless (grep($db_namespace eq $_,blx::xsdsql::parser::get_db_namespaces)) {
	print STDERR $Opt{n},": Can't locate db_namespace in \@INC\n";
	exit 1;
}

my $cmd=shift @ARGV;
my $p=blx::xsdsql::parser->new(DB_NAMESPACE => $db_namespace); 

unless (grep($_ eq $Opt{n},blx::xsdsql::generator::get_namespaces)) {
	print STDERR $Opt{n},": Can't locate namespace in \@INC\n";
	exit 1;
}
my $g=blx::xsdsql::generator->new(OUTPUT_NAMESPACE => $output_namespace,DB_NAMESPACE => $db_namespace,FD => *STDOUT);

push @ARGV,'-'  if scalar(@ARGV) == 0;
for my $f(@ARGV) {
	my $root_table=$p->parsefile($f,ROOT_TABLE_NAME =>  nvl($Opt{r},'ROOT')) || exit 1;
	$g->generate(ROOT_TABLE => $root_table,COMMAND => $cmd);
}

exit 0;
