package blx::xsdsql::xml::oracle::column;

use strict;
use warnings;
use integer;
use Carp;

use base qw(blx::xsdsql::xml::oracle::catalog blx::xsdsql::xml::generic::column );

my  %_DEFAULT_SIZE =(
		VARCHAR         =>         4000
);

my %_TRANSLATE_TYPE= (
		number    				=> 'number'
		,double      			=> 'double precision'
		,datetime   			=> 'varchar(50)'
		,date          			=> 'varchar(50)'
		,time         			=> 'varchar(50)'
		,gyear        			=> 'varchar(50)'
		,gyearmonth   			=> 'varchar(50)'
		,gmonthday  			=> 'varchar(50)'
		,float					=> 'float'
		,decimal				=> 'varchar(50)'
		,integer				=> 'number'
		,int 					=> 'number'
		,nonPositiveInteger  	=> 'number'
		,nonNegativeInteger		=> 'number'
		,negativeInteger		=> 'number'
		,long					=> 'number'
		,short					=> 'number'
		,byte					=> 'number'
		,unsignedLong			=> 'number'
		,unsignedInt			=> 'number'
		,unsignedShort			=> 'number'
		,unsignedByte			=> 'number'
		,positiveInteger		=> 'number'
		,dateTime				=> 'varchar(50)'
		,duration				=> 'varchar(4000)'
		,string					=> 'varchar(4000)' 
		,normalizedString		=> {    REF	=> 'string' }
		,token					=> {    REF	=> 'string' }
		,base64Binary			=> {    REF	=> 'string' }
		,hexBinary				=> {    REF	=> 'string' }
		,boolean				=> 'number(1)'
		,anyURI					=> 'varchar(4000)'
		,ID						=> 'varchar(4000)'
		,IDREF					=> 'varchar(4000)'
		,IDREFS					=> 'varchar(4000)'
		,NMTOKEN				=> 'varchar(4000)'
		,NMTOKENS				=> 'varchar(4000)'
		,language				=> 'varchar(4000)'
		,Name					=> 'varchar(4000)'
		,QName					=> 'varchar(4000)'
		,NCName					=> 'varchar(4000)'
		,char					=> 'char(4000)' 
);

use constant {
			DEFAULT_SQL_VARCHAR             => 'varchar'
			,DEFAULT_SQL_CHAR				=> 'char'
			,DEFAULT_SQL_NUMBER				=> 'number'
# 			,DEFAULT_SQL_DOUBLE				=> 'double'
# 			,DEFAULT_SQL_FLOAT             	=> 'float'
# 			,DEFAULT_SQL_DECIMAL         	=> 'decimal'
# 			,DEFAULT_SQL_DATETIME       	=> 'datetime'
# 			,DEFAULT_SQL_DATE              	=> 'date'
# 			,DEFAULT_SQL_TIME              	=> 'time'
# 			,DEFAULT_SQL_GYEAR              => 'gyear'
# 			,DEFAULT_SQL_GYEARMONTH         => 'gyearmonth'
# 			,DEFAULT_SQL_GMONTHDAY          => 'gmonthday'
# 			,DEFAULT_SQL_BOOLEAN            => 'boolean'

};


use constant {
  			DEFAULT_ID_SQL_TYPE						=> { SQL_TYPE  => DEFAULT_SQL_NUMBER,SQL_SIZE => 18 } 
			,DEFAULT_SEQ_SQL_TYPE					=> { SQL_TYPE  => DEFAULT_SQL_NUMBER,SQL_SIZE => 18 }
			,DEFAULT_VALUE_SQL_TYPE					=> { SQL_TYPE  => DEFAULT_SQL_VARCHAR,SQL_SIZE => 4000 }
};


sub _get_translate_type_table { return \%_TRANSLATE_TYPE; }

my %INVALID_NAMES=(map { (uc($_),undef) } qw ( int  double short byte column varchar date time long number float table alter create drop decimal integer level duration language string union float)); 

sub _get_default_predef_colum {
	my ($self,$type,%params)=@_;
	return DEFAULT_ID_SQL_TYPE if $type eq 'ID';
	return DEFAULT_SEQ_SQL_TYPE if $type eq 'SEQ';
	return DEFAULT_VALUE_SQL_TYPE if $type eq 'VALUE';
	confess "$type: not valid\n";
}

sub _resolve_invalid_name {
	my ($self,$name,%params)=@_;
	if (exists $INVALID_NAMES{uc($name)}) {
		$name=substr($name,0,$self->get_name_maxsize - 1) if length($name) >= $self->get_name_maxsize;
		$name.='_';
	}
	return $name;
}

sub _get_hash_sql_types {
	my  ($self,%params)=@_;
	return \%_DEFAULT_SIZE;
}

sub _factory_sql_type {
	my ($self,$type,%params)=@_;
	return DEFAULT_SQL_VARCHAR if $type eq 'VARCHAR';
	return DEFAULT_SQL_CHAR if $type eq 'CHAR';
	return DEFAULT_SQL_NUMBER if $type eq 'NUMBER';
	confess "$type: invalid type";
}

sub _get_attrs_w { return \%blx::xsdsql::xml::generic::column::_ATTRS_W; }
sub _get_attrs_r { return \%blx::xsdsql::xml::generic::column::_ATTRS_R; }

sub new {
	my ($class,%params)=@_;
	return bless(blx::xsdsql::xml::generic::column->_new(%params),$class)
}


1;



__END__


=head1  NAME

	blx::xsdsql::xml::oracle::column -  a column class for oracle
 
=cut

=head1 SYNOPSIS

	use blx::xsdsql::xml::oracle::column

=cut


=head1 DESCRIPTION

this package is a class - instance it with the method new


=head1 FUNCTIONS

see the methods of blx::xsdsql::xml::generic::column and blx::xsdsql::xml::oracle::catalog 
 

=head1 EXPORT

None by default.


=head1 EXPORT_OK
	
none 

=head1 SEE ALSO

See blx::xsdsql::xml::generic::column and blx::xsdsql::xml::pg::catalog  - this class inerith for it 

See blx:.xsdsql::generator for generate the schema of the database and blx::xsdsql::parser  for parse a xsd file (schema file)

=head1 AUTHOR

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIG 

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut




