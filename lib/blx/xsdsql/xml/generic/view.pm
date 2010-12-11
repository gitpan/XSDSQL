package blx::xsdsql::xml::generic::view;

use strict;
use warnings;
use Carp;

use blx::xsdsql::ut;



our %_ATTRS_R=();
our %_ATTRS_W=();


sub new {
	my $classname=shift;
	my %params=@_;
	return bless(\%params,$classname);
}



1;

__END__


=head1  NAME

blx::xsdsql::xml::generic::view -  a view is a class with include the common methods from table class  and column class (for example the   max length of  a dictionary database name)

=cut

=head1 SYNOPSIS

use blx::xsdsql::xml::generic::view

=cut


=head1 DESCRIPTION

this package is a class - instance it with the method new


=head1 FUNCTIONS

this module defined the followed functions




=head1 EXPORT

None by default.


=head1 EXPORT_OK
	
none 

=head1 SEE ALSO

See blx:.xsdsql::generator for generate the schema of the database and blx::xsdsql::parser 
for parse a xsd file (schema file)


=head1 AUTHOR

lorenzo.bellotti, E<lt>bellzerozerouno@tiscali.itE<gt>

=head1 COPYRIG 

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut


