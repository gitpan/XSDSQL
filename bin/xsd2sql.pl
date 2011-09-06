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
 	DEFAULT_VIEW_PREFIX				=> 'V'
	,DEFAULT_ROOT_TABLE_NAME 		=> 'ROOT'
 	,DEFAULT_SEQUENCE_PREFIX		=> 'S'
 	,DEFAULT_TABLE_DICTIONARY		=> 'table_dictionary'
 	,DEFAULT_COLUMN_DICTIONARY		=> 'column_dictionary'
	,DEFAULT_RELATION_DICTIONARY 	=> 'relation_dictionary'
	,O_KEYS							=>  [ qw(MAX_VIEW_COLUMNS MAX_VIEW_JOINS) ]
	
};

my %Opt=();
unless (getopts ('hn:r:p:l:t:w:s:b:do:',\%Opt)) {
	print STDERR "invalid option or option not set\n";
	exit 1;
}

if ($Opt{h}) {
	print STDOUT "
$0  [<options>]  [<xsdfile>] [<command>...]
	<options>: 
		-h  - this help
		-d  - emit debug info 
		-n <output_namespace>::<db_namespace> - default sql::pg  (sql for PostgreSQL)
		-r <root_table_name> - set the root table name  (default '".DEFAULT_ROOT_TABLE_NAME."')
		-p <table_prefix_name> - set the prefix for the tables name (default none)
		-w <view_prefix_name>  - set the prefix for views name (default '".DEFAULT_VIEW_PREFIX."')
				WARNING - This option can influence table names
		-s <sequence_prefix_name>  - set the prefix for sequences name (default '".DEFAULT_SEQUENCE_PREFIX."')
				WARNING - This option can influence table names
		-l <start_table_level> - set the start level for generate create/drop view (the root has level 0) (default 0)
		-t <table_name>|<path_name>[,<table_name>|<path_name>...] - generate view starting only from <table_name> (default all tables)
			if the first <table_name>|<path_name> begin with comma then <table_name>|<path_name> (without comma) is a file name containing a list of <table_name>|<path_name>
		-b [<table_dictionary_name>][:<column_dictionary_name>[:<relation_dictionary_name>]] - set the name of the table_dictionary, the column_dictionary  and or the relation dictionary
				the default names are '".DEFAULT_TABLE_DICTIONARY."' , '".DEFAULT_COLUMN_DICTIONARY."' and '".DEFAULT_RELATION_DICTIONARY."' 
		-o <name>=<value>[,<name>=<value>...]
			set extra params - valid names are:
				MAX_VIEW_COLUMNS 	=>  produce view code only for views with columns number <= MAX_VIEW_COLUMNS
					-1 is a system limit (database depend)
					false is no limit (the default)
				MAX_VIEW_JOINS 		=>  produce view code only for views with join number <= MAX_VIEW_JOINS 
					-1 is a system limit (database depend)
					false is no limit (the default)						
	<commands>
		display_cl_namespaces - display on stdout the namespaces (type+db) founded (Es: sql::pg)
		drop_table  - generate a drop tables on stdout
		create_table - generate a create tables on stdout
		addpk - generate primary keys on stdout
		drop_sequence - generate a drop sequence on stdout
		create_sequence - generate a create sequence on stdout
		drop_view       - generate a drop view on stdout
		create_view     - generate a create view on stdout
		drop_dictionary - generate a drop dictionary on stdout
		create_dictionary - generate a create dictionary on stdout
		insert_dictionary - generate an insert dictionary on stdout
		display_path_relation - display on stdout the relation from path and table/column
\n"; 
    exit 0;
}


my @cl_namespaces=blx::xsdsql::generator::get_namespaces;
my @db_namespaces=blx::xsdsql::parser::get_db_namespaces;

if ($ARGV[0] eq 'display_namespaces') {	
	for my $n(sort @cl_namespaces) {
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

unless (grep($Opt{n} eq $_,@cl_namespaces)) {
	print STDERR $Opt{n},": option n is invalid - valid values are: (",join(',',@cl_namespaces),")\n";
	exit 1;
}

unless (grep($db_namespace eq $_,@db_namespaces)) {
	print STDERR $Opt{n},": option n is invalid - can't locate db_namespace in \@INC\n";
	exit 1;
}

unless (nvl($Opt{l},0)=~/^\d{1,11}$/) {
	print STDERR $Opt{l},": option l is invalid - valid is a abs number\n";
	exit 1;
}


if (defined (my $t=$Opt{t})) {
	if ($t=~/^,(.*)$/) {  # is a file name
		if (open(my $fd,'<',$1)) {
			my @lines=grep(!/^\s*$/,
				map {  
					s/^\s*//; 
					s/\s*$//; 
					my $l=/^\s*#/ ? '' : $_;
					$l;  
				} <$fd>);
			$Opt{t}=\@lines;
			close $fd;
		}
		else {
			print STDERR "$1: $!\n";
			exit 1;
		}
	}
	else {
	   $Opt{t}=[split(",",$t)];
	}
}

if (defined $Opt{o}) {
	my %h=();
	for my $e(split(",",$Opt{o})) {
		my ($name,$value)=$e=~/^([^=]+)=(.*)$/;
		unless (defined $name) {
			print STDERR $Opt{o},": option o is invalid - valid is <name>=<value>[,<name>=<value>...]\n";
			exit 1;
		}
		$h{$name}=$value;
	}
	my $o_keys=O_KEYS;
	for my $k(keys %h) {
		unless (grep($_ eq $k,@$o_keys)) {
			print STDERR "$k: key on 'o' option is not valid - valid keys are ",join(',',@$o_keys),"\n";
			exit 1;
		}
	}
	$Opt{o}=\%h;
}
else {
	$Opt{o}={};
}

$Opt{w}=DEFAULT_VIEW_PREFIX unless defined $Opt{w};
$Opt{r}=DEFAULT_ROOT_TABLE_NAME unless defined $Opt{r};
$Opt{s}=DEFAULT_SEQUENCE_PREFIX unless defined $Opt{s};
$Opt{b}=DEFAULT_TABLE_DICTIONARY.':'.DEFAULT_COLUMN_DICTIONARY.':'.DEFAULT_RELATION_DICTIONARY unless defined $Opt{b};
my @dic=split(":",$Opt{b});
$dic[0]=DEFAULT_TABLE_DICTIONARY unless $dic[0];
$dic[1]=DEFAULT_COLUMN_DICTIONARY unless $dic[1];
$dic[2]=DEFAULT_RELATION_DICTIONARY unless $dic[2];

if (scalar(@dic) != 3) {
	print STDERR $Opt{b},": option b is invalid - valid is <table_dictionary>[:<column_dictionary>[:<relation_dictionary>]]\n";
	exit 1;
}
$Opt{b}=\@dic;


my $schema_pathname=sub {
	my $s=shift;
	$s='-' unless defined $s;
	$s='-' unless length($s);
	return $s;
}->(shift @ARGV);


my @cmds=@ARGV;
for my $cmd(@cmds) {
	unless (grep($_ eq $cmd,qw( drop_table create_table addpk drop_sequence create_sequence drop_view create_view drop_dictionary create_dictionary insert_dictionary display_path_relation display_cl_namespaces))) {
		print STDERR "$cmd: invalid command\n";
		exit 1;
	}
}


my $p=blx::xsdsql::parser->new(DB_NAMESPACE => $db_namespace,DEBUG => $Opt{d}); 

unless (grep($_ eq $Opt{n},blx::xsdsql::generator::get_namespaces)) {
	print STDERR $Opt{n},": Can't locate namespace in \@INC\n";
	exit 1;
}


my $g=blx::xsdsql::generator->new(OUTPUT_NAMESPACE => $output_namespace,DB_NAMESPACE => $db_namespace,FD => *STDOUT,DEBUG => $Opt{d});


my $schema=$p->parsefile(
	$schema_pathname
	,ROOT_TABLE_NAME 				=> $Opt{r}
	,TABLE_PREFIX 					=> $Opt{p}
	,VIEW_PREFIX 					=> $Opt{w}
	,SEQUENCE_PREFIX				=> $Opt{s}
	,TABLE_DICTIONARY_NAME 			=> $Opt{b}->[0]
	,COLUMN_DICTIONARY_NAME			=> $Opt{b}->[1] 
	,RELATION_DICTIONARY_NAME 		=> $Opt{b}->[2]
	,SCHEMA_DUMPER					=> 0
) || exit 1;


for my $cmd(@cmds) {
	if ($cmd eq 'display_path_relation') {
		my $paths=$schema->get_attrs_value(qw(MAPPING_PATH))->get_attrs_value(qw(TC));
		for my $line(map {
								my $k=$_;
								my $e=$paths->{$k};
								my $obj=ref($e) eq 'HASH' ? $e->{C} : $e->[-1]->{T};
								my $minoccurs=$obj->get_min_occurs;
								my	$out=($minoccurs == 0 ? " " : "M").' '.$k.' => '.(ref($e) eq 'HASH' ? $e->{C}->get_full_name : $e->[-1]->{T}->get_sql_name);
								$out;
							} sort keys %$paths) {
			print "$line\n";
		}
		print "\n";
	}
	elsif ($cmd eq 'display_cl_namespaces') {
		for my $n(sort @cl_namespaces) {
			print STDOUT $n,"\n";
		}
	}
	else {
		$g->generate(
			SCHEMA				=> $schema
			,COMMAND 			=> $cmd
			,LEVEL_FILTER		=> $Opt{l}
			,TABLES_FILTER		=> $Opt{t}
			,%{$Opt{o}}
		);
	}
}

exit 0;
