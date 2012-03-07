package blx::xsdsql::xml::pg::column;
use strict;
use warnings;
use integer;
use Carp;
use base qw(blx::xsdsql::xml::pg::catalog blx::xsdsql::xml::generic::column);
use blx::xsdsql::ut qw(nvl);


my %_TRANSLATE_TYPE=(
		number    				=> 'numeric'
		,double      			=> 'double precision'
		,datetime   			=> 'varchar(50)'
		,date          			=> 'varchar(50)'
		,time         			=> 'varchar(50)'
		,gyear        			=> 'varchar(50)'
		,gyearmonth   			=> 'varchar(50)'
		,gmonthday  			=> 'varchar(50)'
		,float					=> 'float'
		,decimal				=> 'decimal'
		,integer				=> 'numeric'
		,int 					=> 'numeric'
		,nonPositiveInteger  	=> 'numeric'
		,nonNegativeInteger		=> 'numeric'
		,negativeInteger		=> 'numeric'
		,long					=> 'numeric'
		,short					=> 'numeric'
		,byte					=> 'numeric'
		,unsignedLong			=> 'numeric'
		,unsignedInt			=> 'numeric'
		,unsignedShort			=> 'numeric'
		,unsignedByte			=> 'numeric'
		,positiveInteger		=> 'numeric'
		,dateTime				=> 'varchar(50)'
		,duration				=> 'varchar(4096)'
		,string					=> 'varchar(4096)' 
		,normalizedString		=> {    REF	=> 'string' }
		,token					=> {    REF	=> 'string' }
		,base64Binary			=> {    REF	=> 'string' }
		,hexBinary				=> {    REF	=> 'string' }
		,boolean				=> 'boolean'
		,anyURI					=> 'varchar(4096)'
		,ID						=> 'varchar(4096)'
		,IDREF					=> 'varchar(4096)'
		,IDREFS					=> 'varchar(4096)'
		,NMTOKEN				=> 'varchar(4096)'
		,NMTOKENS				=> 'varchar(4096)'
		,language				=> 'varchar(4096)'
		,Name					=> 'varchar(4096)'
		,QName					=> 'varchar(4096)'
		,NCName					=> 'varchar(4096)'
		,char					=> 'char(4096)' 
);

use constant {  #for construct columms dictionary
			DEFAULT_SQL_VARCHAR             => 'varchar'
			,DEFAULT_SQL_CHAR				=> 'char'
			,DEFAULT_SQL_NUMBER				=> 'number'
};


my %INVALID_NAMES=(map { (uc($_),undef) } qw ( int  short byte column varchar date long numeric table alter create drop union end)); 

my  %_DEFAULT_SIZE =(
 		VARCHAR         =>         4096
);

use constant {
  			DEFAULT_ID_SQL_TYPE						=> { SQL_TYPE  => DEFAULT_SQL_NUMBER,SQL_SIZE => 18 } 
			,DEFAULT_SEQ_SQL_TYPE					=> { SQL_TYPE  => DEFAULT_SQL_NUMBER,SQL_SIZE => 18 }
			,DEFAULT_VALUE_SQL_TYPE					=> { SQL_TYPE  => DEFAULT_SQL_VARCHAR,SQL_SIZE => 4096 }
};

sub _get_hash_sql_types {
	my  ($self,%params)=@_;
	return \%_DEFAULT_SIZE;
}

sub _get_translate_type_table { return \%_TRANSLATE_TYPE; }

sub _get_default_predef_colum {
	my ($self,$type,%params)=@_;
	return DEFAULT_ID_SQL_TYPE if $type eq 'ID';
	return DEFAULT_SEQ_SQL_TYPE if $type eq 'SEQ';
	return DEFAULT_VALUE_SQL_TYPE if $type eq 'VALUE';
	confess "$type: not valid\n";
}


sub _factory_sql_type {
	my ($self,$type,%params)=@_;
	return DEFAULT_SQL_VARCHAR if $type eq 'VARCHAR';
	return DEFAULT_SQL_CHAR if $type eq 'CHAR';
	return DEFAULT_SQL_NUMBER if $type eq 'NUMBER';
	confess "$type: invalid type";
}

sub _resolve_invalid_name {
	my ($self,$name,%params)=@_;
	if (exists $INVALID_NAMES{uc($name)}) {
		$name=substr($name,0,$self->get_name_maxsize - 1) if length($name) >= $self->get_name_maxsize;
		$name.='_';
	}
	return $name;
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

	blx::xsdsql::xml::pg::column -  a column class for postgresql
 
=cut

=head1 SYNOPSIS

  use blx::xsdsql::xml::pg::column

=cut


=head1 DESCRIPTION

this package is a class - instance it with the method new


=head1 FUNCTIONS

see the methods of blx::xsdsql::xml::generic::column and blx::xsdsql::xml::pg::catalog 
 

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




