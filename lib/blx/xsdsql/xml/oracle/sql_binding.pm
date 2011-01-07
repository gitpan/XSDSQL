package blx::xsdsql::xml::oracle::sql_binding;

use base qw(blx::xsdsql::xml::generic::sql_binding);
use Carp;

sub get_next_sequence {
	my ($self,$table,%params)=@_;
	if (defined $params{SEQUENCE_NAME}) {
		if (defined $self->{PREPARE_SEQUENCE}) {
			$self->{PREPARE_SEQUENCE}->finish;
			delete $self->{PREPARE_SEQUENCE};
		}
		$self->{SEQUENCE_NAME}=$params{SEQUENCE_NAME};
	}
	croak "SEQUENCE_NAME param not defined" unless defined $self->{SEQUENCE_NAME}; 
	$self->{PREPARE_SEQUENCE}=$self->{DB_CONN}->prepare("select ".$self->{SEQUENCE_NAME}.".nextval from dual")
		unless defined $self->{PREPARE_SEQUENCE};

	$self->{PREPARE_SEQUENCE}->execute;
	my $r=$self->{PREPARE_SEQUENCE}->fetchrow_arrayref;
	return $r->[0];
}

sub finish {
	my ($self,%params)=@_;
	(delete $self->{PREPARE_SEQUENCE})->finish if defined $self->{PREPARE_SEQUENCE};
	return $self->SUPER::finish(%params);
}

1;




__END__

=head1  NAME

	blx::xsdsql::xml::oracle::sql_binding -  a binding class for oracle
 
=cut

=head1 SYNOPSIS

  use blx::xsdsql::xml::oracle::sql_binding

=cut


=head1 DESCRIPTION

this package is a class - instance it with the method new


=head1 FUNCTIONS

see the methods of  blx::xsdsql::xml::generic::sql_binding  
 

=head1 EXPORT

None by default.


=head1 EXPORT_OK
	
none 

=head1 SEE ALSO

See blx::xsdsql::xml::generic::sql_binding   - this class inerith for it 

See blx:.xsdsql::generator for generate the schema of the database and blx::xsdsql::parser  for parse a xsd file (schema file)

=head1 AUTHOR

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIG 

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut




