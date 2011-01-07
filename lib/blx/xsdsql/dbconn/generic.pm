package blx::xsdsql::dbconn::generic;
use strict;
use warnings;
use integer;
use Carp;

sub _split {
	my ($self,$s,%params)=@_;
	return undef unless defined $s;
	my ($user,$pwd,$dbname,$host,$port)=$s=~/^(\w+)\/(\w+)@(\w+):([^:]+):(\d*)$/;
	($user,$pwd,$dbname,$host)=$s=~/^(\w+)\/(\w+)@(\w+):([^:]+)$/ unless defined $user;
	($user,$pwd,$dbname)=$s=~/^(\w+)\/(\w+)@(\w+)$/ unless defined $user;
	return undef unless defined $user;
	
	my %p=(
				 USER	=> $user
				,PWD	=> $pwd
				,DBNAME	=> $dbname
				,HOST	=> $host
				,PORT	=> $port
	);
	$params{$_}=$p{$_} for (keys %p);
	return \%params;
}

sub _get_as {
	my ($self,$connstr,%params)=@_;
	croak "abstract method"; 
}

sub get_application_string {
	my ($self,$connstr,%params)=@_;
	my $h=$self->_split($connstr,%params);
	return wantarray ? () : undef unless defined $h;
	my @a=$self->_get_as($h,%params);
	return @a if wantarray;
	return scalar(@a)==0 ? undef : \@a;
}

sub new {
	my ($class,%params)=@_;
	return bless \%params,$class;
}


1;

__END__

=head1 NAME

blx::xsdsql::dbconn::generic  - generic converted database connection string into specific application form


=head1 SYNOPSIS


use blx::xsdsql::dbconn::generic


=head1 DESCRIPTION

this package is a class - instance it with the method new

=cut


=head1 FUNCTIONS


new - constructor

	PARAMS - none


get_application_string - return an array of data for application input

	the first argument is a string into a form <database_type>:<user>/<pwd>@<database_name>[:<host>[:<port>]]



=head1 EXPORT

None by default.


=head1 EXPORT_OK

None

=head1 SEE ALSO


See  blx::xsdsql::dbconn::pg::dbi   - this class inherit from this and implement the dbi for postgresql 


=head1 AUTHOR

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
 


