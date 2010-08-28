package blx::xsdsql::xml::pg::column;

use strict;
use warnings;
use integer;
use Carp;

use base qw(blx::xsdsql::xml::pg::catalog blx::xsdsql::xml::generic::column);

our  %_DEFAULT_SIZE =(
		VARCHAR         =>         4096
);


sub _get_hash_sql_types {
	my  ($self,%params)=@_;
	return \%_DEFAULT_SIZE;
}


sub new {
	my $class=shift;
	my %params=@_;
	return bless(blx::xsdsql::xml::generic::column->new(%params),$class)
}

my %_TRANSLATE_TYPE= (
		number    => 'numeric'
		,double      => 'double precision'
		,datetime   => 'varchar(50)'
		,date          => 'varchar(50)'
		,time         =>  'varchar(50)'
		,gyear        =>  'varchar(50)'
		,gyearmonth   => 'varchar(50)'
		,gmonthday  => 'varchar(50)'
		,oth         => sub {
							my $type=shift;
							$type=~s/number/numeric/i;
							return $type;
		}
);

sub _translate_type {
	my $self=shift;
	my $type=shift;
	my %params=@_;
	my $t=$_TRANSLATE_TYPE{$type};
	$t=$_TRANSLATE_TYPE{oth}->($type) unless defined $t;
	return $t;
}

my @INVALID_NAMES=qw ( int  short byte column varchar date long numeric table alter create drop ); 

sub _resolve_invalid_name {
	my ($self,$name,%params)=@_;
	$name.='_' if  grep (uc($_) eq uc($name) ,@INVALID_NAMES);
	return $name;
}

sub set_attrs_value {
	my $self=shift;
	return blx::xsdsql::ut::set_attrs_value($self,\%blx::xsdsql::xml::generic::column::_ATTRS_W,@_);
}

sub get_attrs_value {
	my $self=shift;
	return blx::xsdsql::ut::get_attrs_value($self,\%blx::xsdsql::xml::generic::column::_ATTRS_R,@_);
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

lorenzo.bellotti, E<lt>bellzerozerouno@tiscali.itE<gt>

=head1 COPYRIG 

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut




