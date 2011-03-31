package blx::xsdsql::schema;

use strict;
use warnings;
use Carp;
use Data::Dumper;

use blx::xsdsql::ut qw(nvl);
use blx::xsdsql::path_map;


sub _fusion_params {
	my ($self,%params)=@_;
	my %p=%$self;
	for my $p(keys %params) {
		$p{$p}=$params{$p};
	}
	return \%p;
}

our %_ATTRS_R=();
our %_ATTRS_W=(
	TYPES	=> sub {
		my ($self,$types)=@_;
		croak "types already set " if  $self->{TYPE_NAMES}; 
		croak "not an ARRAY" unless ref($types) eq 'ARRAY';
		my %type_names=map { ($_->get_attrs_value(qw(NAME)),$_) } grep(defined $_->get_attrs_value(qw(NAME)),@$types);
		my %type_paths=map { ($_->get_attrs_value(qw(PATH)),$_) } grep(defined $_->get_attrs_value(qw(PATH)),@$types);
		$self->{TYPE_NAMES}=\%type_names;
		$self->{TYPE_PATHS}=\%type_paths;
		return 1;
	}

);


sub new {
	my ($classname,%params)=@_;
	my $self=bless {},$classname;
	$self->set_attrs_value(%params);
	return $self;
}

sub set_attrs_value {
	my $self=shift;
	blx::xsdsql::ut::set_attrs_value($self,\%_ATTRS_W,@_);
	return $self;
}

sub get_attrs_value {
	my $self=shift;
	return blx::xsdsql::ut::get_attrs_value($self,\%_ATTRS_R,@_);
}

sub get_types_name {
	my ($self,%params)=@_;
	my $types=$self->{TYPE_NAMES};
	return undef unless defined $types;
	return wantarray ? %$types : $types;
}

sub get_types_path {
	my ($self,%params)=@_;
	my $types=$self->{TYPE_PATHS};
	return undef unless defined $types;
	return wantarray ? %$types : $types;
}	

sub resolve_path {
	my ($self,$path,%params)=@_;
	return $self->{MAPPING_PATH}->resolve_path($path,%params);
}


sub get_root_table { 
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(ROOT);
}

sub get_dictionary_table {
	my ($self,$type,%params)=@_;
	croak "type (1^ param) not set" unless $type;
	return $self->get_attrs_value($type);
}


sub get_sequence_name {
	my ($self,%params)=@_;
	my $t=$self->get_root_table;
	return undef unless $t;
	return $t->get_sequence_name(%params);
}


sub mapping_paths {
	my ($self,%params)=@_;
	croak "map already set" if $self->get_attrs_value qw(MAPPING_PATH);
	my $pr=$self->_fusion_params(%params);
	my $m=blx::xsdsql::path_map->new;
	my $root=$self->get_root_table;
	my $p=$self->get_types_path;
	$self->{MAPPING_PATH}=$m->mapping_paths($root,$p,%$pr);
	return $self;
}
	

1;

__END__

=head1  NAME

blx::xsdsql::schema -  a schema is a class with include the common objects and search methods 

=cut

=head1 SYNOPSIS

use blx::xsdsql::schema

=cut


=head1 DESCRIPTION

this package is a class - instance it with the method new


=head1 FUNCTIONS

this module defined the followed functions

new - constructor   
	standard params:
			TYPES - set an array of tables type
			TABLE_DICTIONARY - set/get the dictionary of the tables
			COLUMN_DICTIONARY - set/get the dictionary of the columns
			RELATION_DICTIONARY - set/get the dictionary of the relations
			ROOT - set/get  the root table
			SEQUENCE - set/get  the sequence object


set_attrs_value   - set a value of attributes

	the arguments are a pairs NAME => VALUE	
	the method return a self object



get_attrs_value  - return a list  of attributes values

	the arguments are a list of attributes name


get_types_name - return an hash of object types - the key are names


get_types_path - return an hash of object types - the key are node path


resolve_path - return the table and the column associated  to the the pathnode
				the method return an array ref if the path is associated to a tables
				otherwise return an hash if the path is associated to a column

	arguments
		absolute node path 
		
	params:
		DEBUG - emit debug info 
 

get_root_table - return the root table objects


get_dictionary_table - return  a dictionary object 
	the first argument is a constant  string TABLE_DICTIONARY|COLUMN_DICTIONARY|RELATION_DICTIONARY


get_sequence_name - return the sequence name associated to the root table


mapping_paths - mapping the all path node to tables and columns

	params:
		DEBUG - emit debug info 

	the method return the self object




=head1 EXPORT

None by default.


=head1 EXPORT_OK

None


=head1 SEE ALSO

	blx::xsdsql::path_map   - mapping a xml path to table/column 

=head1 AUTHOR

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut


