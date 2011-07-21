package blx::xsdsql::xml::generic::table;

use strict;
use warnings;
use integer;
use blx::xsdsql::ut qw(nvl);
use File::Basename;

use base qw(blx::xsdsql::xml::generic::catalog);
use Carp;

use constant {
		DEFAULT_ROOT_TABLE_NAME	=> 'ROOT'
};

our %_ATTRS_R=( 
			NAME   => sub {
							my $self=shift;
							return defined $self->{PATH} ? basename($self->{PATH}) : $self->{NAME};
			}							
			,TYPES => sub {
							my $self=shift;
							my $t=nvl($self->{TYPES},[]); 
							return wantarray ? @{$t} : $t;
			}
			,MINOCCURS	=> sub {
							my $self=shift;
							return nvl($self->{MINOCCORS},0);
			}
			,MAXOCCURS  => sub {
							my $self=shift;
							return nvl($self->{MAXOCCURS},1);
			}
			,XSD_SEQ	=> sub {
							my $self=shift;
							return nvl($self->{XSD_SEQ},0);
			}
			,TABLE_IS_TYPE	=> sub {
							my $self=shift;
							return $self->{TABLE_IS_TYPE} ? 1 : 0;
			}
			,SIMPLE_TYPE	=> sub {
							my $self=shift;
							return $self->{SIMPLE_TYPE} ? 1 : 0;
			}
			,CHOICE			=> sub {
							my $self=shift;
							return $self->{CHOICE} ? 1 : 0;
			}
			,GROUP_TYPE		=> sub {
							my $self=shift;
							return $self->{GROUP_TYPE} ? 1 : 0;
			}
			,DEEP_LEVEL			=> sub {
							my $self=shift;
							return $self->{DEEP_LEVEL}
			}
			,INTERNAL_REFERENCE => sub {
							my $self=shift;
							return $self->{INTERNAL_REFERENCE} ? 1 : 0;
			}
);

our %_ATTRS_W=();

sub new {
	my ($class,%params)=@_;
	$params{COLUMNS}=[] unless  defined $params{COLUMNS};
	$params{CHILD_TABLES}=[] unless defined $params{CHILD_TABLES}; 
	$params{XSD_SEQ}=0 unless defined $params{XSD_SEQ}; 
	return bless(\%params,$class);
}

sub add_columns {
	my $self=shift;
	my $table_name=$self->get_sql_name;
	my $cols=$self->get_attrs_value qw(COLUMNS);
	my %cl=map {  (uc($_->get_sql_name),1); } @$cols;
	my @newcols=();
	for my $col(@_) {
		$col->set_attrs_value(COLUMN_SEQUENCE => scalar(@$cols) + scalar(@newcols),TABLE_NAME => $table_name);
		$col->get_sql_name(COLUMNNAME_LIST => \%cl,FORCE => 1); #resolve sql_name
		push @newcols,$col;
	}
	push @$cols,@newcols;
	return $self;
}

sub reset_columns {
	my ($self,%params)=@_;
	my $cols=[];
	my $oldcols=defined wantarray ? $self->get_attrs_value('COLUMNS') : undef;
	$self->set_attrs_value(COLUMNS => $cols);
	return wantarray ? @$oldcols : $oldcols;
}

sub get_columns {
	my ($self,%params)=@_;
	my $v=$self->get_attrs_value qw(COLUMNS);
	return wantarray ? @$v : $v;
}

sub add_child_tables {
	my $self=shift;
	push @{$self->{CHILD_TABLES}},@_;
	return $self;
}

sub _is_column_group_ref {
	my ($self,$col,$path_orig,%params)=@_;
	my $v=$col->get_attrs_value qw(PATH);
	my $table_ref=$col->get_attrs_value qw(TABLE_REFERENCE);
	my $table_path=$table_ref->get_attrs_value qw(PATH);
	for my $c($table_ref->get_columns) {
		my $path=$c->get_attrs_value qw(PATH);
		$path='/'.$c->get_attrs_value qw(NAME) unless defined $path;
		next unless defined $path;
		$path=~s/^$table_path//;
		return 1 if $v.$path eq $path_orig;
		
	}	
	return 0;
}

sub find_columns {
	my ($self,%params)=@_;
	my $cols=$self->get_columns;
	return wantarray ? () : undef if scalar(keys %params) == 0;
	my @r=map {
		my $col=$_;
		(grep {
			my $r=undef;
			my $param_value=$params{$_};
			my $v=$col->get_attrs_value($_);
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
	blx::xsdsql::ut::set_attrs_value($self,\%_ATTRS_W,@_);
	return $self;
}

sub get_attrs_value {
	my $self=shift;
	return blx::xsdsql::ut::get_attrs_value($self,\%_ATTRS_R,@_);
}

sub _adjdup_sql_name {
	my ($self,$name,%params)=@_;
	my $suff_digits=nvl($params{SUFF_DIGITS},1);
	confess "$name: length <= $suff_digits\n" if length($name) <= $suff_digits;  
	$name=substr($name,0,length($name) - $suff_digits).('0'x$suff_digits);
	confess "param TABLENAME_LIST not defined" unless defined $params{TABLENAME_LIST}; 
	my $l=$params{TABLENAME_LIST};
	while(1) {
		last unless exists $l->{uc($name)};
		my ($suff)=$name=~/(\d{$suff_digits})$/;
		++$suff;
		return $self->_adjdup_sql_name($name,%params,SUFF_DIGITS => $suff_digits + 1) if $suff >= 10 ** $suff_digits;
		$name=~s/\d{$suff_digits}$/$suff/;
	}
	return $name;
}

sub _translate_path  {
	my ($self,%params)=@_;
	my $path=defined $self->{PATH} ? $self->{PATH} : $self->{NAME};
	$path=nvl($params{ROOT_TABLE_NAME},DEFAULT_ROOT_TABLE_NAME) if $path eq '/';
	$path=~s/\//_/g;
	$path=~s/^_//;
	$path=~s/-/_/g;
	$path=$params{VIEW_PREFIX}.'_'.$path if $params{VIEW_PREFIX};
	$path=$params{TABLE_PREFIX}.'_'.$path if $params{TABLE_PREFIX};
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
	for my $i(0..scalar(@s) - 1) {
		next if $i == 0 && $params{TABLE_PREFIX}; #not reduce the table prefix
		next if $i == 0 && $params{VIEW_PREFIX}; #not reduce  the view prefix
		$s[$i]=~s/([A-Z])[a-z0-9]+/$1/g;
		my $t=join('_',@s);
		return $t if  length($t) <= $maxsize;
	}
	return substr(join('_',@s),0,$maxsize);
}

sub _inc_xsd_seq {
	my ($self,%params)=@_;
	++$self->{XSD_SEQ};
	return $self;
}

sub is_type {
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(TABLE_IS_TYPE);
}

sub is_simple_type {
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(SIMPLE_TYPE);
}

sub is_group_type {
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(GROUP_TYPE);
}

sub is_choice {
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(CHOICE);	
}	

sub get_path {
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(PATH);
}

sub get_min_occurs { 
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(MINOCCURS);
}

sub get_max_occurs { 
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(MAXOCCURS);
}

sub get_xsd_seq {
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(XSD_SEQ);
}

sub get_sql_name {
	my ($self,%params)=@_;
	return $self->{SQL_NAME} if defined $self->{SQL_NAME};
	my $l=$params{TABLENAME_LIST};
	croak "param TABLENAME_LIST not defined" unless defined $l;
	delete $params{VIEW_PREFIX}; #only for views
	my $name= $self->_translate_path(%params);
	$name=$self->_reduce_sql_name($name,%params) if length($name) > $self->get_name_maxsize();
	$name=$self->_resolve_invalid_name($name,%params);
	if (exists $l->{uc($name)}) {
		$name=$self->_adjdup_sql_name($name,%params);
		confess "'$name' duplicate" if exists $l->{uc($name)};
	}
	$l->{uc($name)}=undef;
	$self->{SQL_NAME}=$name;
	return $name;
}

sub get_view_sql_name {
	my ($self,%params)=@_;
	return $self->{VIEW_SQL_NAME} if defined $self->{VIEW_SQL_NAME};
	my $l=$params{TABLENAME_LIST};
	croak "param TABLENAME_LIST not defined" unless defined $l;
	delete $params{TABLE_PREFIX};
	my $name= $self->_translate_path(%params);
	$name=$self->_reduce_sql_name($name,%params) if length($name) > $self->get_name_maxsize();
	if (exists $l->{uc($name)}) {
		$name=$self->_adjdup_sql_name($name,%params);
		confess "'$name' duplicate" if exists $l->{uc($name)};
	}
	$l->{uc($name)}=undef;
	$self->{VIEW_SQL_NAME}=$name;
	return $name;
}


sub _get_constraint_suffix { 
	my ($self,$type,%params)=@_;
	return '_'.$type;
}

sub get_constraint_name {
	my ($self,$type,%params)=@_;
	return $self->{SQL_CONSTRAINT}->{$type} if defined $self->{SQL_CONSTRAINT}->{$type}; 
	my $l=$params{CONSTRAINT_LIST};
	croak "param CONSTRAINT_LIST not defined" unless defined $l;
	my $pk_suffix=$self->_get_constraint_suffix($type,%params);
	my $table_name=$self->get_sql_name(%params,TABLENAME_LIST => undef);
	my $pt=substr($table_name,0,$self->get_name_maxsize - length($pk_suffix));
	if (exists $l->{$type}->{uc($pt)}) {
		$pt=$self->_adjdup_sql_name($pt,%params,TABLENAME_LIST => $l->{$type});
		confess "'$pt' duplicate" if exists $l->{$type}->{uc($pt)};
	}
	$l->{$type}->{uc($pt)}=undef;
	return $self->{SQL_CONSTRAINT}->{$type}=$pt.$pk_suffix;
}


sub get_sequence_name {
	my ($self,%params)=@_;
	return $self->{SEQ_SQL_NAME} if defined $self->{SEQ_SQL_NAME};
	my $l=$params{TABLENAME_LIST};
	croak "param TABLENAME_LIST not defined" unless defined $l;
	delete $params{VIEW_PREFIX}; #only for views
	$params{TABLE_PREFIX}=$params{SEQUENCE_PREFIX};
	my $name= $self->_translate_path(%params);
	$name=$self->_reduce_sql_name($name,%params) if length($name) > $self->get_name_maxsize();
	if (exists $l->{uc($name)}) {
		$name=$self->_adjdup_sql_name($name,%params);
		confess "'$name' duplicate" if exists $l->{$name};
	}
	$l->{uc($name)}=undef;
	$self->{SEQ_SQL_NAME}=$name;
	return $name;
}


sub get_deep_level {
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(DEEP_LEVEL);
}

sub is_internal_reference {
	my ($self,%params)=@_;
	return $self->get_attrs_value qw(INTERNAL_REFERENCE);
}


sub get_pk_columns {
	my ($self,%params)=@_;
	my $cols=$self->get_columns;
	my @cols=($cols->[0]);
	push @cols,$cols->[1] if $cols->[1]->is_pk;
	confess "col not seq 0" unless  nvl($cols[0]->get_pk_seq,'-1') == 0;
	confess "col not seq 1"  unless  !defined $cols[1] || nvl($cols[1]->get_pk_seq,'-1') == 1;
	return wantarray ? @cols : \@cols;
} 

sub is_root_table {
	my ($self,%params)=@_;
	return nvl($self->get_attrs_value qw(PATH)) eq '/' ? 1 : 0;
}

sub is_unpath {
	my ($self,%params)=@_;
	return 0 if $self->get_attrs_value qw(PATH);
	return 1 if $self->get_max_occurs > 1;
	return 0;
}


sub get_parent_path {
	my ($self,%params)=@_;
	return $self->is_unpath ? $self->get_attrs_value qw(PARENT_PATH) : undef;
}


sub get_dictionary_data {
	my ($self,$dictionary_type,%params)=@_;
	croak "dictionary_type (1^ arg)  non defined" unless defined $dictionary_type;
	if ($dictionary_type eq 'TABLE_DICTIONARY') {
		my %data=(
			TABLE_NAME 					=> $self->get_sql_name
			,XSD_SEQ 					=> $self->get_xsd_seq
			,TYPE						=> ($self->is_simple_type ? 'S' : $self->is_type ? 'C' : undef)  
			,IS_GROUP					=> $self->is_group_type
			,IS_CHOICE					=> $self->is_choice
			,MIN_OCCURS					=> $self->get_min_occurs
			,MAX_OCCURS					=> $self->get_max_occurs
			,PATH_NAME					=> $self->get_attrs_value qw(PATH)
			,DEEP_LEVEL					=> $self->get_deep_level
			,PARENT_PATH				=> $self->get_parent_path
			,IS_ROOT_TABLE				=> $self->is_root_table
			,IS_UNPATH					=> $self->is_unpath
			,IS_INTERNAL_REF			=> $self->is_internal_reference
			,VIEW_NAME					=> $self->get_view_sql_name
		);
		return wantarray ? %data : \%data if scalar %data;
	}
	
	if ($dictionary_type eq 'RELATION_DICTIONARY') {
		my $count=0;
		my $name=$self->get_sql_name;
		my @data=map {
			{
				PARENT_TABLE_NAME	=> $name
				,CHILD_SEQUENCE		=> ${count}++
				,CHILD_TABLE_NAME	=> $_->get_sql_name
				
			}
		} $self->get_child_tables;
		return wantarray ? @data : \@data;
	}
	
	if ($dictionary_type eq 'COLUMN_DICTIONARY') {
		my @data=map { my $data=$_->get_dictionary_data qw(COLUMN_DICTIONARY); $data->{TABLE_NAME}=$self->get_sql_name; $data } $self->get_columns;
		return wantarray ? @data : \@data;	 
	}
	
	croak "$dictionary_type: invalid value";
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
		COLUMNS  			- a pointer too an array of  column objects (default [])
		CHILD_TABLES 		- pointer too an array of table objects (default [])
		XSD_SEQ  			- a XSD_SEQ start number 
		TABLE_IS_TYPE 		- the table is associated with type (simple or complex)
		SIMPLE_TYPE 		- the table is associated with a simple type
		GROUP_TYPE  		- the table is associated to an xsd group
		CHOICE 				- the table is associated to a choice
		MINOCCURS 			- the table as a minoccurs 
		MAXOCCURS 			- the table as a maxoccurs
		PATH    			- a node path name 
		TYPE 				- an internal node type
		NAME 				- a node name 
		DEEP_LEVEL			- a deep level - the root has level 0
		INTERNAL_REFERENCE  - if true the the table is an occurs of simple types
		TYPES  				- a pointer to an array of table types (only for root)
		PARENT_PATH			- a path of parent table if table path is not set
		TABLE_DICTIONARY 	- a pointer to table dictionary (only for root)
		COLUMN_DICTIONARY 	- a pointer to column dictionary (only for root)
		RELATION_DICTIONARY - a pointer to a relation dictionary (only for root)

		
add_columns - add columns to a table
 		
	the params are a list of columns
	the method return a self object


reset_columns - reset the columns of the table

	the method return  the columns


get_columns - return an array of columns object


add_child_tables - add child tables to a table

	the params are a list of tables
	the method return a self object

 
find_columns  - find columns that  match the pairs attributes => value

	the method return an array of columns object


get_child_tables  - return an array of child tables

	
set_attrs_value   - set a value of attributes

	the arguments are a pairs NAME => VALUE	
	the method return a self object



get_attrs_value  - return a list  of attributes values

	the arguments are a list of attributes name


get_sql_name  - return the sql name


get_constraint_name  - return a constraint name 

	the first argument must be the constant 'pk' (primary key)


get_pk_columns - return the primary key columns


is_type	- return true if the table is associated to a xsd type


is_simple_type - return true if the table is associated to a xsd simple type


is_choice - return true if the table is associated to a xsd choice


get_xsd_seq - return the  start xsd sequence 


get_min_occurs - return the min occurs of the table


get_max_occurs - return the max occurs of the table


get_path	- return the xml path associated with table


get_dictionary_data - return an hash of dictionary column name => value for the insert into dictionary
	
	the first argument must be:
		TABLE_DICTIONARY - return data for table dictionary
		RELATION_DICTIONARY - return data for relation dictionary
		COLUMN_DICTIONARY - return data for column dictionary


get_deep_level - return the deep level - the root has level 0


is_internal_reference - return  true if the the table is an occurs of simple types


is_unpath - return true if the table is not associated to a path


get_parent_path - return the parent path if is_unpath is true



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
