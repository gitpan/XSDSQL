#!/usr/bin/perl -w

package MyErrorHandler;
use strict;
use warnings;
use vars qw(@ISA);
@ISA = qw(XML::Xerces::PerlErrorHandler);

#use base qw(XML::Xerces::PerlErrorHandler);

sub new {
	my $this = shift;
	my $class = ref($this) || $this;
	my $self = {
			COUNTER_W => 0
			,COUNTER_E => 0
			,COUNTER_F => 0
	};
	return bless $self, $class;
}

sub reset_counters {
	my $self=shift;
	for my $c qw(COUNTER_W COUNTER_E COUNTER_F) {
		$self->{$c}=0;
	};
	return $self;
}

sub warning {
	my ($self,$super)=@_;
	my $line = $super->getLineNumber;
	my $column = $super->getColumnNumber;
	my $message = $super->getMessage;
  	printf STDERR "%s:[%s]:%d:%d:%s:%s\n",
    $main::PROGRAM,$main::FILE,$line, $column, 'W', $message;
    $self->{COUNTER_W}++;
	return $self;
}

sub error {
	my ($self,$super)=@_;
	my $line = $super->getLineNumber;
	my $column = $super->getColumnNumber;
	my $message = $super->getMessage;
	printf STDERR "%s:[%s]:%d:%d:%s:%s\n",
	$main::PROGRAM,$main::FILE,$line, $column, 'E', $message;
	$self->{COUNTER_E}++;
	return $self;
}

sub fatal_error {
	my ($self,$super)=@_;
	my $line = $super->getLineNumber;
	my $column = $super->getColumnNumber;
	my $message = $super->getMessage;
	printf STDERR "%s:[%s]:%d:%d:%s:%s\n",
	$main::PROGRAM,$main::FILE,$line, $column, 'F', $message;
	$self->{COUNTER_F}++;
	return $self;
}


sub get_warning_count {
	my $self=shift;
	return $self->{COUNTER_W};
}

sub get_error_count {
	my $self=shift;
	return $self->{COUNTER_E};
}

sub get_fatal_count {
	my $self=shift;
	return $self->{COUNTER_F};
}

1;


package main;

use strict;
use warnings;
use XML::Xerces;
use IO::Handle;
use Cwd qw(abs_path);
use Getopt::Std;
use File::Basename;

    
sub usage($) {
    my $rc=shift;
    my $file=*STDERR;
    print $file "
$0  [-hv]   [-s <schema_file> ] [<xml_file>]...
    esegue la validazione di uno o piu file xml
    -h - questo aiuto    
    -v - opzione verbose
    -s <schema_file> - nome file di schema
    xml_file - nome file xml - se nessun  file � specificato esegue solo la verifica di lettura di <schema_file> (se specificato)  
"; 
    exit $rc;
}


use constant	{
	EXIT_OK				=>   0
	,EXIT_INPUTERROR		=>   1
};


my %Opt=();
getopts ('hvs:', \%Opt) or exit EXIT_INPUTERROR;
usage(EXIT_OK) if (defined $Opt{h});

if (defined $Opt{s}) {
	unless (-r $Opt{s}) {
		print STDERR $Opt{s},": non leggibile \n";
		exit EXIT_INPUTERROR;
	}
	else {
		$Opt{s}=abs_path($Opt{s});	  #il parser sballa se e' un path relativo
	}
}




my  ($namespace,$schema,$full_schema) = (1,1,1);
$main::PROGRAM = basename $0;
my $parser = XML::Xerces::XMLReaderFactory::createXMLReader();
my $myerrhandler = new MyErrorHandler;
$parser->setErrorHandler($myerrhandler);

STDERR->autoflush();

eval {
	$parser->setFeature("$XML::Xerces::XMLUni::fgSAX2CoreNameSpaces", $namespace);
	$parser->setFeature("$XML::Xerces::XMLUni::fgXercesSchema", $schema);
	$parser->setFeature("$XML::Xerces::XMLUni::fgXercesSchemaFullChecking", $full_schema);

	# Associa, se richiesto, uno schema XML (xsd) esterno
	if ( $Opt{s}  &&  $schema  &&  $full_schema ) {
		$parser->setProperty("$XML::Xerces::XMLUni::fgXercesSchemaExternalNoNameSpaceSchemaLocation", $Opt{s});
	}
  
};
XML::Xerces::error($@) if $@;

# and the required features
eval {
  $parser->setFeature("$XML::Xerces::XMLUni::fgXercesContinueAfterFatalError", 1);
  $parser->setFeature("$XML::Xerces::XMLUni::fgXercesValidationErrorAsFatal", 0);
  $parser->setFeature("$XML::Xerces::XMLUni::fgSAX2CoreValidation", 1);
  $parser->setFeature("$XML::Xerces::XMLUni::fgXercesDynamic", 1);
};
XML::Xerces::error($@) if $@;

for my $xmlFile(@ARGV) {
	print STDERR "$xmlFile: elabora file\n" if $Opt{v}; 
	unless (-r $xmlFile)  {
		print STDERR "$xmlFile: non leggibile \n";
		exit EXIT_INPUTERROR;
	}
	$main::FILE = $xmlFile;
	eval {
	  my $is = XML::Xerces::LocalFileInputSource->new($xmlFile);
	  $parser->parse($is) ;
	}; 
	XML::Xerces::error($@) if $@;
}

if ($Opt{v}) {
	print STDERR "W count ",$myerrhandler->get_warning_count,"\n";
	print STDERR "E count ",$myerrhandler->get_error_count,"\n";
	print STDERR "F count ",$myerrhandler->get_fatal_count,"\n";
}

exit EXIT_INPUTERROR if $myerrhandler->get_error_count() + $myerrhandler->get_fatal_count() > 0;
exit EXIT_OK;

