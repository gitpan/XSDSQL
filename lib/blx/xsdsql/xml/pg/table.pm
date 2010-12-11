package blx::xsdsql::xml::pg::table;

use strict;
use warnings;
use integer;
use Carp;

use base qw( blx::xsdsql::xml::pg::catalog blx::xsdsql::xml::generic::table   );


sub new {
	my ($class,%params)=@_;
	return bless(blx::xsdsql::xml::generic::table->new(%params),$class)
}

sub set_attrs_value {
	my $self=shift;
	return blx::xsdsql::ut::set_attrs_value($self,\%blx::xsdsql::xml::generic::table::_ATTRS_W,@_);
}

sub get_attrs_value {
	my $self=shift;
	return blx::xsdsql::ut::get_attrs_value($self,\%blx::xsdsql::xml::generic::table::_ATTRS_R,@_);
}



1;

__END__

=head1  NAME

	blx::xsdsql::xml::pg::table -  a table class for postgresql
 
=cut

=head1 SYNOPSIS

  use blx::xsdsql::xml::pg::table

=cut


=head1 DESCRIPTION

this package is a class - instance it with the method new


=head1 FUNCTIONS

see the methods of blx::xsdsql::xml::generic::table and blx::xsdsql::xml::pg::catalog 
 

=head1 EXPORT

None by default.


=head1 EXPORT_OK
	
none 

=head1 SEE ALSO

See blx::xsdsql::xml::generic::table and blx::xsdsql::xml::pg::catalog  - this class inerith for it 

See blx:.xsdsql::generator for generate the schema of the database and blx::xsdsql::parser  for parse a xsd file (schema file)

=head1 AUTHOR

lorenzo.bellotti, E<lt>bellzerozerouno@tiscali.itE<gt>

=head1 COPYRIG 

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut




