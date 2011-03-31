package blx::xsdsql::xml::generic::column;

use strict;
use warnings;
use integer;
use Carp;
use blx::xsdsql::ut qw(nvl);
use File::Basename;
use Storable;

use base qw(blx::xsdsql::xml::generic::catalog);

use constant {
			DEFAULT_SQL_VARCHAR             =>  'varchar'
			,DEFAULT_SQL_CHAR				=> 'char'
			,DEFAULT_SQL_NUMBER				=> 'number'
			,DEFAULT_SQL_DOUBLE				=> 'double'
			,DEFAULT_SQL_FLOAT             	=> 'float'
			,DEFAULT_SQL_DECIMAL         	=> 'decimal'
			,DEFAULT_SQL_DATETIME       	=> 'datetime'
			,DEFAULT_SQL_DATE              	=> 'date'
			,DEFAULT_SQL_TIME              	=> 'time'
			,DEFAULT_SQL_GYEAR              => 'gyear'
			,DEFAULT_SQL_GYEARMONTH         => 'gyearmonth'
			,DEFAULT_SQL_GMONTHDAY          => 'gmonthday'
			,DEFAULT_SQL_BOOLEAN            => 'boolean'

};

use constant {
  			DEFAULT_ID_SQL_TYPE						=> { SQL_TYPE  => DEFAULT_SQL_NUMBER,SQL_SIZE => 18 } 
			,DEFAULT_SEQ_SQL_TYPE					=> { SQL_TYPE  => DEFAULT_SQL_NUMBER,SQL_SIZE => 18 }
			,DEFAULT_VALUE_SQL_TYPE					=> { SQL_TYPE  => DEFAULT_SQL_VARCHAR,SQL_SIZE => 4096 }
};

use constant {
			DEFAULT_ID_SQL_COLUMN			=> { NAME	=> 'ID',TYPE 	=> DEFAULT_ID_SQL_TYPE,MINOCCURS => 1,MAXOCCURS => 1, PK_SEQ => 0 }
			,DEFAULT_SEQ_SQL_COLUMN			=> { NAME	=> 'SEQ',TYPE	=> DEFAULT_SEQ_SQL_TYPE,MINOCCURS => 1,MAXOCCURS => 1,PK_SEQ => 1 }
			,DEFAULT_VALUE_SQL_COLUMN		=> { NAME	=> 'VALUE',TYPE	=> DEFAULT_VALUE_SQL_TYPE,MINOCCURS => 1,MAXOCCURS => 1,VALUE_COL => 1   }
};

our  %_DEFAULT_SIZE =(
		VARCHAR         =>         4096
);

our %_ATTRS_R=( 
			NAME   => sub {
							my $self=shift;
							return defined $self->{PATH} ? basename($self->{PATH}) : $self->{NAME};
			}
			,COLUMN_SEQUENCE	=> sub {
							my $self=shift;
							return $self->{COLUMN_SEQUENCE};
			}
			,MAXOCCURS => sub {
							my $self=shift;
							return 1 unless defined $self->{MAXOCCURS};
							return $self->{MAXOCCURS};
			}
			,MINOCCURS => sub {
							my $self=shift;
							return 1 unless defined $self->{MINOCCURS};
							return $self->{MINOCCURS};
			}
			,SQL_NAME => sub {
							my $self=shift;
							return $self->get_sql_name;
			}
			,INTERNAL_REFERENCE => sub {
							my $self=shift;
							return $self->{INTERNAL_REFERENCE} ? 1 : 0;
			}
			,SQL_TYPE  => sub {
							my $self=shift;
							return $self->get_sql_type
			}
			,PK			=> sub {
							my $self=shift;
							return defined $self->get_attrs_value qw(PK_SEQ)  ? 1 : 0;
			}
			,GROUP_REF	=> sub {
							my $self=shift;
							return $self->{GROUP_REF} ? 1 : 0;
			}
			,PATH		=> sub {
							my $self=shift;
							return $self->{PATH};
			}
);

our %_ATTRS_W=();

sub new {
	my ($class,%params)=@_;
	$params{XSD_SEQ}=0 unless defined $params{XSD_SEQ}; 
	return bless(\%params,$class);
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

sub _translate_type {
	my ($self,$type,%params)=@_;
	return $type;
}

sub _get_hash_sql_types {
	my  ($self,%params)=@_;
	return \%_DEFAULT_SIZE;
}

sub _get_sql_size {
	my ($self,%params)=@_;
	return $self->{TYPE}->{SQL_SIZE} if defined $self->{TYPE}->{SQL_SIZE};
	my $hashvalues=$self->_get_hash_sql_types(%params);
	my $v=$hashvalues->{uc($self->{TYPE}->{SQL_TYPE})};
	return undef unless defined $v;
	return $v->($self,%params) if ref($v) eq 'CODE';
	return $v if ref($v) eq  '';
	confess  Dumper($v).": uninplemented";
}

sub get_sql_type {
	my ($self,%params)=@_;
	return $self->{SQL_TYPE} if defined $self->{SQL_TYPE}; 
	my $type=$self->{TYPE}->{SQL_TYPE};
	my $sz=$self->_get_sql_size(%params);
	$type.='('.$sz.')' if defined $sz;
	$self->{SQL_TYPE}=$self->_translate_type($type,%params);
	return $self->{SQL_TYPE};
}

sub _adjdup_sql_name {
	my ($self,$name,%params)=@_;
	my $l=$params{COLUMNNAME_LIST};
	confess "param COLUMNNAME_LIST not defined " unless defined $l;
	$name=substr($name,0,length($name) -1).'0' if $name!~/\d+$/;
	while(1) {
		last unless exists $l->{uc($name)};
		my ($suff)=$name=~/(\d+)$/;
		$suff+=1;
		$name=~s/\d+$/$suff/;
	}
	return $name;
}

sub _translate_path  {
	my ($self,%params)=@_;
	my $path=$self->get_attrs_value qw(NAME);
	$path=~s/^_//;
	$path=~s/-/_/g;
	return $path;
}

sub _resolve_invalid_name {
	my ($self,$name,%params)=@_;
	return $name;
}

sub _reduce_sql_name {
	my ($self,$name,%params)=@_;
	my $maxsize=$self->get_name_maxsize;
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

sub get_column_sequence {
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(COLUMN_SEQUENCE);
}

sub get_sql_name {
	my ($self,%params)=@_;
	return $self->{SQL_NAME} if defined $self->{SQL_NAME};
	my $l=$params{COLUMNNAME_LIST};
	confess "param COLUMNNAME_LIST not defined " unless defined $l; 
	my $name= $self->_translate_path(%params);
	$name=$self->_reduce_sql_name($name) if length($name) > $self->get_name_maxsize();
	$name=$self->_adjdup_sql_name($name,%params) if exists $l->{uc($name)};
	$name=$self->_resolve_invalid_name($name,%params);
	$name=$self->_adjdup_sql_name($name,%params) if exists $l->{uc($name)};
	confess "duplicate column name" if exists $l->{uc($name)}; 
	$l->{uc($name)}=undef;
	$self->{SQL_NAME}=$name;
	return $name;
}

sub is_internal_reference {
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(INTERNAL_REFERENCE);
}

sub is_group_reference {
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(GROUP_REF);	
}

sub get_min_occurs {
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(MINOCCURS);
}

sub get_max_occurs {
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(MAXOCCURS);
}

sub is_pk {
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(PK) ? 1 : 0;
}

sub get_pk_seq {
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(PK_SEQ);
}

sub get_xsd_seq {
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(XSD_SEQ);
}

sub get_path {
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(PATH);
}

sub get_path_reference {
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(PATH_REFERENCE);
}

sub get_table_name {
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(TABLE_NAME);
}

sub get_full_name {
	my ($self,%params)=@_;
	return $self->get_table_name.'.'.$self->get_sql_name;
}

sub get_table_reference {
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(TABLE_REFERENCE);	
}

sub factory_column {
	my ($self,$type,%params)=@_;
	if (defined $type) {
		return Storable::dclone(bless(DEFAULT_ID_SQL_COLUMN,ref($self))) if $type eq 'ID';
		return Storable::dclone(bless(DEFAULT_SEQ_SQL_COLUMN,ref($self))) if $type eq 'SEQ';
		return Storable::dclone(bless(DEFAULT_VALUE_SQL_COLUMN,ref($self))) if $type eq 'VALUE';
		croak "$type: invalid type";
	}
	croak "param NAME and/or  SQL_TYPE not defined" unless defined $params{NAME} && defined $params{SQL_TYPE};
	croak "TYPE is not a valid param name " if exists $params{TYPE};
	
	$params{TYPE}={
			SQL_TYPE => $self->factory_sql_type(delete $params{SQL_TYPE})
			,SQL_SIZE => delete $params{SQL_SIZE} 
	};
	
	return bless \%params,ref($self); 
}


sub factory_sql_type {
	my ($self,$type,%params)=@_;
	croak "2^ param not defined " unless defined $type;
	return DEFAULT_SQL_VARCHAR if $type eq 'VARCHAR';
	return DEFAULT_SQL_CHAR if $type eq 'CHAR';
	return DEFAULT_SQL_NUMBER if $type eq 'NUMBER';
	return DEFAULT_SQL_DOUBLE if $type eq 'DOUBLE';
	return DEFAULT_SQL_FLOAT   if $type eq  'FLOAT';
	return DEFAULT_SQL_DECIMAL   if $type eq  'DECIMAL';
	return DEFAULT_SQL_DATETIME   if $type eq  'DATETIME';
	return DEFAULT_SQL_DATE   if $type eq  'DATE';
	return DEFAULT_SQL_TIME   if $type eq  'TIME';
	return DEFAULT_SQL_GYEAR   if $type eq  'GYEAR';
	return DEFAULT_SQL_GYEARMONTH   if $type eq  'GYEARMONTH';
	return DEFAULT_SQL_GMONTHDAY   if $type eq  'GMONTHDAY';
	return DEFAULT_SQL_BOOLEAN  if $type eq  'BOOLEAN';
	croak "$type: invalid type";
}

sub factory_dictionary_columns {
	my ($self,$dictionary_type,%params)=@_;
	my $c=$self;
	croak "dictionary type not defined" unless defined $dictionary_type;
	my @cols=$dictionary_type eq 'TABLE_DICTIONARY' 
		? (
			$c->factory_column(undef,NAME => 'table_name',SQL_TYPE	=> 'VARCHAR',SQL_SIZE => $c->get_name_maxsize,PK_SEQ => 0) 
			,$c->factory_column(qw(SEQ))->set_attrs_value(NAME => 'xsd_seq',COMMENT => 'xsd sequence start',PK_SEQ => undef)
			,$c->factory_column(undef,NAME => 'type',SQL_TYPE	=> 'CHAR',SQL_SIZE => 1,ENUM_RESTRICTIONS => { C => 'complex type',S => 'simple_type' },COMMENT => 'values: C - the table is a simple_type - S - the table is a complex_type')
			,$c->factory_column(undef,NAME => 'is_group',SQL_TYPE	=> 'CHAR',SQL_SIZE => 1,ENUM_RESTRICTIONS => { Y => 'is a group' },COMMENT => 'values: Y - the table is a group type')
			,$c->factory_column(undef,NAME => 'is_choise',SQL_TYPE	=> 'CHAR',SQL_SIZE => 1,ENUM_RESTRICTIONS => { Y => 'is a choise' },COMMENT => 'values: Y - the table is a choise')
			,$c->factory_column(qw(SEQ))->set_attrs_value(NAME => 'min_occurs',PK_SEQ => undef)
			,$c->factory_column(qw(SEQ))->set_attrs_value(NAME => 'max_occurs',PK_SEQ => undef)
			,$c->factory_column(undef,NAME => 'path_name',SQL_TYPE	=> 'VARCHAR')
			,$c->factory_column(qw(SEQ))->set_attrs_value(NAME => 'deep_level',COMMENT => 'the root has level 0',PK_SEQ => undef)
		)
		: $dictionary_type eq 'COLUMN_DICTIONARY' 
		? (
			$c->factory_column(undef,NAME => 'table_name',SQL_TYPE	=> 'VARCHAR',SQL_SIZE => $c->get_name_maxsize,PK_SEQ => 0) 
			,$c->factory_column(qw(SEQ))->set_attrs_value(NAME => 'column_seq',COMMENT => 'a column sequence into the table',PK_SEQ => 1)
			,$c->factory_column(undef,NAME => 'column_name',SQL_TYPE	=> 'VARCHAR',SQL_SIZE => $c->get_name_maxsize) 
			,$c->factory_column(undef,NAME => 'path_name',SQL_TYPE	=> 'VARCHAR') 
			,$c->factory_column(qw(SEQ))->set_attrs_value(NAME => 'xsd_seq',COMMENT => 'xsd sequence into a choise',PK_SEQ => undef)
			,$c->factory_column(undef,NAME => 'path_name_ref',SQL_TYPE	=> 'VARCHAR',COMMENT => 'the column reference a table') 
			,$c->factory_column(undef,NAME => 'table_name_ref',SQL_TYPE	=> 'VARCHAR',SQL_SIZE => $c->get_name_maxsize,COMMENT => 'the column reference a table') 
			,$c->factory_column(undef,NAME => 'is_internal_ref',SQL_TYPE	=> 'CHAR',SQL_SIZE => 1,ENUM_RESTRICTIONS => { Y => 'has internal_reference' },COMMENT => 'values: Y - the column is an array of simple_type')
			,$c->factory_column(undef,NAME => 'is_group_ref',SQL_TYPE	=> 'CHAR',SQL_SIZE => 1,ENUM_RESTRICTIONS => { Y => 'group reference' },COMMENT => 'values: Y - the column reference a group')
			,$c->factory_column(qw(SEQ))->set_attrs_value(NAME => 'min_occurs',COMMENT => 'the ref table has this min_occurs or the column has internal reference',PK_SEQ => undef)
			,$c->factory_column(qw(SEQ))->set_attrs_value(NAME => 'max_occurs',COMMENT => 'the ref table has this max_occurs or the column has internal reference',PK_SEQ => undef )
			,$c->factory_column(qw(SEQ))->set_attrs_value(NAME => 'pk_seq',COMMENT => 'the column is part of the primary key - this is the sequence number',PK_SEQ => undef )
		)
		: $dictionary_type eq 'RELATION_DICTIONARY' 
		? (
			$c->factory_column(undef,NAME => 'parent_table_name',SQL_TYPE	=> 'VARCHAR',SQL_SIZE => $c->get_name_maxsize,PK_SEQ => 0) 
			,$c->factory_column(qw(SEQ))->set_attrs_value(NAME => 'child_sequence',PK_SEQ => 1)
			,$c->factory_column(undef,NAME => 'child_table_name',SQL_TYPE	=> 'VARCHAR',SQL_SIZE => $c->get_name_maxsize) 
		)
		: croak "$dictionary_type: invalid value for dictionary_type";
	my %cl=();
	for my $col(@cols) { #generate sql names
		$col->get_sql_name(COLUMNNAME_LIST => \%cl);
	}
	return wantarray ? @cols : \@cols;
}

sub get_dictionary_data {
	my ($self,$dictionary_type,%params)=@_;
	croak "dictionary type not defined" unless defined $dictionary_type;
	if ($dictionary_type eq 'COLUMN_DICTIONARY') {
		my $table_ref=$self->get_table_reference;
		my %data=(
			COLUMN_SEQ  		=> $self->get_column_sequence
			,COLUMN_NAME		=> $self->get_sql_name
			,PATH_NAME			=> $self->get_attrs_value qw(PATH)
			,XSD_SEQ			=> $self->get_xsd_seq
			,PATH_NAME_REF		=> $self->get_path_reference
			,TABLE_NAME_REF		=> ($table_ref ? $table_ref->get_sql_name : undef)
			,IS_INTERNAL_REF	=> ($self->is_internal_reference ? 'Y' : undef)
			,IS_GROUP_REF		=> ($self->is_group_reference ? 'Y' : undef)
			,MIN_OCCURS			=> $self->get_min_occurs
			,MAX_OCCURS			=> $self->get_max_occurs
			,PK_SEQ				=> $self->get_pk_seq 
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
		XSD_SEQ  - a sequence number into a choise 
		MIN_OCCURS - default 1
		MAX_OCCURS - default 1
		NAME  - a basename of xml node
		PATH 	- a path name of xml xml node
		PATH_REFERENCE - the referenced by column 
		TABLE_REFERENCE	- the table referenced by column
		INTERNAL_REFERENCE - true if the column is an array of simple types
		PK_SEQ  - sequence into the primary key 
		GROUP_REF - the column reference a GROUP
		TABLE_NAME - the table name of the column
		
set_attrs_value   - set a value of attributes

	the arguments are a pairs NAME => VALUE
	the method return a self object



get_attrs_value  - return a list  of attributes values

	the arguments are a list of attributes name


get_column_sequence - return the sequence into the table - the first column has sequence 0


get_sql_type  - return the sql type of the column


get_sql_name  - return the  name of the column


get_min_occurs - return the value of the minoccurs into the xsd schema


get_max_occurs - return the value of the maxoccurs into the xsd schema


is_internal_reference  - return true if the column is an array of simple types   


is_group_reference - return true if the column reference a xsd group


get_path		   - return the node path name


get_path_reference - return the path referenced 


get_table_reference - return the table referenced 


get_table_name - return the table name of the column


is_pk  - return true if the column is part of the primary key


get_pk_seq - return the sequence into the primary key


get_xsd_seq - return a sequence number into a choise


factory_column - factory a generic column object 

	the first argument must be  ID|SEQ|VALUE|undef
		ID    - factory the first column of a primary key 
		SEQ  - factory the second column of a primary key
		VALUE - factory a generic value column
		undef - factory a user custom column 
					other params must be NAME,SQL_TYPE and optionally SQL_SIZE
	the method return an object  of the same type of the self object
 

factory_sql_type  - factory a generic sql type 

	the first argument must be   VARCHAR|CHAR|NUMBER|DOUBLE|FLOAT|DECIMAL|DATETIME|DATE|TIME|GYEAR|GYEARMONTH|GMONTHDAY|BOOLEAN
	the method return a string 


factory_dictionary_columns - factory the columns dictionary 
	
	the first argument must be:
		TABLE_DICTIONARY - factory columns for table dictionary
		COLUMN_DICTIONARY - factory columns for column dictionary
		RELATION_DICTIONARY - factory columns for relation dictionary

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
