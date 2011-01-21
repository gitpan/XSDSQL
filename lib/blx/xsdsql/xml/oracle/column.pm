package blx::xsdsql::xml::oracle::column;

use strict;
use warnings;
use integer;
use Carp;

use base qw(blx::xsdsql::xml::oracle::catalog blx::xsdsql::xml::generic::column);

my  %_DEFAULT_SIZE =(
		VARCHAR         =>         4000
);

my %_TRANSLATE_TYPE= (
		number    => 'number'
		,double      => 'binary_double'
		,datetime   => 'varchar(50)'
		,date          => 'varchar(50)'
		,time         =>  'varchar(50)'
		,gyear        =>  'varchar(50)'
		,gyearmonth   => 'varchar(50)'
		,gmonthday  => 'varchar(50)'
		,oth         => sub {
							my $type=shift;
							return $type;
		}
		,boolean	=> 'number(1)'
		,default	=> 'varchar('.$_DEFAULT_SIZE{VARCHAR}.')'
		
);

sub _translate_type {
	my ($self,$type,%params)=@_;
	$type='default' unless defined $type;
	my $t=$_TRANSLATE_TYPE{$type};
	$t=$_TRANSLATE_TYPE{oth}->($type) unless defined $t;
	return $t;
}

my @INVALID_NAMES=qw ( int  short byte column varchar date time long number float table alter create drop decimal integer); 

sub _resolve_invalid_name {
	my ($self,$name,%params)=@_;
	$name.='_' if  grep (uc($_) eq uc($name) ,@INVALID_NAMES);
	return $name;
}

sub _get_hash_sql_types {
	my  ($self,%params)=@_;
	return \%_DEFAULT_SIZE;
}


sub new {
	my ($class,%params)=@_;
	return bless(blx::xsdsql::xml::generic::column->new(%params),$class)
}

sub set_attrs_value {
	my $self=shift;
	blx::xsdsql::ut::set_attrs_value($self,\%blx::xsdsql::xml::generic::column::_ATTRS_W,@_);
	return $self;
}

sub get_attrs_value {
	my $self=shift;
	return blx::xsdsql::ut::get_attrs_value($self,\%blx::xsdsql::xml::generic::column::_ATTRS_R,@_);
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




