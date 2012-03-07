package blx::xsdsql::xsd_parser::node::choice;
use base qw(blx::xsdsql::xsd_parser::node);
use strict;
use warnings;
use integer;
use Carp;
use POSIX;
use Data::Dumper;
use blx::xsdsql::ut qw(nvl);
use blx::xsdsql::xsd_parser::type;

use constant {
	DEFAULT_OCCURS_TABLE_PREFIX	=> 'm_'
};

sub trigger_at_start_node {
	my ($self,%params)=@_;
	my $parent_table=$self->_get_parent_table;
	my $path=$parent_table->get_path;
	my ($maxoccurs,$minoccurs)=(
		$self->_resolve_maxOccurs
		,$self->_resolve_minOccurs(CHOICE => $parent_table->get_attrs_value qw(CHOICE))
	);
	if ($maxoccurs > 1) {
		my $schema=$self->get_attrs_value qw(STACK)->[1];
		my $table = $self->get_attrs_value qw(TABLE_CLASS)->new(
			NAME			=> DEFAULT_OCCURS_TABLE_PREFIX.$parent_table->get_attrs_value(qw(NAME))
			,MAXOCCURS		=> $maxoccurs
			,PARENT_PATH	=> $path
			,CHOICE			=> 1
		);
		
		$schema->set_table_names($table);

		$table->_add_columns(
			$schema->get_attrs_value qw(ANONYMOUS_COLUMN)->_factory_column(qw(ID))
			,$schema->get_attrs_value qw(ANONYMOUS_COLUMN)->_factory_column(qw(SEQ))
		);
		$parent_table->_add_child_tables($table);
		my $isparent_choice=$parent_table->get_attrs_value qw(CHOICE);

		my $column =  $self->get_attrs_value qw(COLUMN_CLASS)->new (	 #hook the column to the parent table 
			NAME				=> $table->get_attrs_value qw(NAME)
			,TYPE				=> $schema->get_attrs_value qw(ID_SQL_TYPE)
			,MINOCCURS			=> 0
			,MAXOCCURS			=> 1
			,PATH_REFERENCE		=> $table->get_path
			,TABLE_REFERENCE	=> $table
			,CHOICE				=> $isparent_choice
			,ELEMENT_FORM 		=> $self->_resolve_form
		);

		if (defined $parent_table->get_xsd_seq) {	   #the table is a sequence or a choice 
			$column->set_attrs_value(XSD_SEQ => $parent_table->get_xsd_seq); 
			$parent_table->_inc_xsd_seq unless $isparent_choice;
		}
		$parent_table->_add_columns($column);
		$self->set_attrs_value(TABLE => $table);
	}
	else {
		$parent_table->set_attrs_value(CHOICE => 1);
		$parent_table->set_attrs_value(XSD_SEQ => 0) unless defined $parent_table->get_xsd_seq; 
		$self->set_attrs_value(TABLE => $parent_table);
	}
}

sub trigger_at_end_node {
	my ($self,%params)=@_;
	my $parent_table=$self->get_attrs_value qw(STACK)->[-1]->get_attrs_value qw(TABLE);
	$parent_table->_inc_xsd_seq;  
	return $self;
}


1;



__END__


=head1  NAME

blx::xsdsql::xsd_parser::node::choice - internal class for parsing schema 

=cut
