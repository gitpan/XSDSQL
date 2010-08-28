#!/usr/bin/perl
use strict;
use warnings;
use integer;
use English '-no_match_vars';

use Carp;
use DBI;
use blx::xsdsql::ut qw(:all);
use blx::xsdsql::parser;
use blx::xsdsql::xml;
use Getopt::Std;
use File::Basename;
use XML::Parser;
use XML::Writer;

use constant {
		DBI_TYPE  => 'dbi:Pg'
};

my %Connection=(
	 DBNAME    => 'mydb'
	,HOST     => '127.0.0.1'
	,PORT     =>  undef
	,OPTIONS  => undef
	,TTY      => undef
);


my $Connect_string=DBI_TYPE.':'.join(';',map { lc($_).'='.$Connection{$_} } grep(defined $Connection{$_},keys %Connection));

use constant {
	USER  => 'xmldb'     #set the correct user
	,PWD  => 'xmldb'     #set the correct pwd
	,SEQUENCE_NAME   =>  'xmldb_seq'  # create this sequence if is not created
	,DEBUG  => 0
	,DEBUG_SQL => 0
	,COMMIT => 1
	,AUTOCOMMIT => 0
};

my %CMD=();
%CMD=(
			r                 =>  sub {
										my $xml=shift;
										my @argv=@_;
										my $fd=defined $argv[2] ? undef : *STDIN;
										unless (open($fd,"<",$argv[2])) {
											print STDERR  $argv[2].": $!";
											return (1);
										}
										my $id=$xml->read(FD => $fd);
										close $fd unless  $fd eq *STDIN;
										print STDERR "xml load with id $id\n";
										return wantarray ? (0,$id) : 0;
			}
			,read             => sub { return $CMD{r}->(@_); }
			,w                 => sub {
										my $xml=shift;
										my @argv=@_;
										my $r=$xml->write(ROOT_ID => $argv[2]);
										unless (defined $r) {
											print STDERR $argv[2],": root_id not found into the database\n";
											return 1;
										}
										return 0;
			}
			,write             => sub {  return $CMD{w}->(@_); }
			,c                 => sub {
										 my ($rc,$id)=$CMD{r}->(@_);
										 return $rc if $rc;
										 $_[3]=$id;
										 return $CMD{w}->(@_);
								}
			,combine           => sub { return $CMD{c}->(@_); }
			,d                 => sub {
										my $xml=shift;
										my @argv=@_;
										my $r=$xml->write(ROOT_ID => $argv[2],DELETE_ROWS => 1);
										unless (defined $r) {
											print STDERR $argv[2],": root_id not found into the database\n";
											return 1;
										}
										return 0;
			}
			,'delete'           => sub {  return $CMD{d}->(@_); }
			,cd                 => sub {
										 my ($rc,$id)=$CMD{r}->(@_);
										 return $rc if $rc;
										 $_[3]=$id;
										 return $CMD{d}->(@_);
								}
			,combine_delete     => sub {  return $CMD{cd}->(@_); }
);


my %Opt=();
getopts ('hdt:n:s:c:U:P:r:',\%Opt) or exit 1;
if ($Opt{h}) {
	print STDOUT "
		$0  [<options>]  <command>  <xsdfile> [<xmlfile>|<root_id>] 
		<options>: 
			-h  - this help
			-d  - emit debug info 
			-c - connect string to database - default is $Connect_string
			-U - user for connect to database - defaul is ",USER,"
			-P - pwd for connect to database - default is ",PWD,"
			-t <c|r>	 - issue a commit or rollback at the end  (default commit)
			-n <namespace> - default pg (PostgreSQL)
			-s <schema> - schema name for output xml (default <none>)
			-r <root table name> - set the root table name (default ROOT)
		<command>
			C      - test the conmnection to the database and exit
			r[ead] - read <xmlfile> and put into into a database 
			w[rite]  - write xml file from database to stdout - root_id is mandatory 
			c[ombined] - read <xmlfile>, put into database and write to stdout reading from database
			d[elete] - write to stdout ed delete from database - root_id is mandatory
			cd|combined_delete - read <xmlfile>, put into database and write to stdout and deleting reading from database
	"; 
    exit 0;
}


$Opt{c}=$Connect_string unless nvl($Opt{c});
$Opt{U}=USER unless nvl($Opt{U});
$Opt{P}=PWD unless nvl($Opt{P});

if (scalar(@ARGV) < 2) {
	print STDERR "missing arguments\n";
	exit 1;
}

print STDERR "connected string is: '",$Opt{c}," with user ",$Opt{U},"\n";

if ($ARGV[0] eq 'C') {
	my $conn=DBI->connect($Opt{c},$Opt{U},$Opt{P});
	exit 1 unless defined $conn;
	$conn->disconnect;
	exit 0;
}


unless (-r $ARGV[1]) {
	print STDERR "xsdfile is not readable\n";
	exit 1;
}

$Opt{n}='pg' unless defined $Opt{n};
unless (grep($Opt{n} eq $_,blx::xsdsql::parser::get_db_namespaces)) {
	print STDERR $Opt{n},": Can't locate db_namespace in \@INC\n";
	exit 1;
}

my $p=blx::xsdsql::parser->new(DB_NAMESPACE => $Opt{n}); 

my $cmd=$CMD{$ARGV[0]};
unless (defined $cmd)  {
	print STDERR  $ARGV[0].": unknow command\n";
	exit 1;
}

my $root_table=$p->parsefile($ARGV[1],ROOT_TABLE_NAME => nvl($Opt{r},'ROOT'));
my $conn=DBI->connect($Opt{c},$Opt{U},$Opt{P}) || exit 1;
$conn->{AutoCommit}=AUTOCOMMIT;

my $xml=blx::xsdsql::xml->new(
	DB_CONN       => $conn
	,DB_NAMESPACE => $Opt{n}
	,XSD_FILE     => $ARGV[1]
	,DEBUG        => $Opt{d}
	,SEQUENCE_NAME => SEQUENCE_NAME
	,ROOT_TABLE   => $root_table
	,SCHEMA_NAME  => $Opt{s}
	,PARSER       => XML::Parser->new
	,XMLWRITER    => XML::Writer->new(DATA_INDENT => 4,DATA_MODE => 1,ENCODING => 'UTF-8',NAMESPACES => 0)
);

my $rc=$cmd->($xml,@ARGV);
$xml->finish;
$Opt{t} eq 'c'  ? $conn->commit : $conn->rollback;
print STDERR ($Opt{t} eq 'c'  ? "commit" : "roolback")," issue\n"; 
$conn->disconnect;
exit $rc;
