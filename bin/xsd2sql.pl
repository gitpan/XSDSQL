#!/usr/bin/perl
eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
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

use constant {
 	DEFAULT_VIEW_PREFIX			=> 'V'
	,DEFAULT_ROOT_TABLE_NAME 	=> 'ROOT'
 	,DEFAULT_SEQUENCE_PREFIX	=> 'S'
};

my %Opt=();
unless (getopts ('hn:r:p:l:t:w:s:',\%Opt)) {
	print STDERR "invalid option or option not set\n";
	exit 1;
}

if ($Opt{h}) {
	print STDOUT "
		$0  [<options>]  <command>  [<xsdfile>...] 
		<options>: 
			-h  - this help
			-n <output_namespace>::<db_namespace> - default sql::pg  (Sql for PostgreSQL)
			-r <root_table_name> - set the root table name  (default '".DEFAULT_ROOT_TABLE_NAME."')
			-p <table_prefix_name> - set the prefix for the tables name (default none)
			-w <view_prefix_name>  - set the prefix for views name (default '".DEFAULT_VIEW_PREFIX."')
					WARNING - This option can influence table names
			-s <sequence_prefix_name>  - set the prefix for sequences name (default '".DEFAULT_SEQUENCE_PREFIX."')
					WARNING - This option can influence table names
			-l <start_table_level> - set the start level for generate create/drop view (the root has level 0) (default 0)
			-t <table_name>|<path_name>[,<table_name>|<path_name>...] - generate view starting only from <table_name> or <pathname> (default all tables)
		<command>
			display_namespaces - display on stdout the namespaces founded (Es: sql::pg)
			drop_table  - generate a drop tables on stdout
			create_table - generate a create tables on stdout
			addpk - generate primary keys on stdout
			drop_sequence - generate a drop sequence on stdout
			create_sequence - generate a create sequence on stdout
	"; 
    exit 0;
}

if (scalar(@ARGV) < 1) {
	print STDERR "missing arguments\n";
	exit 1;
}

my @namespaces=blx::xsdsql::generator::get_namespaces;
my @db_namespaces=blx::xsdsql::parser::get_db_namespaces;

if ($ARGV[0] eq 'display_namespaces') {	
	for my $n(sort @namespaces) {
		print STDOUT $n,"\n";
	}
	exit 0;
}

$Opt{n}='sql::pg' unless defined $Opt{n};

my ($output_namespace,$db_namespace)=$Opt{n}=~/^(\S+)::([^:]+)$/;
unless (defined $db_namespace) {
	print STDERR $Opt{n},": option n is invalid - valid is (<output_namespace>::<db_namespace>)\n";
    exit 1;
}

unless (grep($Opt{n} eq $_,@namespaces)) {
	print STDERR $Opt{n},": option n is invalid - valid values are: (",join(',',@namespaces),")\n";
	exit 1;
}

unless (grep($db_namespace eq $_,@db_namespaces)) {
	print STDERR $Opt{n},": Can't locate db_namespace in \@INC\n";
	exit 1;
}

unless (nvl($Opt{l},0)=~/^\d{1,11}$/) {
	print STDERR $Opt{l},": option l is invalid - valid is a abs number\n";
	exit 1;
}

$Opt{t}=[split(",",$Opt{t})] if defined $Opt{t};
$Opt{w}=DEFAULT_VIEW_PREFIX unless defined $Opt{w};
$Opt{r}=DEFAULT_ROOT_TABLE_NAME unless defined $Opt{r};
$Opt{s}=DEFAULT_SEQUENCE_PREFIX unless defined $Opt{s};

my $cmd=shift @ARGV;
unless (grep($_ eq $cmd,qw( drop_table create_table addpk drop_sequence create_sequence))) {
	print STDERR "$cmd: invalid command\n";
	exit 1;
}

my $p=blx::xsdsql::parser->new(DB_NAMESPACE => $db_namespace); 

unless (grep($_ eq $Opt{n},blx::xsdsql::generator::get_namespaces)) {
	print STDERR $Opt{n},": Can't locate namespace in \@INC\n";
	exit 1;
}


my $g=blx::xsdsql::generator->new(OUTPUT_NAMESPACE => $output_namespace,DB_NAMESPACE => $db_namespace,FD => *STDOUT);

push @ARGV,'-'  if scalar(@ARGV) == 0;
for my $f(@ARGV) {
	my $root_table=$p->parsefile(
		$f
		,ROOT_TABLE_NAME 	=> $Opt{r}
		,TABLE_PREFIX 		=> $Opt{p}
		,VIEW_PREFIX 		=> $Opt{w}
		,SEQUENCE_PREFIX	=> $Opt{s}
	) || exit 1;
	$g->generate(
		ROOT_TABLE 			=> $root_table
		,COMMAND 			=> $cmd
		,LEVEL_FILTER		=> $Opt{l}
		,TABLES_FILTER		=> $Opt{t}
	);
}

exit 0;
