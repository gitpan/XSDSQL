package blx::xsdsql::xsd_parser::type::simple_content;
use strict;
use warnings;
use integer;
use Carp;
use blx::xsdsql::ut(qw(nvl));

use base(qw(blx::xsdsql::xsd_parser::type));

sub link_to_column {
	my ($self,$c,%params)=@_;
	my $ty=$self->get_attrs_value(qw(NAME));
	my $table=$ty->get_attrs_value(qw(TABLE));
	my $schema=$self->get_attrs_value(qw(SCHEMA));
	$c->set_attrs_value(
		 PATH_REFERENCE 		=> $table->get_path
		,TABLE_REFERENCE 		=> $table
		,TYPE 					=> $schema->get_attrs_value(qw(ID_SQL_TYPE))
		,INTERNAL_REFERENCE 	=> 1
	);
	return $self;
}

1;


__END__


=head1  NAME

blx::xsdsql::xsd_parser::type::simple_content - internal class for parsing schema 

=cut
