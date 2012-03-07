package blx::xsdsql::xml::oracle::table;

use strict;
use warnings;
use integer;
use Carp;

use base qw( blx::xsdsql::xml::oracle::catalog blx::xsdsql::xml::generic::table   );

my %INVALID_NAMES=();

sub new {
	my ($class,%params)=@_;
	return bless(blx::xsdsql::xml::generic::table->_new(%params),$class)
}

sub _get_attrs_w { return \%blx::xsdsql::xml::generic::table::_ATTRS_W; }
sub _get_attrs_r { return \%blx::xsdsql::xml::generic::table::_ATTRS_R; }


sub _resolve_invalid_name {
	my ($self,$name,%params)=@_;
	if (exists $INVALID_NAMES{uc($name)}) {
		$name=substr($name,0,$self->get_name_maxsize - 1) if length($name) >= $self->get_name_maxsize;
		$name.='_';
	}
	return $name;
}


1;



__END__

=head1  NAME

	blx::xsdsql::xml::oracle::table -  a table class for oracle
 
=cut

=head1 SYNOPSIS

  use blx::xsdsql::xml::oracle::table

=cut


=head1 DESCRIPTION

this package is a class - instance it with the method new


=head1 FUNCTIONS

see the methods of blx::xsdsql::xml::generic::table and blx::xsdsql::xml::oracle::catalog 
 

=head1 EXPORT

None by default.


=head1 EXPORT_OK
	
none 

=head1 SEE ALSO

See blx::xsdsql::xml::generic::table and blx::xsdsql::xml::oracle::catalog  - this class inerith for it 

See blx:.xsdsql::generator for generate the schema of the database and blx::xsdsql::parser  for parse a xsd file (schema file)

=head1 AUTHOR

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIG 

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut




