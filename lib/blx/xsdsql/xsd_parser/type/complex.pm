package blx::xsdsql::xsd_parser::type::complex;
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
	$self->_debug(__LINE__,'column ',$c->get_full_name,'  ref to table ',$table->get_sql_name);
	my $schema=$self->get_attrs_value qw(SCHEMA);
	$c->set_attrs_value(
		TYPE 					=> $schema->get_attrs_value qw(ID_SQL_TYPE)
		,INTERNAL_REFERENCE		=> $table->get_attrs_value qw(INTERNAL_REFERENCE)
		,PATH_REFERENCE 		=> $table->get_path
		,TABLE_REFERENCE 		=> $table
	); 
	return $self;
}

1;

__END__


=head1  NAME

blx::xsdsql::xsd_parser::type::complex - internal class for parsing schema 

=cut

