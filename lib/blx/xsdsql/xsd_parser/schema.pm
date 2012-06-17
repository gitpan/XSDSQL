package blx::xsdsql::xsd_parser::schema;

use strict;
use warnings;
use integer;
use Carp;

use base qw(blx::xsdsql::log blx::xsdsql::common_interfaces);

my %_ATTRS_R=(
	ID_SQL_TYPE	=> sub  { 
		my $h=Storable::dclone($_[0]->{ID_SQL_TYPE});
		return blx::xsdsql::xsd_parser::type::simple->_new(SQL_T_ => $h);
	}
);

my %_ATTRS_W=();


sub _get_attrs_w { return \%_ATTRS_W; }
sub _get_attrs_r { return \%_ATTRS_R; }


sub get_root_table {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(TABLE));
}

sub get_types_name {
	my ($self,%params)=@_;
	my $types=$self->get_attrs_value(qw(TYPE_NAMES));
	return undef unless defined $types;
	return wantarray ? %$types : $types;
}


sub get_dictionary_table {
	my ($self,$type,%params)=@_;
	croak "type (1^ param) not set" unless $type;
	return $self->get_attrs_value($type);
}

sub get_dictionary_data {
	my ($self,$dictionary_type,%params)=@_;
	croak "dictionary_type (1^ arg)  non defined" unless defined $dictionary_type;
	if ($dictionary_type eq 'SCHEMA_DICTIONARY') {
		my %data=map { ($_,$self->get_attrs_value($_)); } qw(URI element_form_default attribute_form_default); 
		return wantarray ? %data : \%data;
	}
	croak "$dictionary_type: invalid value";
}

sub get_sequence_name {
	my ($self,%params)=@_;
	my $t=$self->get_root_table;
	return undef unless $t;
	return $t->get_sequence_name(%params);
}



sub get_childs_schema {
	my ($self,%params)=@_;
	return  blx::xsdsql::xsd_parser::node::schema::get_childs_schema(@_);
}

sub resolve_attributes {
	my ($self,$table_name,@attrnames)=@_;
	return $self->{MAPPING_PATH}->resolve_attributes($table_name,@attrnames);
}

sub resolve_path {
	my ($self,$path,%params)=@_;
	return $self->{MAPPING_PATH}->resolve_path($path,%params);
}

sub resolve_column_link {
	my ($self,$t1,$t2,%params)=@_;
	return $self->{MAPPING_PATH}->resolve_column_link($t1,$t2,%params);
}



1;

__END__


=head1  NAME

blx::xsdsql::xsd_parser::schema -  a schema is a class with include the common objects and search methods 

=cut

=head1 SYNOPSIS

use blx::xsdsql::xsd_parser::schema

=cut


=head1 DESCRIPTION

this package is a class - is instanciated by package blx::xsdsql::xsd_parser


=head1 FUNCTIONS

this module defined the followed functions


set_attrs_value   - set a value of attributes

	the arguments are a pairs NAME => VALUE	
	the method return a self object



get_attrs_value  - return a list  of attributes values

	the arguments are a list of attributes name


get_types_name - return an hash of object types - the key are names



resolve_path - return the table and the column associated  to the the pathnode
				the method return an array ref if the path is associated to a tables
				otherwise return an hash if the path is associated to a column

	arguments
		absolute node path 
		
	params:
		DEBUG - emit debug info 
 

resolve_column_link - return the column link a tables 

	arguments
		parent table
		child table


resolve_attributes - return the attributes columns
	arguments
		table_name
		attribute name...


get_root_table - return the root table objects


get_dictionary_table - return  a dictionary object 
	the first argument is a constant  string TABLE_DICTIONARY|COLUMN_DICTIONARY|RELATION_DICTIONARY


get_sequence_name - return the sequence name associated to the root table






=head1 EXPORT

None by default.


=head1 EXPORT_OK

None


=head1 SEE ALSO

	blx::xsdsql::xsd_parser - parse an xsd file  

=head1 AUTHOR

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut





