package blx::xsdsql::xsd_parser::node::group;
use base qw(blx::xsdsql::xsd_parser::node);
use strict;
use warnings;
use integer;
use Carp;
use POSIX;
use Data::Dumper;
use blx::xsdsql::ut qw(nvl);
use blx::xsdsql::xml::generic::table qw(:overload);
use blx::xsdsql::xsd_parser::type;
use blx::xsdsql::xsd_parser::type::group;

sub trigger_at_start_node {
	my ($self,%params)=@_;
	my $parent_table=$self->_get_parent_table;
	my $schema=$self->get_attrs_value qw(STACK)->[1];
	if (defined (my $ref=$self->get_attrs_value qw(ref))) {
		my $isparent_choice=$parent_table->get_attrs_value qw(CHOICE);
		my ($maxoccurs,$minoccurs) = ($self->_resolve_maxOccurs,$self->_resolve_minOccurs(CHOICE => $isparent_choice)); 
		my $name=nvl($self->get_attrs_value qw(name),$ref);
		my $ty_obj=blx::xsdsql::xsd_parser::type::factory(
				$ref
				,SCHEMA => $self->get_attrs_value qw(STACK)->[1]
				,DEBUG => $self->get_attrs_value qw(DEBUG)
		);

		my $column = $self->get_attrs_value qw(COLUMN_CLASS)->new(
			PATH			=> $self->_construct_path(undef,%params,PARENT => undef)
			,NAME			=> $name
			,TYPE			=> $ty_obj
			,MINOCCURS		=> $minoccurs
			,MAXOCCURS		=> $maxoccurs
			,GROUP_REF		=> 1
			,CHOICE			=> $isparent_choice
			,ELEMENT_FORM 	=> $self->_resolve_form
		);
		if (defined $parent_table->get_xsd_seq) {	   #the table is a sequence or choice
			$column->set_attrs_value(XSD_SEQ => $parent_table->get_xsd_seq); 
			$parent_table->_inc_xsd_seq unless $isparent_choice; #the columns of a choice have the same xsd_seq
		}
		$parent_table->_add_columns($column);
		$self->set_attrs_value(TABLE => $parent_table);
	}
	elsif (defined (my $name=$self->get_attrs_value qw(name))) {
		my $table = $self->get_attrs_value qw(TABLE_CLASS)->new (
			PATH			=> $self->_construct_path($name,PARENT => undef)
			,NAME			=> $name
			,XSD_TYPE		=> XSD_TYPE_GROUP
			,XSD_SEQ		=> 1
		);
		$schema->set_table_names($table);
		$table->_add_columns(
			$schema->get_attrs_value qw(ANONYMOUS_COLUMN)->_factory_column qw(ID)
			,$schema->get_attrs_value qw(ANONYMOUS_COLUMN)->_factory_column qw(SEQ)
		);
		$self->set_attrs_value(TABLE => $table);
		$schema->add_types($self);
	}
	else {
		confess __LINE__.". group without name or ref\n";
	}
	return $self;
}

sub factory_type {
	my ($self,$t,$types,%params)=@_;
	return blx::xsdsql::xsd_parser::type::group->_new(NAME => $t,SCHEMA => $t->get_attrs_value qw(STACK)->[1],DEBUG => $self->get_attrs_value qw(DEBUG));
}

1;


__END__


=head1  NAME

blx::xsdsql::xsd_parser::node::group - internal class for parsing schema 

=cut
