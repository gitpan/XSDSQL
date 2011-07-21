#!/usr/bin/perl
eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
use strict;
use warnings;
use integer;
use English '-no_match_vars';

use Carp;
use DBI;
use File::Basename;
use XML::Parser;
use XML::Writer;
use Getopt::Std;

use blx::xsdsql::ut qw(:all);
use blx::xsdsql::parser;
use blx::xsdsql::xml;
use blx::xsdsql::dbconn;


use constant {
	DEBUG  => 0
	,DEBUG_SQL => 0
	,COMMIT => 1
	,AUTOCOMMIT => 0
};

use constant {
 	DEFAULT_VIEW_PREFIX			=> 'V'
	,DEFAULT_ROOT_TABLE_NAME 	=> 'ROOT'
	,DEFAULT_SEQUENCE_PREFIX	=> 'S'
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
										if (defined $id) {
											print STDERR "xml load with id $id\n"; 
											if ($xml->{DB_TRANSACTION_MODE} eq 'h') {
			 									print STDERR "commit issue\n"; 
												$xml->{DB_CONN}->commit;
											}
										}
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
unless (getopts ('hdut:n:s:c:r:p:w:i:q:b:a:',\%Opt)) {
	print STDERR "invalid option or option not set\n";
	exit 1;
}

if ($Opt{h}) {
	print STDOUT "
$0  [<options>]  <command>  [<xsdfile>] [<xmlfile>|<root_id>] 
<options>: 
    -h  - this help
    -d  - emit debug info 
    -c - connect string to database - the default is the value of the env var DB_CONNECT_STRING
        otherwise is an error
         the form is  <user/password\@dbname[:hostname[:port]]>
         for the database type see <n> option
    -t <c|r|h>     - issue a commit or rollback at the end  (default commit)
                   - with  h issue  a commit after a read 
    -n <db_namespace> - default pg (PostgreSQL)
    -s <schema> - schema name in header for output xml (default <none>)
    -i <schema_instance> schema instance in header for output xml (default <none>)
    -r <root_table_name> - set the root table name  (default '".DEFAULT_ROOT_TABLE_NAME."')
    -p <table_prefix_name> - set the prefix for the tables name (default none)
    -w <view_prefix_name>  - set the prefix for views name (default '".DEFAULT_VIEW_PREFIX."')
            WARNING - This option can influence database objects names
    -q <sequence_prefix_name>  - set the prefix for sequences name (default '".DEFAULT_SEQUENCE_PREFIX."')
            WARNING - This option can influence database objects names
    -u - set encondig utf8 to xmlwriter
    -b - set the execute prefix for db objects (Ex.   'scott.' in oracle)
         this option not influence database objects names
    -a - set the execute suffix for db objects (Ex: '\@dblink' in oracle)
       this option not influence database objects names
  
<command>
    C      - test the connection to the database and exit
    r[ead] - read <xmlfile> and put into a database 
    w[rite]  - write xml file from database to stdout - root_id is mandatory 
    c[ombined] - read <xmlfile>, put into database and write to stdout reading from database
    d[elete] - write to stdout ed delete from database - root_id is mandatory
    cd|combined_delete - read <xmlfile>, put into database, write to stdout and delete reading from database
    "; 
    exit 0;
}


$Opt{c}=$ENV{DB_CONNECT_STRING} unless $Opt{c};
unless ($Opt{c}) {
	print STDERR "the connect string (see 'c' option) is not defined\n";
	exit 1;
}

$Opt{t}='c' unless $Opt{t};

if (scalar(@ARGV) < 1) {
	print STDERR "missing arguments\n";
	exit 1;
}

$Opt{n}='pg' unless $Opt{n};
unless (grep($Opt{n} eq $_,blx::xsdsql::parser::get_db_namespaces)) {
	print STDERR $Opt{n},": Can't locate db_namespace in \@INC\n";
	exit 1;
}

my $dbconn=blx::xsdsql::dbconn->new;
my @dbi_params=$dbconn->get_application_string($Opt{c},APPLICATION => 'dbi',DBTYPE => $Opt{n});
if (scalar(@dbi_params) == 0) {
	print STDERR $Opt{c},": connection string is not correct\n";
	exit 1;
}

if ($ARGV[0] eq 'C') {
	my $conn=DBI->connect(@dbi_params);
	exit 1 unless defined $conn;
	$conn->disconnect;
	exit 0;
}

if (scalar(@ARGV) < 2) {
	print STDERR "missing arguments\n";
	exit 1;
}

unless (-r $ARGV[1]) {
	print STDERR $ARGV[1].": xsdfile is not readable\n";
	exit 1;
}


my $p=blx::xsdsql::parser->new(DB_NAMESPACE => $Opt{n},DEBUG => $Opt{d}); 

my $cmd=$CMD{$ARGV[0]};
unless (defined $cmd)  {
	print STDERR  $ARGV[0].": unknow command\n";
	exit 1;
}

$Opt{r}=DEFAULT_ROOT_TABLE_NAME unless defined $Opt{r};
$Opt{w}=DEFAULT_VIEW_PREFIX unless defined $Opt{w};

my $schema=$p->parsefile(
	$ARGV[1]
	,ROOT_TABLE_NAME 	=> $Opt{r}
	,TABLE_PREFIX 		=> $Opt{p}
	,VIEW_PREFIX 		=> $Opt{w}
	,SEQUENCE_PREFIX	=> $Opt{q}	
) || exit 1;

my $conn=DBI->connect(@dbi_params) || exit 1;
$conn->{AutoCommit}=AUTOCOMMIT;

my $xmlwriter=XML::Writer->new(
	DATA_INDENT => 4
	,DATA_MODE => 1
	,NAMESPACES => 0
	,($Opt{u} ? ('ENCODING','UTF-8') : ())
);

my $xml=blx::xsdsql::xml->new(
	DB_CONN       				=> $conn
	,DB_NAMESPACE 				=> $Opt{n}
	,XSD_FILE     				=> $ARGV[1]
	,DEBUG        				=> $Opt{d}
	,SCHEMA						=> $schema
	,PARSER						=> XML::Parser->new
	,XMLWRITER    				=> $xmlwriter
	,SCHEMA_NAME  				=> $Opt{s}
	,SCHEMA_INSTANCE 			=> $Opt{i}
	,EXECUTE_OBJECTS_PREFIX		=> $Opt{b} 
	,EXECUTE_OBJECTS_SUFFIX		=> $Opt{a} 
	,DB_TRANSACTION_MODE		=> $Opt{t}
);


binmode(*STDERR,':utf8');

my $rc=$cmd->($xml,@ARGV);
$xml->finish;
$Opt{t} eq 'c'  ? $conn->commit : $conn->rollback;
print STDERR ($Opt{t} eq 'c'  ? "commit" : "roolback")," issue\n"; 
$conn->disconnect;
exit $rc;
