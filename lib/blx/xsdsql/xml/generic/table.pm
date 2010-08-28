package blx::xsdsql::xml::generic::table;

use strict;
use warnings;
use integer;
use Carp;
use blx::xsdsql::ut qw(nvl);
use File::Basename;

use base qw(blx::xsdsql::xml::generic::catalog);

our %_ATTRS_R=( 
			NAME   => sub {
							my $self=shift;
							return defined $self->{PATH} ? basename($self->{PATH}) : $self->{NAME};
			}							
			,PATH_RESOLVED => sub {
							my $self=shift;
							return $self->get_path_resolved(@_);
			}
			,TYPES => sub {
							my $self=shift;
							my $t=nvl($self->{TYPES},[]); 
							return wantarray ? @{$t} : $t;
			}
);

our %_ATTRS_W=();

sub new {
	my $class=shift;
	my %params=@_;
	$params{COLUMNS}=[] unless  defined $params{COLUMNS};
	$params{CHILD_TABLES}=[] unless defined $params{CHILD_TABLES}; 
	$params{XSD_SEQ}=0 unless defined $params{XSD_SEQ}; 
	return bless(\%params,$class);
}

sub add_columns {
	my $self=shift;
	$self->{COLUMNNAME_LIST}={} unless defined $self->{COLUMNNAME_LIST}; 
	for my $col(@_) {
		$col->set_attrs_value(COLUMN_SEQUENCE => scalar(@{$self->{COLUMNS}}));
		$col->get_sql_name(COLUMNNAME_LIST => $self->{COLUMNNAME_LIST}); #resolve sql_name
		push @{$self->{COLUMNS}},$col;
	}
	return $self->get_columns;
}

sub get_columns {
	my $self=shift;
	my $v=$self->get_attrs_value qw(COLUMNS);
	return wantarray ? @$v : $v;
}

sub add_child_tables {
	my $self=shift;
	push @{$self->{CHILD_TABLES}},@_;
	return $self;
}

sub resolve_path_for_table_type {
	my $self=shift;
	croak $self->get_sql_name.': table is not a type ' unless $self->get_attrs_value qw(TABLE_IS_TYPE);
	my $orig_path_name=shift;
	my $path=shift;	
	my $table_path=$self->get_attrs_value qw(PATH);
	croak "$path\n$orig_path_name\nnot omogemus path " if substr($path,0,length($orig_path_name)) ne $orig_path_name;
	my $p=$table_path.substr($path,length($orig_path_name));
	return $p;
}

sub find_columns {
	my $self=shift;
	my %params=@_;
	my $cols=$self->get_columns;
	return wantarray ? () : undef if scalar(keys %params) == 0;
	my @r=map {
		my $col=$_;
		(grep {
			my $param_value=$params{$_};
			my $v=$col->get_attrs_value($_);
			my $r=undef;
			if (ref($param_value) eq '') {
				$r=defined $v && defined $param_value && $v eq $param_value
					|| !defined $v && !defined $param_value ? 1 : 0;
			}
			elsif (ref($param_value) eq 'CODE') {
				$r=$param_value->($col,$cols);
			}
			else {
				croak "param value must e scalar or a CODE";
			}
			$r;
		}  keys %params) ? ($col) : (); 
	} @$cols;
	return @r if wantarray;
	return scalar(@r) <= 1 ? $r[0] : \@r;
}

sub get_child_tables {
	my $self=shift;
	my $v=$self->get_attrs_value qw(CHILD_TABLES);
	return wantarray ? @$v : $v;
}
	
sub set_attrs_value {
	my $self=shift;
	return blx::xsdsql::ut::set_attrs_value($self,\%_ATTRS_W,@_);
}

sub get_attrs_value {
	my $self=shift;
	return blx::xsdsql::ut::get_attrs_value($self,\%_ATTRS_R,@_);
}

sub _adjdup_sql_name {
	my $self=shift;
	my $name=shift;
	my %params=@_;
	$name=substr($name,0,length($name) -1).'0' if $name!~/\d+$/;
	confess "param TABLENAME_LIST not defined" unless defined $params{TABLENAME_LIST}; 
	my $l=$params{TABLENAME_LIST};
	while(1) {
		last unless exists $l->{$name};
		my ($suff)=$name=~/(\d+)$/;
		$suff+=1;
		$name=~s/\d+$/$suff/;
	}
	return $name;
}

sub _translate_path  {
	my $self=shift;
	my $path=defined $self->{PATH} ? $self->{PATH} : $self->{NAME};
	my %params=@_;
	$path=nvl($params{ROOT_TABLE_NAME},'ROOT') if $path eq '/';
	$path=~s/\//_/g;
	$path=~s/^_//;
	$path=~s/-/_/g;
	return $path;
}

sub _reduce_sql_name {
	my $self=shift;
	my $name=shift;
	my %params=@_;
	my $maxsize=$self->get_name_maxsize;
	my @s=split('_',$name);
	for my $s(@s) {
		$s=~s/([A-Z])[a-z0-9]+/$1/g;
		my $t=join('_',@s);
		return $t if  length($t) <= $maxsize;
	}
	return substr(join('_',@s),0,$maxsize);
}

sub get_sql_name {
	my $self=shift;
	my %params=@_;
	return $self->{SQL_NAME} if defined $self->{SQL_NAME};
	my $l=$params{TABLENAME_LIST};
	croak "param TABLENAME_LIST not defined" unless defined $l;
	my $name= $self->_translate_path(%params);

	$name=$self->_reduce_sql_name($name) if length($name) > $self->get_name_maxsize();
	if (exists $l->{$name}) {
		$name=$self->_adjdup_sql_name($name,%params);
		confess "'$name' duplicate" if exists $l->{$name};
	}
	$l->{$name}=undef;
	$self->{SQL_NAME}=$name;
	return $name;
}

sub _get_constraint_suffix { 
	my $self=shift;
	my $type=shift;
	my %params=@_;
	return '_'.$type;
}

sub get_constraint_name {
	my $self=shift;
	my $type=shift;
	my %params=@_;
	return $self->{SQL_CONSTRAINT}->{$type} if defined $self->{SQL_CONSTRAINT}->{$type}; 
	my $l=$params{CONSTRAINT_LIST};
	croak "param CONSTRAINT_LIST not defined" unless defined $l;
	my $pk_suffix=$self->_get_constraint_suffix($type,%params);
	my $table_name=$self->get_sql_name(TABLENAME_LIST => {});
	my $pt=substr($table_name,0,$self->get_name_maxsize - length($pk_suffix));
	if (exists $l->{$type}->{$pt}) {
		$pt=$self->_adjdup_sql_name($pt,TABLENAME_LIST => $l->{$type});
		confess "'$pt' duplicate" if exists $l->{$type}->{$pt};
	}
	$l->{$type}->{$pt}=undef;
	return $self->{SQL_CONSTRAINT}->{$type}=$pt.$pk_suffix;
}

sub get_path_resolved {
	my $self=shift;
	return defined $self->{PATH} ? $self->{PATH} : $self->{NAME}
}

1;



__END__


=head1  NAME

blx::xsdsql::xml::generic::table -  a generic table class 

=cut

=head1 SYNOPSIS

use blx::xsdsql::xml::generic::table

=cut


=head1 DESCRIPTION

this package is a class - instance it with the method new


=head1 FUNCTIONS

this module defined the followed functions



new  - contructor

	PARAMS: 
		COLUMNS  - a pointer too an array of  column objects (default [])
		CHILD_TABLES - pointer too an array of table objects (default [])
		XSD_SEQ  - a XSD_SEQ start number  (default 0)
		TABLE_IS_TYPE - the table is associated with type (simple or complex) (default false)
		SIMPLE_TYPE - the table is associated with a simple type  (default false)
		MINOCCURS - the table as a minoccurs  (default 0)
		MAXOCCURS - the table as a maxoccurs (default 1)
		PATH    - a node path name (default not defined)
		TYPE - a internal node type (default not defined)
		NAME - a node name (default not defined)


add_columns - add columns to a table
		
	the method return a self object


get_columns - return an array of columns object

add_child_tables - add child tables to a table

	the method return a self object


resolve_path_for_table_type - if the table is associated with a type use this  method to return the real path associated

	the method return a string
  
find_columns  - find columns that  match the pairs attributes => value

	the method return an array of columns object


get_child_tables  - return an array of child table


	
set_attrs_value   - set a value of attributes

	the arguments are a pairs NAME => VALUE	
	the method return a self object



get_attrs_value  - return a list  of attributes values

	the arguments are a list of attributes name


get_sql_name  - return the sql name


get_constraint_name  - return a constraint name 

	the first argument must be pk (primary key)


get_path_resolved  - return a resolved path name associated 



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
