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
			,DEFAULT_SQL_FLOAT             => 'float'
			,DEFAULT_SQL_DECIMAL         => 'decimal'
			,DEFAULT_SQL_DATETIME       => 'datetime'
			,DEFAULT_SQL_DATE              => 'date'
			,DEFAULT_SQL_TIME              => 'time'
			,DEFAULT_SQL_GYEAR              => 'gyear'
			,DEFAULT_SQL_GYEARMONTH              => 'gyearmonth'
			,DEFAULT_SQL_GMONTHDAY              => 'gmonthday'
			,DEFAULT_SQL_BOOLEAN              => 'boolean'

};

use constant {
  			DEFAULT_ID_SQL_TYPE						=> { SQL_TYPE  => DEFAULT_SQL_NUMBER,SQL_SIZE => 18 } 
			,DEFAULT_SEQ_SQL_TYPE					=> { SQL_TYPE  => DEFAULT_SQL_NUMBER,SQL_SIZE => 18 }
			,DEFAULT_VALUE_SQL_TYPE				=> { SQL_TYPE  => DEFAULT_SQL_VARCHAR,SQL_SIZE => 4096 }
};

use constant {
			DEFAULT_ID_SQL_COLUMN			=> { NAME	=> 'ID',TYPE 	=> DEFAULT_ID_SQL_TYPE,MINOCCURS => 1,MAXOCCURS => 1, PK => 1, PK_SEQ => 0 }
			,DEFAULT_SEQ_SQL_COLUMN			=> { NAME	=> 'SEQ',TYPE	=> DEFAULT_SEQ_SQL_TYPE,MINOCCURS => 1,MAXOCCURS => 1,PK => 1, PK_SEQ => 1 }
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
			,MAXOCCURS => sub {
							my $self=shift;
							return 1 unless defined $self->{MAXOCCURS};
							return $self->{MAXOCCURS};
			}
			,MINOCCURS => sub {
							my $self=shift;
							return 1 unless defined $self->{MINOCCURS};
							return $self->{MINCCURS};
			}
			,SQL_NAME => sub {
							my $self=shift;
							return $self->get_sql_name;
			}
			,INTERNAL_REFERENCE => sub {
							my $self=shift;
							return $self->is_internal_reference
			}
			,SQL_TYPE  => sub {
							my $self=shift;
							return $self->get_sql_type
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
	confess "param COLUMNNAME_LIST not defined " unless defined $params{COLUMNNAME_LIST};
	$name=substr($name,0,length($name) -1).'0' if $name!~/\d+$/;
	while(1) {
		last unless exists $l->{$name};
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

sub _resolve_invalid_name {
	my ($self,$name,%params)=@_;
	return $name;
}

sub get_sql_name {
	my ($self,%params)=@_;
	return $self->{SQL_NAME} if defined $self->{SQL_NAME};
	my $l=$params{COLUMNNAME_LIST};
	confess "param COLUMNNAME_LIST not defined " unless defined $l; 
	my $name= $self->_translate_path(%params);
	$name=$self->_reduce_sql_name($name) if length($name) > $self->get_name_maxsize();
	$name=$self->_resolve_invalid_name($name,%params);
	$name=$self->_adjdup_sql_name($name,%params) if exists $l->{$name};
	confess "duplicate column name" if exists $l->{$name};
	push @{$self->{PARAM}->{COLUMNNAME_LIST}},$name;
	$l->{$name}=undef;
	$self->{SQL_NAME}=$name;
	return $name;
}

sub is_internal_reference {
	my ($self,%params)=@_;
	return $self->{INTERNAL_REFERENCE} ? 1 : 0;
}

sub factory_column {
	my $self=shift;
	my $type=nvl(shift);
	return Storable::dclone(bless(DEFAULT_ID_SQL_COLUMN,ref($self))) if $type eq 'ID';
	return Storable::dclone(bless(DEFAULT_SEQ_SQL_COLUMN,ref($self))) if $type eq 'SEQ';
	return Storable::dclone(bless(DEFAULT_VALUE_SQL_COLUMN,ref($self))) if $type eq 'VALUE';
	croak "$type: invalid type";

}


sub factory_sql_type {
	my $self=shift;
	my $type=nvl(shift);
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
	confess "$type: invalid type";
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
		XSD_SEQ  - a sequence number into a choise or sequence of a xsd file 
		MIN_OCCURS - default 1
		MAX_OCCURS - default 1
		NAME  - a basename of xml node
		PATH_NAME - a path name of xml node
		INTERNAL_REFERENCE - true if the column is an array of simple types


set_attrs_value   - set a value of attributes

	the arguments are a pairs NAME => VALUE
	the method return a self object



get_attrs_value  - return a list  of attributes values

	the arguments are a list of attributes name


get_sql_type  - return the sql type of the column


get_sql_name  - return the  name of the column


is_internal_reference  - return true if the column is an array of simple types   


factory_column - factory a generic column object 

	the first argument must be  ID|SEQ|VALUE
		ID:    - factory the first column of a primary key 
		SEQ  - factory the second column of a primary key
		VALUE - factory a generic value column
	the method return an object  of the same type of the self object
 

factory_sql_type  - factory a generic sql type 

	the first argument must be   VARCHAR|CHAR|NUMBER|DOUBLE
	the method return a string 


=head1 EXPORT

None by default.


=head1 EXPORT_OK
	
none 

=head1 SEE ALSO

See blx::xsdsql::xml::generic::catalog, it's the base class
See blx:.xsdsql::generator for generate the schema of the database and blx::xsdsql::parser 
for parse a xsd file (schema file)


=head1 AUTHOR

lorenzo.bellotti, E<lt>bellzerozerouno@tiscali.itE<gt>

=head1 COPYRIG 

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
