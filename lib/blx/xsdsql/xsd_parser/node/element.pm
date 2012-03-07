package blx::xsdsql::xsd_parser::node::element;
use base qw(blx::xsdsql::xsd_parser::node);
use strict;
use warnings;
use integer;
use Carp;
use File::Basename;
use blx::xsdsql::ut qw(nvl);
use blx::xsdsql::xsd_parser::type;


sub trigger_at_start_node {
	my ($self,%params)=@_;
	my $parent_table=$self->_get_parent_table;
	my $isparent_choice=$parent_table->get_attrs_value qw(CHOICE);
	my ($maxoccurs,$minoccurs) = ($self->_resolve_maxOccurs,$self->_resolve_minOccurs(CHOICE => $isparent_choice)); 

	if (defined (my $name=$self->get_attrs_value qw(name))) {
		my $path=$self->_construct_path($name,%params,PARENT => undef);
		if (defined (my $xsd_type=$self->get_attrs_value qw(type))) {
			my ($schema,$debug)=($self->get_attrs_value qw(STACK)->[1],$self->get_attrs_value qw(DEBUG));
			my $ty_obj=blx::xsdsql::xsd_parser::type::factory(
					$xsd_type
					,SCHEMA => $schema
					,DEBUG => $debug
			);
			if ($maxoccurs > 1  && ref($ty_obj)=~/::simple$/) {
				$self->_debug(__LINE__,$xsd_type,': simple type with maxOccurs > 1');
				my $column =  $self->get_attrs_value qw(COLUMN_CLASS)->new(
					PATH					=> $path
					,TYPE					=> $schema->get_attrs_value qw(ID_SQL_TYPE)
					,MINOCCURS				=> $minoccurs
					,MAXOCCURS				=> $maxoccurs
					,INTERNAL_REFERENCE 	=> 1
					,CHOICE					=> $isparent_choice
					,ELEMENT_FORM 			=> $self->_resolve_form
				);
				if (defined $parent_table->get_xsd_seq) {	   #the table is a sequence or choice
					$column->set_attrs_value(XSD_SEQ => $parent_table->get_xsd_seq); 
					$parent_table->_inc_xsd_seq unless $isparent_choice; #the columns of a choice have the same xsd_seq
				}
				$parent_table->_add_columns($column);
				my $table=$self->get_attrs_value qw(TABLE_CLASS)->new(
					PATH		    		=> $path
					,INTERNAL_REFERENCE 	=> 1
				);
				$schema->set_table_names($table);
				$table->_add_columns(
					$schema->get_attrs_value qw(ANONYMOUS_COLUMN)->_factory_column(qw(ID))
					,$schema->get_attrs_value qw(ANONYMOUS_COLUMN)->_factory_column(qw(SEQ))
				);
				my $value_col=$schema->get_attrs_value qw(ANONYMOUS_COLUMN)->_factory_column(qw(VALUE));
				$value_col->set_attrs_value(TYPE => $ty_obj,PATH => $path,CHOICE => $isparent_choice);
				$table->_add_columns($value_col);
				$column->set_attrs_value(TABLE_REFERENCE => $table,PATH_REFERENCE => $table->get_path);
				$parent_table->_add_child_tables($table);
				$self->set_attrs_value(TABLE => $table);
			}
			else {
				$self->_debug(__LINE__,$path,': type with maxOccurs <= 1');
				my $column = $self->get_attrs_value qw(COLUMN_CLASS)->new(
					PATH					=> $path
					,TYPE					=> $ty_obj
					,MINOCCURS				=> $minoccurs
					,MAXOCCURS				=> $maxoccurs
					,CHOICE 				=> $isparent_choice
					,ELEMENT_FORM 			=> $self->_resolve_form
				);
				if (defined $parent_table->get_xsd_seq) {	   #the table is a sequence or choice
					$column->set_attrs_value(XSD_SEQ => $parent_table->get_xsd_seq); 
					$parent_table->_inc_xsd_seq unless $isparent_choice; #the columns of a choice have the same xsd_seq
				}
				$parent_table->_add_columns($column);
			}
		}
		else {   #anonymous type - converted into a table
			$self->_debug(__LINE__,$path,': anonymous type - converted into table');
			my $schema=$self->get_attrs_value qw(STACK)->[1];
			my $table = $self->get_attrs_value qw(TABLE_CLASS)->new(
					PATH				=> $path
					,ANONYMOUS_TYPE		=> 1 
			);
			$schema->set_table_names($table);
			my $maxocc=nvl($params{MAXOCCURS},1);
			$table->set_attrs_value(MAXOCCURS => $maxocc) 	if $maxocc > 1;
			$table->set_attrs_value(MAXOCCURS => $maxoccurs) 	if $maxoccurs > 1;
			$table->_add_columns($schema->get_attrs_value qw(ANONYMOUS_COLUMN)->_factory_column(qw(ID)));
			$parent_table->_add_child_tables($table);

			my $column = $schema->get_attrs_value qw(COLUMN_CLASS)->new(	 #hoock to the parent the column 
					NAME				=> $name
					,PATH				=> undef
					,TYPE				=> $schema->get_attrs_value qw(ID_SQL_TYPE)
					,MINOCCURS			=> $minoccurs
					,MAXOCCURS			=> $maxoccurs
					,PATH_REFERENCE		=> $path
					,TABLE_REFERENCE 	=> $table
					,CHOICE				=> $isparent_choice
					,ELEMENT_FORM 		=> $self->_resolve_form
				);
			if (defined $parent_table->get_xsd_seq) {	   #the table is a xs:sequence or a xs:choice 
				$column->set_attrs_value(XSD_SEQ => $parent_table->get_xsd_seq); 
				$parent_table->_inc_xsd_seq unless $isparent_choice; 
			}	
			$parent_table->_add_columns($column);
			my $cols=$parent_table->get_columns;
			my $child_tables=$parent_table->get_child_tables;
			$self->set_attrs_value(
				TABLE 			=> $table
				,TABLE_INDEX 	=> scalar(@$child_tables) - 1
				,PARENT_TABLE 	=> $parent_table
				,COLUMN_INDEX   => scalar(@$cols) - 1
			);
		}
	}
	elsif (defined (my $ref=$self->get_attrs_value qw(ref))) {
		$self->_debug(__LINE__,$ref,': element without name and with ref');
		my $path=$self->_construct_path($ref,%params,PARENT => undef);
		my $schema=$self->get_attrs_value qw(STACK)->[1];
		my $column = $schema->get_attrs_value qw(COLUMN_CLASS)->new(
			REF					=> 1
			,PATH				=> $path
			,MINOCCURS			=> $minoccurs
			,MAXOCCURS			=> $maxoccurs
			,CHOICE 			=> $isparent_choice
			,ELEMENT_FORM 		=> $self->_resolve_form
		);
		if (defined $parent_table->get_xsd_seq) {	   #the table is a sequence or choice
			$column->set_attrs_value(XSD_SEQ => $parent_table->get_xsd_seq); 
			$parent_table->_inc_xsd_seq unless  $isparent_choice; #the columns of a choice have the same xsd_seq
		}
		$parent_table->_add_columns($column);
		$self->set_attrs_value(TABLE => $parent_table);
	}
	else {
		$self->_debug(__LINE__,Dumper($self));
		confess "node without name or ref is not supported\n";
	}

	return $self;
}


sub _get_type {
	my ($self,%params)=@_;
	my $childs=delete $params{CHILD};
	$childs=$self->get_attrs_value qw(CHILD) unless defined $childs;
	confess "CHILD not set\n" unless defined $childs;
	confess "CHILD not array\n" unless ref($childs) eq 'ARRAY';
	confess "not CHILDS element\n" if scalar(@$childs)==0;
	confess "multiply CHILDS element\n" if scalar(@$childs) > 1;
	my $child=$childs->[0];
	my $out={};
	my ($schema,$debug)=($self->get_attrs_value qw(STACK)->[1],$self->get_attrs_value qw(DEBUG));
	$self->_resolve_simple_type($child,undef,$out,%params,SCHEMA => $schema);
	my $ty_obj=ref($out->{base}) eq '' 
			? blx::xsdsql::xsd_parser::type::simple->_new(NAME => $out,SCHEMA => $schema,DEBUG => $debug) 
			: $out->{base};
	return $ty_obj;
}

sub _get_last_node_column { 
	my ($self,$table,%params)=@_;
	my @cols=$table->get_columns;
	my $col=undef;
	while (1) {
		$col=pop @cols;
		last unless defined $col;
		last unless $col->is_sys_attributes or $col->is_attribute or $col->is_pk;
	}	
	return $col;
}

sub trigger_at_end_node {
	my ($self,%params)=@_;
	my $table=$self->get_attrs_value qw(TABLE);

	if (defined $table && $table->get_attrs_value qw(ANONYMOUS_TYPE)) {
		if (defined (my $childs=$self->get_attrs_value qw(CHILD))) {
			my $parent_table=$self->get_attrs_value qw(PARENT_TABLE);
			my $col=$self->_get_last_node_column($parent_table);
			confess "link column not found for table ".$table->get_sql_name."\n" unless defined $col;
			my ($schema,$debug)=($self->get_attrs_value qw(STACK)->[1],$self->get_attrs_value qw(DEBUG));
			my $ty_obj=$self->_get_type(CHILD => $childs);
			if ($col->get_max_occurs <= 1) {
				$col->set_attrs_value(TYPE => $ty_obj,TABLE_REFERENCE => undef,PATH_REFERENCE => undef,PATH => $table->get_path);
				$parent_table->_delete_child_tables($self->get_attrs_value qw(TABLE_INDEX));
			}
			else {
				my $path=$table->get_path;
				$col->set_attrs_value(INTERNAL_REFERENCE => 1,PATH => $path);
				my $column = $schema->get_attrs_value qw(COLUMN_CLASS)->new(
					NAME			=> basename($path)
					,PATH			=> $path
					,CHOICE 		=> $table->is_choice
					,TYPE			=> $ty_obj
					,ELEMENT_FORM 	=> $self->_resolve_form
				);
				$table->set_attrs_value(INTERNAL_REFERENCE => 1);
				$table->_add_columns(
					$schema->get_attrs_value qw(ANONYMOUS_COLUMN)->_factory_column(qw(SEQ))
					,$column
				);
			}
		}
	}
	return $self;
}

1;


__END__


=head1  NAME

blx::xsdsql::xsd_parser::node::element - internal class for parsing schema 

=cut
