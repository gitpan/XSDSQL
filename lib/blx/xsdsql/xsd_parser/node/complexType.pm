package blx::xsdsql::xsd_parser::node::complexType;
use base(qw(blx::xsdsql::xsd_parser::node));
use strict;
use warnings;
use integer;
use Carp;
use POSIX;
use Data::Dumper;
use blx::xsdsql::ut(qw(nvl));
use blx::xsdsql::xml::generic::table qw(:overload);
use blx::xsdsql::xsd_parser::type;
use blx::xsdsql::xsd_parser::type::complex;
use blx::xsdsql::xsd_parser::type::simple_content;
use blx::xsdsql::xsd_parser::type::simple;

sub trigger_at_start_node {
	my ($self,%params)=@_;
	my $parent=$self->{STACK}->[-1];
	my $parent_table=$parent->get_attrs_value(qw(TABLE));
	if (defined (my $name=$self->get_attrs_value(qw(name)))) {
		my $schema=$self->get_attrs_value(qw(STACK))->[1];
		my $path=$self->_construct_path($name,PARENT => $parent);
		my $table = $self->get_attrs_value(qw(TABLE_CLASS))->new (
			PATH			=> $self->_construct_path($name,PARENT => $parent)
			,XSD_TYPE		=> XSD_TYPE_COMPLEX
			,XSD_SEQ		=> 1
		);
		$schema->set_table_names($table);

		$table->_add_columns(
			$schema->get_attrs_value(qw(ANONYMOUS_COLUMN))->_factory_column(qw(ID))
			,$schema->get_attrs_value(qw(ANONYMOUS_COLUMN))->_factory_column(qw(SEQ))
		);
		$schema->add_types($self);
		$self->set_attrs_value(TABLE => $table);
	}
	else {
		$self->set_attrs_value(TABLE => $parent_table);
	}
	return $self;
}

sub factory_type {
	my ($self,$t,$types,%params)=@_;
	my ($schema,$debug)=($t->get_attrs_value(qw(STACK))->[1],$self->get_attrs_value(qw(DEBUG)));
	my $table=$t->get_attrs_value(qw(TABLE));
	if ($table->get_attrs_value(qw(XSD_TYPE) eq XSD_TYPE_SIMPLE_CONTENT)) {
		return blx::xsdsql::xsd_parser::type::simple_content->_new(NAME => $t,SCHEMA => $schema,DEBUG => $debug);
	}
	my $out={};
	$self->_resolve_simple_type($t,$types,$out,%params,SCHEMA => $schema);
	if (defined (my $base=$out->{base})) {  #is simpleContent
		my $ty_obj=blx::xsdsql::xsd_parser::type::simple->_new(NAME => $out,DEBUG => $debug);
		my $value_col=$schema->get_attrs_value(qw(ANONYMOUS_COLUMN))->_factory_column(qw(VALUE))->set_attrs_value(TYPE => $ty_obj);
		$table->_add_columns($value_col);
		$table->set_attrs_value(XSD_TYPE => XSD_TYPE_SIMPLE_CONTENT);	
		return blx::xsdsql::xsd_parser::type::simple_content->_new(NAME => $t,SCHEMA => $schema,DEBUG => $debug);
	}
	return blx::xsdsql::xsd_parser::type::complex->_new(NAME => $t,SCHEMA => $schema,DEBUG => $debug);
}

1;

__END__


=head1  NAME

blx::xsdsql::xsd_parser::node::complexType - internal class for parsing schema 

=cut
