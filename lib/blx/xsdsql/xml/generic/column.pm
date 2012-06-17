package blx::xsdsql::xml::generic::column;

use strict;
use warnings;
use integer;
use Carp;
use blx::xsdsql::ut(qw(nvl));
use File::Basename;
use Storable;

use blx::xsdsql::xml::generic::table qw(:overload);
use base(qw(blx::xsdsql::xml::generic::catalog blx::xsdsql::xml::generic::name_generator));


our %_ATTRS_R=( 
			NAME   				=> sub { 
											my $self=$_[0]; 	
											my ($n,$p)=map { $self->{$_} }(qw(NAME PATH)); 
											return $self->{ATTRIBUTE} || !defined  $p ? $n : basename($p); 
			} 			
			,MAXOCCURS 			=> sub {	my $m=$_[0]->{MAXOCCURS}; return nvl($m,1); }
			,MINOCCURS 			=> sub {	my $m=$_[0]->{MINOCCURS}; return nvl($m,1); }
			,INTERNAL_REFERENCE => sub { 	return $_[0]->{INTERNAL_REFERENCE} ? 1 : 0; }
			,SQL_TYPE  			=> sub {	return $_[0]->get_sql_type; }
			,PK					=> sub { 	return defined $_[0]->{PK_SEQ}  ? 1 : 0; }
			,GROUP_REF			=> sub {	return $_[0]->{GROUP_REF} ? 1 : 0; }
			,CHOICE				=> sub {	return $_[0]->{CHOICE} ? 1 : 0; }
			,ATTRIBUTE			=> sub {	return $_[0]->{ATTRIBUTE} ? 1 : 0; }
			,SYS_ATTRIBUTES		=> sub {	return $_[0]->{SYS_ATTRIBUTES} ? 1 : 0; }
);

our %_ATTRS_W=();


sub _new {
	my ($class,%params)=@_;
	$params{XSD_SEQ}=0 unless defined $params{XSD_SEQ}; 
	return $class->SUPER::_new(%params);
}

sub _get_default_predef_colum {
	my ($self,$type,%params)=@_;
	confess "abstract method\n";
}

sub _get_default_sql_column  {
	my ($self,$type,%params)=@_;
	return { NAME	=> 'ID',TYPE 	=> $self->_get_default_predef_colum(qw(ID)),MINOCCURS => 1,MAXOCCURS => 1, PK_SEQ => 0 } if $type eq 'ID';
	return { NAME	=> 'SEQ',TYPE	=> $self->_get_default_predef_colum(qw(SEQ)),MINOCCURS => 1,MAXOCCURS => 1,PK_SEQ => 1 } if $type eq 'SEQ';
	return { NAME	=> 'VALUE',TYPE	=> $self->_get_default_predef_colum(qw(VALUE)),MINOCCURS => 1,MAXOCCURS => 1,VALUE_COL => 1   } if $type eq 'VALUE';
	confess "$type: not valid\n";
}

sub _translate_type {
	my ($self,$type,%params)=@_;
	confess "internal error - type not set for colum ".nvl($self->get_sql_name,$self->get_path)."\n" unless defined $type;
	my $t=$self->_get_translate_type_table->{$type};
	return $type if !defined $t && $params{IGNORE_IF_NOTEXIST};
	confess "$type - internal error - not defined into translate type table\n" unless defined $t;
	return $t;
}

sub _get_hash_sql_types {
	my  ($self,%params)=@_;
	confess "abastract method\n";
}

sub _get_sql_size {
	my ($self,%params)=@_;
	return $self->{TYPE}->{SQL_SIZE} if defined $self->{TYPE}->{SQL_SIZE};
	my $hashvalues=$self->_get_hash_sql_types(%params);
	my $v=$hashvalues->{uc($self->{TYPE}->{SQL_TYPE})};
	return undef unless defined $v;
	return $v->($self,%params) if ref($v) eq 'CODE';
	return $v if ref($v) eq  '';
	confess  Dumper($v).": internal error - not implemented";
}


sub _translate_path  {
	my ($self,%params)=@_;	
	my $path=defined $params{NAME} ? $params{NAME} : $params{PATH};
	confess "attribute NAME or PATH not set\n"  unless defined $path;
	$path=basename($path);
	$path=~s/^_//;
	$path=~s/-/_/g;
	$path=~s/:/_/g;
	return $path;
}

sub _resolve_invalid_name {
	my ($self,$name,%params)=@_;
	confess "abstract method\n";
	return $name;
}

sub _reduce_sql_name {
	my ($self,$name,$maxsize,%params)=@_;
	my @s=split('_',$name);
	if (scalar(@s) > 1) {
		for my $s(@s) {
			$s=~s/([A-Z])[a-z0-9]+/$1/g;
			my $t=join('_',@s);
			return $t if  length($t) <= $maxsize;
		}
	}
	return substr(join('_',@s),0,$maxsize);
}


sub _factory_sql_type {
	confess "abstract method\n";
}



sub _set_sql_name {
	my ($self,%params)=@_;
	my $name=$self->_gen_name(
				TY 		=> 'c'
				,LIST 	=> $params{COLUMNNAME_LIST}
				,NAME 	=> $self->get_attrs_value(qw(NAME))
				,PATH	=> $self->get_attrs_value(qw(PATH))
	);
	return $self->{SQL_NAME}=$name;
}

sub _factory_column {
	my ($self,$type,%params)=@_;
	if (defined $type) {
		my $h=$self->_get_default_sql_column($type);
		return bless(Storable::dclone($h),ref($self));
	}

	$params{TYPE}={ # contruct sql_type for dictionary column
			SQL_TYPE => $self->_factory_sql_type(delete $params{SQL_TYPE})
			,SQL_SIZE => delete $params{SQL_SIZE} 
	};	
	return bless \%params,ref($self); 
}


sub _factory_dictionary_columns {
	my ($self,$dictionary_type,%params)=@_;
	my $c=$self;
	croak "dictionary type not defined" unless defined $dictionary_type;
	my @cols=$dictionary_type eq 'SCHEMA_DICTIONARY' ?
		(
			$c->_factory_column(undef,NAME => 'URI',SQL_TYPE	=> 'VARCHAR',PK_SEQ => 0) 
			,$c->_factory_column(undef,NAME => 'element_form_default',SQL_TYPE	=> 'CHAR',SQL_SIZE => 1,ENUM_RESTRICTIONS => { Q => 'qualified' },COMMENT => 'values: Q is qualified - null is unqualified (the default)')
			,$c->_factory_column(undef,NAME => 'attribute_form_default',SQL_TYPE	=> 'CHAR',SQL_SIZE => 1,ENUM_RESTRICTIONS => { Q => 'qualified' },COMMENT => 'values: Q is qualified - null is unqualified (the default)')
		)
		: $dictionary_type eq 'TABLE_DICTIONARY' 
		? (
			$c->_factory_column(undef,NAME => 'table_name',SQL_TYPE	=> 'VARCHAR',SQL_SIZE => $c->get_name_maxsize,PK_SEQ => 0) 
			,$c->_factory_column(undef,NAME => 'URI',SQL_TYPE	=> 'VARCHAR',COMMENT => 'null is no namespace definition') 
			,$c->_factory_column(qw(SEQ))->set_attrs_value(NAME => 'xsd_seq',COMMENT => 'xsd sequence start',PK_SEQ => undef)
			,$c->_factory_column(qw(SEQ))->set_attrs_value(NAME => 'min_occurs',PK_SEQ => undef)
			,$c->_factory_column(qw(SEQ))->set_attrs_value(NAME => 'max_occurs',PK_SEQ => undef)
			,$c->_factory_column(undef,NAME => 'path_name',SQL_TYPE	=> 'VARCHAR')
			,$c->_factory_column(qw(SEQ))->set_attrs_value(NAME => 'deep_level',COMMENT => 'the root has level 0',PK_SEQ => undef)
			,$c->_factory_column(undef,NAME => 'parent_path',SQL_TYPE	=> 'VARCHAR',COMMENT => 'path of the parent table if the table is unpathed')
			,$c->_factory_column(undef,NAME => 'is_root_table',SQL_TYPE	=> 'CHAR',SQL_SIZE => 1,ENUM_RESTRICTIONS => { Y => 'is the root table' },COMMENT => 'values: Y - the table is the root table')
			,$c->_factory_column(undef,NAME => 'is_unpath',SQL_TYPE	=> 'CHAR',SQL_SIZE => 1,ENUM_RESTRICTIONS => { Y => 'is an unpath table' },COMMENT => 'values: Y - the table has not an associated path')
			,$c->_factory_column(undef,NAME => 'is_internal_ref',SQL_TYPE	=> 'CHAR',SQL_SIZE => 1,ENUM_RESTRICTIONS => { Y => 'is an occurs of simple type' },COMMENT => 'values: Y - the table is an occurs of simple type')
			,$c->_factory_column(undef,NAME => 'view_name',SQL_TYPE	=> 'VARCHAR',SQL_SIZE => $c->get_name_maxsize,PK_SEQ => 0,COMMENT => 'the view name associated to the table')
			,$c->_factory_column(undef,NAME => 'xsd_type',SQL_TYPE	=> 'VARCHAR',SQL_SIZE => 5,ENUM_RESTRICTIONS => { &XSD_TYPE_COMPLEX => 'complex type',&XSD_TYPE_SIMPLE => 'simple_type',&XSD_TYPE_GROUP => 'group_type',&XSD_TYPE_SIMPLE_CONTENT => 'simple content' },COMMENT => 'xsd node type')
			,$c->_factory_column(undef,NAME => 'is_group_type',SQL_TYPE	=> 'CHAR',SQL_SIZE => 1,ENUM_RESTRICTIONS => { Y => 'is a group' },COMMENT => 'values: Y - the table is a group type')
			,$c->_factory_column(undef,NAME => 'is_complex_type',SQL_TYPE	=> 'CHAR',SQL_SIZE => 1,ENUM_RESTRICTIONS => { Y => 'is a complex' },COMMENT => 'values: Y - the table is a complex type')
			,$c->_factory_column(undef,NAME => 'is_simple_type',SQL_TYPE	=> 'CHAR',SQL_SIZE => 1,ENUM_RESTRICTIONS => { Y => 'is a simple type' },COMMENT => 'values: Y - the table is a simple_type')
			,$c->_factory_column(undef,NAME => 'is_simple_content_type',SQL_TYPE	=> 'CHAR',SQL_SIZE => 1,ENUM_RESTRICTIONS => { Y => 'is a simple content type' },COMMENT => 'values: Y - the table is a simple content type')

		)
		: $dictionary_type eq 'COLUMN_DICTIONARY' 
		? (
			$c->_factory_column(undef,NAME => 'table_name',SQL_TYPE	=> 'VARCHAR',SQL_SIZE => $c->get_name_maxsize,PK_SEQ => 0) 
			,$c->_factory_column(qw(SEQ))->set_attrs_value(NAME => 'column_seq',COMMENT => 'a column sequence into the table',PK_SEQ => 1)
			,$c->_factory_column(undef,NAME => 'column_name',SQL_TYPE	=> 'VARCHAR',SQL_SIZE => $c->get_name_maxsize) 
			,$c->_factory_column(undef,NAME => 'path_name',SQL_TYPE	=> 'VARCHAR') 
			,$c->_factory_column(qw(SEQ))->set_attrs_value(NAME => 'xsd_seq',COMMENT => 'xsd sequence into a choice',PK_SEQ => undef)
			,$c->_factory_column(undef,NAME => 'path_name_ref',SQL_TYPE	=> 'VARCHAR',COMMENT => 'the column reference a table') 
			,$c->_factory_column(undef,NAME => 'table_name_ref',SQL_TYPE	=> 'VARCHAR',SQL_SIZE => $c->get_name_maxsize,COMMENT => 'the column reference a table') 
			,$c->_factory_column(undef,NAME => 'is_internal_ref',SQL_TYPE	=> 'CHAR',SQL_SIZE => 1,ENUM_RESTRICTIONS => { Y => 'has internal_reference' },COMMENT => 'values: Y - the column is an array of simple_type')
			,$c->_factory_column(undef,NAME => 'is_group_ref',SQL_TYPE	=> 'CHAR',SQL_SIZE => 1,ENUM_RESTRICTIONS => { Y => 'group reference' },COMMENT => 'values: Y - the column reference a group')
			,$c->_factory_column(qw(SEQ))->set_attrs_value(NAME => 'min_occurs',COMMENT => 'the ref table has this min_occurs or the column has internal reference',PK_SEQ => undef)
			,$c->_factory_column(qw(SEQ))->set_attrs_value(NAME => 'max_occurs',COMMENT => 'the ref table has this max_occurs or the column has internal reference',PK_SEQ => undef )
			,$c->_factory_column(qw(SEQ))->set_attrs_value(NAME => 'pk_seq',COMMENT => 'the column is part of the primary key - this is the sequence number',PK_SEQ => undef )
			,$c->_factory_column(undef,NAME => 'is_choice',SQL_TYPE	=> 'CHAR',SQL_SIZE => 1,ENUM_RESTRICTIONS => { Y => ' is part of a choice' },COMMENT => 'values: Y - the column is part of a choice')
			,$c->_factory_column(undef,NAME => 'is_attribute',SQL_TYPE	=> 'CHAR',SQL_SIZE => 1,ENUM_RESTRICTIONS => { Y => ' is an attribute' },COMMENT => 'values: Y - the column is an attribute')
			,$c->_factory_column(undef,NAME => 'is_sys_attributes',SQL_TYPE	=> 'CHAR',SQL_SIZE => 1,ENUM_RESTRICTIONS => { Y => ' contain system attributes' },COMMENT => 'values: Y - the column contains  system attributes')
			,$c->_factory_column(undef,NAME => 'element_form',SQL_TYPE	=> 'CHAR',SQL_SIZE => 1,ENUM_RESTRICTIONS => { Q => ' qualified',U => ' unqualified' },COMMENT => 'values: Q(qualified)|(U)nqualified')
		)
		: $dictionary_type eq 'RELATION_DICTIONARY' 
		? (
			$c->_factory_column(undef,NAME => 'parent_table_name',SQL_TYPE	=> 'VARCHAR',SQL_SIZE => $c->get_name_maxsize,PK_SEQ => 0) 
			,$c->_factory_column(qw(SEQ))->set_attrs_value(NAME => 'child_sequence',PK_SEQ => 1)
			,$c->_factory_column(undef,NAME => 'child_table_name',SQL_TYPE	=> 'VARCHAR',SQL_SIZE => $c->get_name_maxsize) 
		)
		: croak "$dictionary_type: invalid value for dictionary_type";
	my %cl=();
	for my $col(@cols) { #generate sql names
		$col->_set_sql_name(COLUMNNAME_LIST => \%cl);
	}
	return wantarray ? @cols : \@cols;
}

sub get_sql_type {
	my ($self,%params)=@_;
	return $self->{SQL_TYPE} if defined $self->{SQL_TYPE};
	if ($self->get_attrs_value(qw(DEBUG))) {
		if ((my $r=ref($self->{TYPE}))  ne 'HASH') {
			unless ($r =~/simple/i) {
				$self->_debug(__LINE__," not hash ref but '$r' - column ",$self->get_full_name,' - type is ',$self->{TYPE}); 
				confess "internal error\n";
			}
		}
	}
	if (ref($self->{TYPE})=~/xsd_parser::type::simple$/) {
		my $ty=$self->{TYPE}->get_sql_type;
		my $sql_type=$self->_translate_type($ty->{SQL_TYPE},NORINCHI => 1);
		$sql_type=$self->_translate_type($sql_type->{REF},NORINCHI => 1) if ref($sql_type) eq 'HASH' && $sql_type->{REF};
		confess "internal error - loop in translate not implemented\n" 
			if ref($sql_type) eq 'HASH' && $sql_type->{REF};			
		if (defined (my $sz=$ty->{SQL_SIZE})) {
			$sql_type=~s/\(\d+\)$//;
			$sql_type.='('.$sz.')';
		}
		$self->{SQL_TYPE}=$sql_type;
	}
	else {
		my $sql_type=$self->_translate_type($self->{TYPE}->{SQL_TYPE},NORINCHI => 1,IGNORE_IF_NOTEXIST => 1);
		if (defined (my $sz=$self->_get_sql_size(%params))) {
			$sql_type=~s/\(\d+\)$//;
			$sql_type.='('.$sz.')';
		}
		$self->{SQL_TYPE}=$sql_type;
	}
	return $self->{SQL_TYPE};
}

sub get_column_sequence {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(COLUMN_SEQUENCE));
}

sub get_name { 	
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(NAME));
}

sub get_sql_name {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(SQL_NAME));
}

sub is_internal_reference {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(INTERNAL_REFERENCE));
}

sub is_group_reference {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(GROUP_REF));	
}

sub is_choice {
	my ($self,%params)=@_;
	return  $self->get_attrs_value(qw(CHOICE));
}

sub is_attribute {
	my ($self,%params)=@_;
	return  $self->get_attrs_value(qw(ATTRIBUTE));
}

sub is_sys_attributes {
	my ($self,%params)=@_;
	return  $self->get_attrs_value(qw(SYS_ATTRIBUTES));
}

sub get_min_occurs {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(MINOCCURS));
}

sub get_max_occurs {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(MAXOCCURS));
}

sub is_pk {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(PK));
}

sub get_pk_seq {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(PK_SEQ));
}

sub get_xsd_seq {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(XSD_SEQ));
}

sub get_path {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(PATH));
}

sub get_path_reference {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(PATH_REFERENCE));
}

sub get_table_name {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(TABLE_NAME));
}

sub get_full_name {
	my ($self,%params)=@_;
	return $self->get_table_name.'.'.$self->get_sql_name;
}

sub get_table_reference {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(TABLE_REFERENCE));	
}


sub get_element_form {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(ELEMENT_FORM));
}

sub get_dictionary_data {
	my ($self,$dictionary_type,%params)=@_;
	croak "dictionary type not defined" unless defined $dictionary_type;
	if ($dictionary_type eq 'COLUMN_DICTIONARY') {
		my $table_ref=$self->get_table_reference;
		my $path_ref=$self->get_path_reference;
		$path_ref=$path_ref->get_sql_name if ref($path_ref) ne '';
		my %data=(
			column_seq  		=> $self->get_column_sequence
			,column_name		=> $self->get_sql_name
			,path_name			=> $self->get_attrs_value(qw(PATH))
			,xsd_seq			=> $self->get_xsd_seq
			,path_name_ref		=> $path_ref
			,table_name_ref		=> ($table_ref ? $table_ref->get_sql_name : undef)
			,is_internal_ref	=> ($self->is_internal_reference ? 'Y' : undef)
			,is_group_ref		=> ($self->is_group_reference ? 'Y' : undef)
			,min_occurs			=> $self->get_min_occurs
			,max_occurs			=> $self->get_max_occurs
			,pk_seq				=> $self->get_pk_seq
			,is_choice			=> ($self->is_choice ? 'Y' : undef)
			,is_attribute		=> ($self->is_attribute ? 'Y' : undef)
			,is_sys_attributes  => ($self->is_sys_attributes ? 'Y' : undef)
			,element_form		=> $self->get_element_form
		);	
		return wantarray ? %data : \%data;
	}
	croak "$dictionary_type: invalid value for dictionary_type";	
}

1;


__END__


=head1  NAME

blx::xsdsql::xml::generic::column -  a generic colum class 

=cut

=head1 SYNOPSIS

use blx::xsdsql::xml::generic::column

=cut


=head1 DESCRIPTION

this package is a class - instance it with the method new


=head1 FUNCTIONS

this module defined the followed functions

new - constructor   

	PARAMS:
		COLUMN_SEQUENCE - a sequence number into the table - the first column has sequence 0
		XSD_SEQ  - a sequence number into xsd 
		MIN_OCCURS - default 1 
		MAX_OCCURS - default 1
		NAME  - a basename of xml node
		PATH 	- a path name of xml xml node
		PATH_REFERENCE - the referenced by column 
		TABLE_REFERENCE	- the table referenced by column
		INTERNAL_REFERENCE - true if the column is an array of simple types
		PK_SEQ  - sequence position number into the primary key 
		GROUP_REF - true if the column reference a group
		TABLE_NAME - the table name of the column
		CHOICE	- if true the column is part of a choice
		ATTRIBUTE	- if true the column  is an attribute
		SYS_ATTRIBUTES - if true the column contain system attributes
		ELEMENT_FORM - the value of form attribute (Q)ualified|(U)nqualified

set_attrs_value   - set a value of attributes

	the arguments are a pairs NAME => VALUE
	the method return a self object


get_attrs_value  - return a list  of attributes values

	the arguments are a list of attributes name


get_column_sequence - return the sequence into the table - the first column has sequence 0


get_sql_type  - return the sql type of the column


get_sql_name  - return the  sql name of the column

	PARAMS: 
		COLUMNNAME_LIST - hash of sql columns name 
			this param is mandatory if the column sql name must be set
		FORCE - force the set of column	sql name


get_min_occurs - return the value of the minoccurs into the xsd schema


get_max_occurs - return the value of the maxoccurs into the xsd schema


is_internal_reference  - return true if the column is an array of simple types   


is_group_reference - return true if the column reference a xsd group


is_choice  - return true if the column is a part of a choice 


is_attribute - return true if the column is an attribute


is_sys_attributes - return true if then column contain system attributes in the form name="value"[,..]


get_path - return the node path name


get_path_reference - return the path referenced 


get_table_reference - return the table referenced 


get_table_name - return the table name of the column


is_pk  - return true if the column is part of the primary key


get_pk_seq - return the sequence into the primary key


get_xsd_seq - return a sequence number into a choice


get_element_form - return the value of form attribute (Q)ualified|(U)nqualified


get_dictionary_data - return an hash of dictionary column name => value for the insert into dictionary

	the first argument must be:
		COLUMN_DICTIONARY - return data for column dictionary (except TABLE_NAME)
				

		 
=head1 EXPORT

None by default.


=head1 EXPORT_OK
	
none 

=head1 SEE ALSO

See blx::xsdsql::xml::generic::catalog, it's the base class
See blx:.xsdsql::generator for generate the schema of the database and blx::xsdsql::parser 
for parse a xsd file (schema file)


=head1 AUTHOR

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIG 

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
