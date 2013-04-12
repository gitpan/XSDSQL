package blx::xsdsql::schema_repository::sql::oracle::column;
use strict;  # use strict is for PBP
use Filter::Include;
include blx::xsdsql::include;
#line 6
use base qw( blx::xsdsql::schema_repository::sql::generic::column blx::xsdsql::schema_repository::sql::oracle::catalog);
use blx::xsdsql::ut::ut qw(nvl);


sub new {
	my ($class,%params)=@_;
	return $class->blx::xsdsql::schema_repository::sql::generic::column::_new(%params);
}



1;


__END__

=head1  NAME

blx::xsdsql::schema_repository::sql::oracle::column -  a column class for oracle

=cut

=head1 SYNOPSIS

  use blx::xsdsql::schema_repository::sql::oracle::column

=cut


=head1 DESCRIPTION

this package is a class - instance it with the method new



=head1 VERSION

0.10.0

=cut

=head1 FUNCTIONS

see the methods of blx::xsdsql::schema_repository::sql::generic::column and blx::xsdsql::schema_repository::sql::oracle::catalog


=head1 EXPORT

None by default.


=head1 EXPORT_OK

none

=head1 SEE ALSO

See blx::xsdsql::schema_repository::sql::generic::column and blx::xsdsql::schema_repository::sql::oracle::catalog  - this class inerith for it

See blx:.xsdsql::generator for generate the schema of the database and blx::xsdsql::parser  for parse a xsd file (schema file)

=head1 AUTHOR

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut




