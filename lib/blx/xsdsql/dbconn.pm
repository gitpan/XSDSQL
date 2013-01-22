package blx::xsdsql::dbconn;
use strict;
use warnings;
use integer;
use Carp;
use File::Spec;
use blx::xsdsql::ut qw(ev);

sub new {
	my ($class,%params)=@_;
	return bless \%params,$class;
}

sub get_application_string {
	my ($self,$s,%params)=@_;
	unless (defined $s) {
		return wantarray ? () : undef;
	}
	for my $p(qw(APPLICATION DBTYPE)) {
		$params{$p} = $self->{$p} unless defined $params{$p};
	}
	croak "APPLICATION param not set" unless defined $params{APPLICATION};
	my $dbtype=$params{DBTYPE};
	unless (defined $dbtype) {
		($dbtype,my $newstr)=$s=~/^(\w+):(.*)$/;
		unless (defined $dbtype) {
			return wantarray ? () : undef;
		}		
		$s=$newstr;
	}
	my $use="blx::xsdsql::dbconn::${dbtype}::".$params{APPLICATION};
	ev("use $use");
	my $appl=$use->new;
	for my $p('APPLICATION DBTYPE') {
		delete $params{$p};
	}
	
	my @r=$appl->get_application_string($s,%params);
	return @r if wantarray;
	return undef unless scalar(@r);
	return \@r;
}
	
	
{
	my $cached=0;
	my @n=();
		
	sub get_applications_classname {
		if (!$cached) {
			for my $i(@INC) {
				my $dirgen=File::Spec->catdir($i,'blx','xsdsql','dbconn');
				next unless  -d "$dirgen";
				next if $dirgen=~/^\./;
				next unless opendir(my $fd,$dirgen);
				while(my $d=readdir($fd)) {
					my $dirout=File::Spec->catdir($dirgen,$d);
					next unless -d $dirout;
					next if $d=~/^\./;
					next unless opendir(my $fd1,$dirout);
					while(my $d1=readdir($fd1)) {
						my $f=File::Spec->catdir($dirgen,$d,$d1);
						next unless -r $f;
						next if $d1=~/^\./;
						next unless $d1=~/\.pm$/;
						$d1=~s/\.pm$//;
						push @n,'blx::xsdsql::dbconn::'.$d.'::'.$d1;
					}
					closedir $fd1;
				}
				closedir($fd);
			}
			$cached=1;
		}
		return wantarray ? @n : \@n;
	}
}

{
	my $cached=0;
	my @db=();
	sub get_database_availables {
		if (!$cached) {
			my %db=();
			for my $n(get_applications_classname) {
				if ($n=~/::(\w+)::\w+$/) {
					$db{$1}=undef;
				}
			}
			@db=sort keys %db;
			$cached=1;
		}
		return @db;		
	}
}

{
	my $cached=0;
	my @appl=();
	sub get_application_availables {
		if (!$cached) {
			my %appl=();
			for my $n(get_applications_classname) {
				if ($n=~/::(\w+)$/) {
					$appl{$1}=undef;
				}
			}
			@appl=sort keys %appl;
			$cached=1;
		}
		return @appl
	}
}

sub get_application_avaliables { 
	warn "deprecated method: use get_application_availables"; 
	goto &get_application_availables; 
}

=pod
{
	my $cached=0;
	my @db=();

	sub get_database_codes_availables {
		if (!$cached) {
			my %db=();
			for my $n(get_applications_classname) {
				my $m=$n.'::get_code';
				my $eval_code="
					use $n;
					&$m;
				";
		#		print STDERR $eval_code,"\n";
				my $code=eval($eval_code);		
		#		print STDERR $@ if $@;
				$db{$code}=undef if !$@ && defined $code && length($code);
			}
			@db=sort keys %db;
			$cached=1;
		}
		return @db;
	}
}
=cut



{
	my %info=();
	my $cached=0;
	sub get_info {
		if (!$cached) {
			for my $n(get_applications_classname) {
				my $m=$n.'::get_code';
				my $eval_code="
					use $n;
					&$m;
				";
				my $code=eval($eval_code);		
				my($dbtype,$application)=$n=~/(\w+)::(\w+)$/;
				if (defined $dbtype) {
					$info{$dbtype}->{$application}={
						CLASSNAME 		=> $n
						,DBTYPE			=> $dbtype
						,APPLICATION 	=> $application
						,CODE			=> $code
					}
				}
			}
		}
		$cached=1;
		return \%info;
	}
}

1;

__END__


=head1 NAME

blx::xsdsql::dbconn  -  convert database connection string into specific application form
						the application is for example dbi
						
=head1 SYNOPSIS

use blx::xsdsql::dbconn


=head1 DESCRIPTION

this package is a class - instance it with the method new

=cut


=head1 FUNCTIONS


new - constructor
	
	PARAMS: 
	
		DBTYPE - database type - the class method get_database_availables return valid values for this param
		APPLICATION - application name - the class method get_application_avaliables return valid values for this param
	

get_application_string - return the connection string for an application

	the 1^ param is a connection string into the form <user>/<pwd>@<database_name>[:<host>[:<port>]]
	
	PARAMS:
		DBTYPE - database type - same as the new constructor
		APPLICATION - application name - same as the new constructor
			
		

get_applications_classname - return the classes associated to an application

	PARAMS: none
	
	this method is a class method 
	

get_application_avaliables - return the application code availables - Ex dbi 
                             this method is deprecated - use get_application_availables

	PARAMS: none
	
	this method is a class method 


get_application_availables - return the application code availables - Ex dbi 

	PARAMS: none
	
	this method is a class method 

get_database_availables - return the database types availables - Ex: pg

	PARAMS: none
	
	this method is a class method 


get_info - return the info (an hash pointer) for databases and application  availables 

	PARAMS: none
	
	this method is a class method 

	
=head1 EXPORT

None by default.


=head1 EXPORT_OK

None

=head1 AUTHOR

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
 

