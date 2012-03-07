package blx::xsdsql::xsd_parser::node::simpleType;
use base qw(blx::xsdsql::xsd_parser::type_restriction);
use strict;
use warnings;
use integer;

sub trigger_at_start_node {
	my ($self,%params)=@_;
	if (defined (my $name=$self->get_attrs_value qw(name))) {
		my $schema=$self->get_attrs_value qw(STACK)->[1];
		$schema->add_types($self);
	}
	return $self;
}


sub factory_type {
	my ($self,$t,$types,%params)=@_;
	my $out={};
	$self->_resolve_simple_type($t,$types,$out,%params,SCHEMA => $t->get_attrs_value qw(STACK)->[1]);
	return blx::xsdsql::xsd_parser::type::simple->_new(NAME => $out,DEBUG => $self->get_attrs_value qw(DEBUG));
}

sub trigger_at_end_node {
	my ($self,%params)=@_;
	if (defined (my $name=$self->get_attrs_value qw(name))) {
			#### none
	}
	else {
		return $self->_hook_to_parent(%params);
	}
}

1;


__END__

=head1  NAME

blx::xsdsql::xsd_parser::node::simpleType - internal class for parsing schema 

=cut


