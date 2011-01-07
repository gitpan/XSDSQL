package blx::xsdsql::xml::pg::catalog;

use strict;
use warnings;
use Carp;

use base qw(blx::xsdsql::xml::generic::catalog);

use constant {
				 DICTIONARY_NAME_MAXSIZE	=> 63
};

sub get_name_maxsize { return DICTIONARY_NAME_MAXSIZE; }

1;

__END__

=head1  NAME

	blx::xsdsql::xml::pg::catalog -  a catalog class for postgresql 
=cut

=head1 SYNOPSIS

  use blx::xsdsql::xml::pg::catalog

=cut


=head1 DESCRIPTION

this package is a class - instance it with the method new


=head1 FUNCTIONS

see the methods of blx::xsdsql::xml::generic::catalog
 

=head1 EXPORT

None by default.


=head1 EXPORT_OK
	
none 

=head1 SEE ALSO

See blx::xsdsql::xml::generic::catalog - this class inerith for it 

See blx:.xsdsql::generator for generate the schema of the database and blx::xsdsql::parser  for parse a xsd file (schema file)

=head1 AUTHOR

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIG 

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut




