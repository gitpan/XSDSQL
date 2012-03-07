package blx::xsdsql::xsd_parser::type::group;
use strict;
use warnings;
use integer;
use Carp;
use blx::xsdsql::ut qw(nvl);

use base qw(blx::xsdsql::xsd_parser::type);


sub link_to_column {
	my ($self,$c,%params)=@_;
	my $ty=$self->get_attrs_value qw(NAME);
	my $table=$ty->get_attrs_value qw(TABLE);
	my $schema=$self->get_attrs_value qw(SCHEMA);
	$c->set_attrs_value(
		TYPE 					=> $schema->get_attrs_value qw(ID_SQL_TYPE)
		,INTERNAL_REFERENCE		=> 0
		,PATH_REFERENCE 		=> $table->get_path
		,TABLE_REFERENCE 		=> $table
	); 
	return $self;
}

1;


__END__


=head1  NAME

blx::xsdsql::xsd_parser::type::group - internal class for parsing schema 

=cut
