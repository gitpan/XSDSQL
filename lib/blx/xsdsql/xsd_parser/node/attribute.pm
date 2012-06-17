package blx::xsdsql::xsd_parser::node::attribute;
use base(qw(blx::xsdsql::xsd_parser::node));
use strict;
use warnings FATAL => 'all';
use integer;
use Carp;
use blx::xsdsql::xsd_parser::type;

sub trigger_at_start_node {
	my ($self,%params)=@_;

	if (defined (my $name=$self->get_attrs_value(qw(name)))) {
		my $column = $self->get_attrs_value(qw(COLUMN_CLASS))->new(
			NAME		=> $name
			,ATTRIBUTE	=> 1
		);

		if (defined (my $type=$self->get_attrs_value(qw(type)))) {
			my $ty_obj=blx::xsdsql::xsd_parser::type::factory(
				$type
				,SCHEMA => $self->get_attrs_value(qw(STACK))->[1]
				,DEBUG => $self->get_attrs_value(qw(DEBUG))
			);
			$column->set_attrs_value(TYPE => $ty_obj);
		}
	
		my $parent_table=$self->_get_parent_table;
		if ($parent_table->is_root_table) {
			 $self->get_attrs_value(qw(STACK))->[1]->_add_attrs($column);
		}
		else {
			$parent_table->_add_columns($column);
		}
		$self->set_attrs_value(TABLE => $parent_table);
	}
	elsif (defined (my $ref=$self->get_attrs_value(qw(ref)))) {
		my $column = $self->get_attrs_value(qw(COLUMN_CLASS))->new(
			NAME		=> $ref
			,ATTRIBUTE	=> 1
			,REF		=> 1
		);
		my $parent_table=$self->_get_parent_table;
		if ($parent_table->is_root_table) {
			 $self->get_attrs_value(qw(STACK))->[1]->_add_attrs($column);
		}
		else {
			$parent_table->_add_columns($column);
		}
		$self->set_attrs_value(TABLE => $parent_table);
	} else {
		confess "internal error - attribute without name or ref is not implemented\n";
	}
	return $self;
}

sub trigger_at_end_node {
	my ($self,%params)=@_;
	unless (defined $self->get_attrs_value(qw(type))) {
		if (defined (my $childs=$self->get_attrs_value(qw(CHILD)))) {
			my $child=$childs->[0];
#			$self->_debug(__LINE__,$child);
			my $out={};
			my $table=$self->get_attrs_value(qw(TABLE));
			my ($schema,$col,$debug)=($self->get_attrs_value(qw(STACK))->[1],($table->get_columns)[-1],$self->get_attrs_value(qw(DEBUG)));
			$self->_resolve_simple_type($child,undef,$out,%params,SCHEMA => $schema,DEBUG => $debug);
			my $ty_obj=ref($out->{base}) eq '' 
					? blx::xsdsql::xsd_parser::type::simple->_new(NAME => $out,SCHEMA => $schema,DEBUG => $debug) 
					: $out->{base};
			$col->set_attrs_value(TYPE => $ty_obj);
		}
		elsif (defined (my $ref=$self->get_attrs_value(qw(ref)))) {
			#empty 
		}
		else {
			confess "attribute without  type and childs\n";
		}
	}
	return $self;
}

sub factory_type {
	my ($self,$t,$types,%params)=@_;
	my ($schema,$debug)=($t->get_attrs_value(qw(STACK))->[1],$self->get_attrs_value(qw(DEBUG)));
	my $table=$t->get_attrs_value(qw(TABLE));
	confess "not implemented\n";

}

1;

__END__


=head1  NAME

blx::xsdsql::xsd_parser::node::attribute - internal class for parsing schema 

=cut
