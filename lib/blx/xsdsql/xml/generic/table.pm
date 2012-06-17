package blx::xsdsql::xml::generic::table;

use strict;
use warnings;
use integer;
use Carp;
use File::Basename;

use blx::xsdsql::ut('nvl');
#use base qw(blx::xsdsql::xml::generic::catalog);

use base qw(blx::xsdsql::xml::generic::catalog blx::xsdsql::xml::generic::name_generator);

use constant {
		DEFAULT_ROOT_TABLE_NAME	=> 'ROOT'
};


use base('Exporter'); 


my  %t=( overload => [ qw (
	XSD_TYPE_SIMPLE
	XSD_TYPE_COMPLEX
	XSD_TYPE_SIMPLE_CONTENT
	XSD_TYPE_GROUP
) ]);

our %EXPORT_TAGS=( all => [ map { @{$t{$_}} } keys %t ],%t); 
our @EXPORT_OK=( @{$EXPORT_TAGS{all}} );
our @EXPORT=qw( );


use constant {  
	XSD_TYPE_SIMPLE				=>  'ST'
	,XSD_TYPE_COMPLEX			=>  'CT'
	,XSD_TYPE_SIMPLE_CONTENT	=>  'SCT'
	,XSD_TYPE_GROUP				=>  'GT'
};

sub _ob {
	confess $_[0].": obsolete\n";
}

our %_ATTRS_R=( 
			NAME   				=> sub { my $p=$_[0]->{PATH}; return defined $p ? basename($p) : $_[0]->{NAME}; }							
			,TYPES 				=> sub { my $t=nvl($_[0]->{TYPES},[]); return wantarray ? @$t : $t; }
			,MINOCCURS			=> sub { return nvl($_[0]->{MINOCCORS},0); }
			,MAXOCCURS  		=> sub { return nvl($_[0]->{MAXOCCURS},1); }
			,XSD_SEQ			=> sub { return nvl($_[0]->{XSD_SEQ},0); }
			,TABLE_IS_TYPE		=> sub { _ob(__LINE__); my $t=$_[0]->get_attrs_value(qw(XSD_TYPE)); return defined $t ? 1 : 0; }
			,SIMPLE_TYPE		=> sub { _ob(__LINE__); my $t=$_[0]->get_attrs_value(qw(XSD_TYPE)); return defined $t && $t eq XSD_TYPE_SIMPLE ? 1 : 0; }
			,CHOICE				=> sub { return $_[0]->{CHOICE} ? 1 : 0; }
			,GROUP_TYPE			=> sub { _ob(__LINE__); my $t=$_[0]->get_attrs_value(qw(XSD_TYPE)); return defined $t && $t eq XSD_TYPE_GROUP ? 1 : 0; }
			,COMPLEX_TYPE		=> sub { _ob(__LINE__); my $t=$_[0]->get_attrs_value(qw(XSD_TYPE)); return defined $t && $t eq XSD_TYPE_COMPLEX ? 1 : 0; }
			,SIMPLE_CONTENT_TYPE	=>	sub { _ob(__LINE__); my $t=$_[0]->get_attrs_value(qw(XSD_TYPE)); return defined $t && $t eq XSD_TYPE_SIMPLE_CONTENT ? 1 : 0; }
			,SIMPLE_CONTENT		=> sub { _ob(__LINE__); }
			,INTERNAL_REFERENCE => sub { return $_[0]->{INTERNAL_REFERENCE} ? 1 : 0; }
			,DEEP_LEVEL			=> sub { 
											if (defined (my $xpath=$_[0]->{PATH})) {
												my @a=grep(length($_),split('/',$xpath));
												return scalar(@a);
											}
											return undef;
			}
);

our %_ATTRS_W=(
		COLUMNS					=> sub {  croak " use add_columns method to add columns\n"; }
		,SYSATTRS_COL			=> sub {  croak " use add_columns method to add system attributes column\n"; }
);

sub _get_attrs_w { return \%_ATTRS_W; }
sub _get_attrs_r { return \%_ATTRS_R; }

sub _translate_path  {
	my ($self,%params)=@_;
	my $path=defined $self->{PATH} ? $self->{PATH} : $self->{NAME};
	confess "internal error - path or name not set\n" unless defined $path;
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
	confess "abstract method\n";
	return $name;
}

sub _reduce_sql_name {
	my ($self,$name,$maxsize,%params)=@_;
	my @s=split('_',$name);
	for my $i(0..scalar(@s) - 1) {
		next if $i == 0  && (defined $params{TABLE_PREFIX} || defined $params{VIEW_PREFIX}); # not reduce  the prefix
		$s[$i]=~s/([A-Z])[a-z0-9]+/$1/g;
		my $t=join('_',@s);
		return $t if  length($t) <= $maxsize;
	}
	return substr(join('_',@s),0,$maxsize);
}

sub _set_sql_name {
	my ($self,%params)=@_;
	my $name=$self->_gen_name(
				ROOT_TABLE_NAME	=> $params{ROOT_TABLE_NAME}
				,TABLE_PREFIX	=> $params{TABLE_PREFIX}
				,TY 	=> 't'
				,LIST 	=> $params{TABLENAME_LIST}
				,NAME 	=> $self->get_attrs_value(qw(NAME))
				,PATH	=> $self->get_attrs_value(qw(PATH))
	);
	return $self->{SQL_NAME}=$name;
}


sub _set_constraint_name {
	my ($self,$type,%params)=@_;
	my $pk_suffix=$self->_get_constraint_suffix($type,%params);
	my $table_name=$self->get_sql_name;
	my $maxsize=$self->get_name_maxsize;
	my $pt=substr($table_name,0,$maxsize - length($pk_suffix));

	my $name=$self->_gen_name(
				TY 				=> 't'
				,LIST 			=> $params{TABLENAME_LIST}
				,NAME 			=> $pt
				,MAXSIZE 		=> $maxsize - length($pk_suffix)
				,TABLE_PREFIX	=> $params{TABLE_PREFIX}
	);
	return $self->{SQL_CONSTRAINT}->{$type}=$name.$pk_suffix;
}


sub _set_sequence_name {
	my ($self,%params)=@_;
	my $name=$self->_gen_name(
				TY 				=> 't'
				,LIST 			=> $params{TABLENAME_LIST}
				,PATH			=> $self->get_path
				,TABLE_PREFIX 	=> $params{SEQUENCE_PREFIX}
	);

	return $self->{SEQ_SQL_NAME}=$name;
}


sub _set_view_sql_name {
	my ($self,%params)=@_;

	my $name=$self->_gen_name(
				TY 				=> 't'
				,LIST 			=> $params{TABLENAME_LIST}
				,VIEW_PREFIX 	=> $params{VIEW_PREFIX}
				,NAME 			=> $self->get_attrs_value(qw(NAME))
				,PATH			=> $self->get_attrs_value(qw(PATH))
	);
	return $self->{VIEW_SQL_NAME}=$name;
}

sub _inc_xsd_seq {
	my ($self,%params)=@_;
	++$self->{XSD_SEQ};
	return $self;
}

sub _get_constraint_suffix { 
	my ($self,$type,%params)=@_;
	return '_'.$type;
}

sub _check_obsolete_params {
	my $self=shift;
	for my $a(@_) {
		if (grep($_ eq $a,qw(TABLE_IS_TYPE SIMPLE_TYPE SIMPLE_CONTENT_TYPE SIMPLE_CONTENT COMPLEX_TYPE GROUP_TYPE))) {
			confess "$a:  obsolete param\n";
		}
	}
	return $self;
}

sub _is_column_group_ref {
	my ($self,$col,$path_orig,%params)=@_;
	my $v=$col->get_attrs_value(qw(PATH));
	my $table_ref=$col->get_attrs_value(qw(TABLE_REFERENCE));
	my $table_path=$table_ref->get_attrs_value(qw(PATH));
	for my $c($table_ref->get_columns) {
		my $path=$c->get_attrs_value(qw(PATH));
		$path='/'.$c->get_attrs_value(qw(NAME)) unless defined $path;
		next unless defined $path;
		$path=~s/^$table_path//;
		return 1 if $v.$path eq $path_orig;
		
	}	
	return 0;
}


sub _add_child_tables {
	my $self=shift;
	push @{$self->{CHILD_TABLES}},grep (defined $_,@_);
	return $self;
}

sub _delete_child_tables {
	my $self=shift;
	for my $index(@_) {
		croak "index not defined\n" unless defined $index;
		croak "$index: index not numeric\n" unless $index=~/^[+-]{0,1}\d+$/;
		$self->{CHILD_TABLES}->[$index]=undef;
	}
	my @childs=grep(defined $_,@{$self->{CHILD_TABLES}});
	$self->{CHILD_TABLES}=\@childs;
	return $self;
}

sub _add_columns {
	my $self=shift;
	confess "before add a column please set the table name\n" unless defined $self->get_attrs_value(qw(SQL_NAME));
	my $table_name=$self->get_sql_name;
	my $cols=$self->get_attrs_value(qw(COLUMNS));
	my @newcols_notattrs=();
	my @newcols_attrs=();
	for my $col(@$cols) {
		if ($col->get_attrs_value(qw(ATTRIBUTE)) || $col->get_attrs_value(qw(SYS_ATTRIBUTES))) {
			push @newcols_attrs,$col;
		}
		else {
			push @newcols_notattrs,$col;
		}
	}
	for my $col(@_) {
		if ($col->get_attrs_value(qw(ATTRIBUTE)) || $col->get_attrs_value(qw(SYS_ATTRIBUTES))) {
			push @newcols_attrs,$col;
			if ($col->get_attrs_value(qw(SYS_ATTRIBUTES))) {
				croak $self->get_sql_name.": multiply sysattrs column not allowed\n"
					if defined $self->get_attrs_value(qw(SYSATTRS_COL));
				$self->{SYSATTRS_COL}=$col;
			}
		}
		else {
			push @newcols_notattrs,$col;
		}
	}
	my @newcols_merge=();
	my $col_seq=0;
	my %cl=();
	for my $col(@newcols_notattrs) {
		$col->set_attrs_value(COLUMN_SEQUENCE => $col_seq++,TABLE_NAME => $table_name);
		$col->_set_sql_name(COLUMNNAME_LIST => \%cl); #resolve sql_name
		push @newcols_merge,$col;
	}
	for my $col(@newcols_attrs) {
		$col->set_attrs_value(COLUMN_SEQUENCE => $col_seq++,TABLE_NAME => $table_name);
		$col->_set_sql_name(COLUMNNAME_LIST => \%cl); #resolve sql_name
		push @newcols_merge,$col;
	}
	$self->{COLUMNS}=\@newcols_merge;
	return $self;
}

sub _reset_columns {
	my ($self,%params)=@_;
	my $oldcols=$self->{COLUMNS};
	$self->{COLUMNS}=[];
	delete $self->{SYSATTRS_COL};
	return wantarray ? @$oldcols : $oldcols;
}

sub _new {
	my ($class,%params)=@_;
	for my $k (qw(COLUMNS SYSATTRS_COL)) {
		croak "param $k not allowed in constructor\n" if defined $params{$k};
	}
	$params{CHILD_TABLES}=[] unless defined $params{CHILD_TABLES}; 
	$params{XSD_SEQ}=0 unless defined $params{XSD_SEQ};
	my $self=bless(\%params,$class);
	$self->_check_obsolete_params(keys %params);
	$self->{COLUMNS}=[];
	return $self;
}

sub get_columns {
	my ($self,%params)=@_;
	my $v=$self->get_attrs_value('COLUMNS');
	return wantarray ? @$v : $v;
}

	
sub get_child_tables {
	my $self=shift;
	my $v=$self->get_attrs_value('CHILD_TABLES');
	return wantarray ? @$v : $v;
}

sub is_type {
	my ($self,%params)=@_;
	return $_[0]->get_attrs_value(qw(XSD_TYPE)) ? 1 : 0; 
}

sub is_complex_type {
	my ($self,%params)=@_;
	return nvl($self->get_attrs_value(qw(XSD_TYPE))) eq XSD_TYPE_COMPLEX ? 1 : 0;
}

sub is_simple_type {
	my ($self,%params)=@_;
	return nvl($self->get_attrs_value(qw(XSD_TYPE))) eq XSD_TYPE_SIMPLE ? 1 : 0;
}

sub is_simple_content_type {
	my ($self,%params)=@_;
	return nvl($self->get_attrs_value(qw(XSD_TYPE))) eq XSD_TYPE_SIMPLE_CONTENT ? 1 : 0;
}


sub is_group_type {
	my ($self,%params)=@_;
	return nvl($self->get_attrs_value(qw(XSD_TYPE))) eq XSD_TYPE_GROUP ? 1 : 0;
}

sub is_choice {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(CHOICE));	
}	

sub get_path {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(PATH));
}

sub get_min_occurs { 
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(MINOCCURS));
}

sub get_max_occurs { 
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(MAXOCCURS));
}

sub get_xsd_seq {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(XSD_SEQ));
}

sub get_xsd_type {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(XSD_TYPE));
}

sub get_sql_name {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(SQL_NAME));
}


sub get_view_sql_name {
	my ($self,%params)=@_;
	return $self->get_attrs_value(qw(VIEW_SQL_NAME));
}


sub get_constraint_name {
	my ($self,$type,%params)=@_;
	return $self->{SQL_CONSTRAINT}->{$type};
}


sub get_sequence_name {
	my ($self,%params)=@_;
	return $self->{SEQ_SQL_NAME}; 
}

sub get_deep_level {
	my ($self,%params)=@_;
	return $self->get_attrs_value('DEEP_LEVEL');
}

sub is_internal_reference {
	my ($self,%params)=@_;
	return $self->get_attrs_value('INTERNAL_REFERENCE');
}


sub get_pk_columns {
	my ($self,%params)=@_;
	my $cols=$self->get_columns;
	my @cols=($cols->[0]);
	push @cols,$cols->[1] if defined $cols->[1] && $cols->[1]->is_pk;
	unless  (nvl($cols[0]->get_pk_seq,'-1') == 0) {
		$self->_debug(__LINE__.'col without seq number == 0 for column ',$cols[0]->get_full_name,' ',$cols[0]);
		confess "internal error\n";
	}
	confess "col not seq 1"  unless  !defined $cols[1] || nvl($cols[1]->get_pk_seq,'-1') == 1;
	return wantarray ? @cols : \@cols;
} 

sub is_root_table {
	my ($self,%params)=@_;
	return nvl($self->get_attrs_value('PATH')) eq '/' ? 1 : 0;
}

sub is_unpath {
	my ($self,%params)=@_;
	return 0 if $self->get_attrs_value('PATH');
	return 1 if $self->get_max_occurs > 1;
	return 0;
}


sub get_parent_path {
	my ($self,%params)=@_;
	return $self->is_unpath ? $self->get_attrs_value('PARENT_PATH') : undef;
}

sub get_URI { 
	my ($self,%params)=@_;
	return $self->get_attrs_value('URI');
} 

sub get_sysattrs_column { 
	my ($self,%params)=@_;
	return $self->get_attrs_value('SYSATTRS_COL');
}


sub get_dictionary_data {
	my ($self,$dictionary_type,%params)=@_;
	croak "dictionary_type (1^ arg)  non defined" unless defined $dictionary_type;

	if ($dictionary_type eq 'TABLE_DICTIONARY') {
		my %data=(
			table_name 					=> $self->get_sql_name
			,URI						=> $self->get_URI
			,xsd_seq 					=> $self->get_xsd_seq
			,min_occurs					=> $self->get_min_occurs
			,max_occurs					=> $self->get_max_occurs
			,path_name					=> $self->get_path
			,deep_level					=> $self->get_deep_level
			,parent_path				=> $self->get_parent_path
			,is_root_table				=> ($self->is_root_table ? 'Y' : undef)
			,is_unpath					=> ($self->is_unpath   ? 'Y' : undef)
			,is_internal_ref			=> ($self->is_internal_reference ? 'Y' : undef)
			,view_name					=> $self->get_view_sql_name
			,xsd_type					=> $self->get_xsd_type 
			,is_group_type				=> ($self->is_group_type ? 'Y' : undef)
			,is_complex_type			=> ($self->is_complex_type ? 'Y' : undef)
			,is_simple_type				=> ($self->is_simple_type ? 'Y' : undef)
			,is_simple_content_type		=> ($self->is_simple_content_type ? 'Y' : undef)
		);
		return wantarray ? %data : \%data; # if scalar %data;
	}
	
	if ($dictionary_type eq 'RELATION_DICTIONARY') {
		my $count=0;
		my $name=$self->get_sql_name;
		my @data=map {
			{
				parent_table_name	=> $name
				,child_sequence		=> ${count}++
				,child_table_name	=> $_->get_sql_name
				
			}
		} $self->get_child_tables;
		return wantarray ? @data : \@data;
	}
	
	if ($dictionary_type eq 'COLUMN_DICTIONARY') {
		my @data=map { my $data=$_->get_dictionary_data('COLUMN_DICTIONARY'); $data->{table_name}=$self->get_sql_name; $data } $self->get_columns;
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
		XSD_TYPE			- xsd type - see XSD_TYPE_* constants 
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

		

get_columns - return an array of columns object

 
get_child_tables  - return an array of child tables


get_sql_name  - return the sql name


get_constraint_name  - return a constraint name 

	the first argument must be the constant 'pk' (primary key)


get_pk_columns - return the primary key columns


is_type	- return true if the table is associated to a xsd type


is_simple_type - return true if the table is associated to a xsd simple type


is_complex_type - return true if the table is associated to a xsd complex type


is_simple_content_type - return true if the table is associated to a xsd simple content type


is_group_type	- return true if the table is associated to a xsd group type


is_choice - return true if the table is associated to a xsd choice


is_internal_reference - return  true if the the table is an occurs of simple types


is_unpath - return true if the table is not associated to a path


get_xsd_seq - return the  start xsd sequence 


get_xsd_type - return the xsd type og the object - see the constants XSD_TYPE_*


get_min_occurs - return the min occurs of the table


get_max_occurs - return the max occurs of the table


get_path	- return the xml path associated with table


get_dictionary_data - return an hash of dictionary column name => value for the insert into dictionary
	
	the first argument must be:
		TABLE_DICTIONARY - return data for table dictionary
		RELATION_DICTIONARY - return data for relation dictionary
		COLUMN_DICTIONARY - return data for column dictionary


get_deep_level - return the deep level - the root has level 0


get_parent_path - return the parent path if is_unpath is true



=head1 EXPORT

None by default.


=head1 EXPORT_OK
	
none 

=head1 SEE ALSO

See blx::xsdsql::xml::generic::catalog, it's the base class

See blx:.xsdsql::generator for generate the schema of the database and blx::xsdsql::xsd_parser 
for parse a xsd file (schema file)


=head1 AUTHOR

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIG 

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
