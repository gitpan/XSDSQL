#!/usr/bin/perl
use strict;
use warnings;
use integer;
use English '-no_match_vars';
use Carp;
use Getopt::Std;
use blx::xsdsql::dbconn;

my %Opt=();
unless (getopts ('hlp:',\%Opt)) {
	 print STDERR "invalid option or option not set\n";
	 exit 1;
}

if ($Opt{h}) {
	print STDOUT "
		$0  -l|-h  
		$0  <application> [<dbtype>] <connstr>
			 emit on stdout database connection string  converted into db dependent format
		<options>: 
			-h  - this help
			-l  - list the applications anf the database types implemented
			-p  - extra params in format <name>[=| ]<value>[,...]
			<application> - application name  (Es: dbi) - use the option 'l' for emit a list
			<dbtype> - database type (Es: pg) - use the option 'l' for emit a list
			<connstr> - database connection string 
						the form is [dbtype:]<user>/<password>\@<dbname>[:<host>[:<port>]]
	"; 
    exit 0;
}


if ($Opt{l}) {
	my @appls=blx::xsdsql::dbconn::get_applications_classname;
	print STDOUT join("\n",@appls),"\n";
	exit 0;
}

if (scalar(@ARGV) < 2) {
	print STDERR "missing arguments\n";
	exit 1;
}

if (scalar(@ARGV) > 3) {
	print STDERR "too many arguments\n";
	exit 1;
}

my %params=defined $Opt{p}
	? map {
		my @out=();
		/^(\w+)([\s=])(.*)$/;
		if (defined $1) {
			if ($2 eq '=') {				
				@out=($1,$3);
			}
			else {
				@out=($1,undef,$2,undef);
			}
		}
		else {
			@out=($_,undef);
		}
		@out;
	} split(',',$Opt{p})
	: ();

my $application=$ARGV[0];
my $dbtype=scalar(@ARGV) == 3 ? $ARGV[1] : undef;
my $connstr=scalar(@ARGV) == 3 ? $ARGV[2] : $ARGV[1];
my $dbconn=blx::xsdsql::dbconn->new;
my @a=$dbconn->get_application_string($connstr,%params,APPLICATION => $application,DBTYPE => $dbtype);
if (scalar(@a) == 0) {
	print STDERR "$connstr: connection string is not correct\n";
	exit 1;
}

print join("\n",@a),"\n";
exit 0;

