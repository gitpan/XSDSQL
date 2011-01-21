#!/usr/bin/perl
use 5.008000;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use Getopt::Long qw(GetOptions);

GetOptions(\my %opt,
   'no-programs|n'
) or do {
    die "Usage: $0 [--no-programs|-n] \n";
};

my @prog;
push(@prog, qw(xml.pl xsd2sql.pl ))
    unless $opt{'no-programs'} || grep /^LIB=/, @ARGV;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

#print STDERR  "---->",join(" ", map "bin/$_", grep /^[A-Z]+$/, @prog),"\n";

WriteMakefile(
	NAME              => 'blx::xsdsql'
	,VERSION_FROM      => 'lib/blx/xsdsql/ut.pm'
	,PREREQ_PM         => { 
						'Rinchi::XMLSchema' => '0.02' 
						, 'XML::Parser' => '1.21' 
						, 'XML::Writer' => '0.600'
						, 'DBI'		=> '1.58'
	}
	,LICENSE => "perl"
	,EXE_FILES => [ map "bin/$_", @prog ]
	,($] >= 5.005 ?     ## Add these new keywords supported since 5.005
		(
			ABSTRACT 	=> 'xsd converter to relational database  objects; xml  load & unload from/to the database'
			,AUTHOR         => 'lorenzo.bellotti <pauseblx@gmail.com>'
		) : ()
	)
	,clean => { FILES => "  t/xml_*/*.sql   t/xml_*/*.diff t/xml_*/*.tmp  t/xml_*/.step t/.strconn " }
);
