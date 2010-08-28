package blx::xsdsql::parser;

use strict;
use warnings;
use integer;
use Rinchi::XMLSchema;
use Carp;
use blx::xsdsql::ut qw(nvl ev);

use constant {
			 DEFAULT_OCCURS_TABLE_PREFIX 	=> 'm_'
			,UNBOUNDED						=> 2 ** 32
			,XS_STRING_TYPE					=> 'string  normalizedString  token  base64Binary  hexBinary duration ID IDREF  IDREFS  NMTOKEN NMTOKENS language Name QName NCName anyURI' 
			,XS_INTEGER_TYPE				=> 'integer integer  nonPositiveInteger  negativeInteger  long  int  short  byte  nonNegativeInteger  unsignedLong  unsignedInt  unsignedShort  unsignedByte  positiveInteger'
			,XS_DOUBLE_TYPE				=> 'double'
			,XS_FLOAT_TYPE				    => 'float'
			,XS_DECIMAL_TYPE				=> 'decimal'
			,XS_DATETIME_TYPE			=> 'dateTime'
			,XS_DATE_TYPE			        => 'date'
			,XS_TIME_TYPE			        => 'time'
			,XS_GYEAR_TYPE			        => 'gYear'
			,XS_GYEARMONTH_TYPE		 => 'gYearMonth'
			,XS_GMONTHDAY_TYPE		 => 'gMonthDay'
			,XS_BOOLEAN_TYPE             => 'boolean'
			,SIMPLE_TYPE_CLASS			=> 'blx::xsdsql::xml::simple_type'
			,STRING_MAXSIZE               =>  2**32
			,XML_STD_NAMESPACES      =>  'xs xsd' 
};


sub _get_type {
	my $parent=shift;
	my $r=ref($parent);
	my %type=();
	$type{RESTRICTIONS}=[];
	if ($r =~/::SimpleType$/) {
		for my $e(@{$parent->{_content_}}) {
			my $r=ref($e); 
			if ($r  =~/::Restriction$/) {
				$type{BASE}=$e->base();
			}
			else {
				die $r;
			}
			for my $f(@{$e->{_content_}}) {
				my $r=ref($f);
				my ($b)=$r=~/:([^:]+)$/;
				my  %t=();
				$t{TYPE}=$b if defined $b;
				$t{VALUE}=$f->{_value} if defined $f->{_value};
				if (scalar(keys(%t)) > 0) {
					push @{$type{RESTRICTIONS}},\%t;
				}
			}
		}
	}
	else {
		confess  $r.": not simple type";
	}	
	return \%type;	
}


sub _get_simple_type_x {
	my $h=shift;
	my %params=@_;
	confess "not base defined " unless defined $h->{BASE};
	confess "self param not set " unless defined $params{SELF};
	my ($xml_ns,$base)=  $h->{BASE}=~/^([^:]+):([^:]+)$/  ?   ($1,$2) : ('',$h->{BASE});

	if (grep($_ eq $xml_ns,split(/\s+/,XML_STD_NAMESPACES))) {
		if (grep($_ eq $base, split(/\s+/,XS_STRING_TYPE ))) {
			my @enum=map { $_->{VALUE} } grep ($_->{TYPE} eq 'Enumeration',@{$h->{RESTRICTIONS}});
			$h->{SQL_ENUM}=\@enum if scalar(@enum) > 0;
			my $maxsize = ( map { $_->{VALUE} } grep ($_->{TYPE} eq 'MaxLength',@{$h->{RESTRICTIONS}}))[0];
			my $size = ( map { $_->{VALUE} } grep ($_->{TYPE} eq 'Length',@{$h->{RESTRICTIONS}}))[0];
			if (defined $maxsize) {
				$h->{SQL_TYPE} = $params{SELF}->{ANONYMOUS_COLUMN}->factory_sql_type qw(VARCHAR);
				$h->{SQL_SIZE} = $maxsize;
			}
			elsif (defined $size) {
				$h->{SQL_TYPE} =$params{SELF}->{ANONYMOUS_COLUMN}->factory_sql_type qw(CHAR);
				$h->{SQL_SIZE} = $size;
			}
			else {
				my $maxsize=undef;
				for my $e(@enum) { $maxsize = length($e) if length($e) > nvl($maxsize,0); }
				$h->{SQL_TYPE} = $params{SELF}->{ANONYMOUS_COLUMN}->factory_sql_type qw(VARCHAR);
				$h->{SQL_SIZE}=$maxsize;
			}
		}
		elsif (grep($_ eq $base, split(/\s+/,XS_INTEGER_TYPE ))) {
				$h->{SQL_TYPE} = $params{SELF}->{ANONYMOUS_COLUMN}->factory_sql_type qw(NUMBER);
				$h->{SQL_SIZE} = ( map { $_->{VALUE} } grep ($_->{TYPE} eq 'TotalDigits',@{$h->{RESTRICTIONS}}))[0];
		}
		elsif (grep($_ eq $base, split(/\s+/,XS_DOUBLE_TYPE ))) {
				$h->{SQL_TYPE} = $params{SELF}->{ANONYMOUS_COLUMN}->factory_sql_type qw(DOUBLE);
		}  
		elsif (grep($_ eq $base, split(/\s+/,XS_FLOAT_TYPE ))) {
				$h->{SQL_TYPE} = $params{SELF}->{ANONYMOUS_COLUMN}->factory_sql_type qw(FLOAT);
		}  
		elsif (grep($_ eq $base, split(/\s+/,XS_DECIMAL_TYPE ))) {
				$h->{SQL_TYPE} = $params{SELF}->{ANONYMOUS_COLUMN}->factory_sql_type qw(DECIMAL);
		}  
		elsif (grep($_ eq $base, split(/\s+/,XS_DATETIME_TYPE ))) {
				$h->{SQL_TYPE} = $params{SELF}->{ANONYMOUS_COLUMN}->factory_sql_type qw(DATETIME);
		}  
		elsif (grep($_ eq $base, split(/\s+/,XS_DATE_TYPE ))) {
				$h->{SQL_TYPE} = $params{SELF}->{ANONYMOUS_COLUMN}->factory_sql_type qw(DATE);
		} 
		elsif (grep($_ eq $base, split(/\s+/,XS_TIME_TYPE ))) {
				$h->{SQL_TYPE} = $params{SELF}->{ANONYMOUS_COLUMN}->factory_sql_type qw(TIME);
		} 
		elsif (grep($_ eq $base, split(/\s+/,XS_GYEAR_TYPE ))) {
				$h->{SQL_TYPE} = $params{SELF}->{ANONYMOUS_COLUMN}->factory_sql_type qw(GYEAR);
		} 
		elsif (grep($_ eq $base, split(/\s+/,XS_GYEARMONTH_TYPE ))) {
				$h->{SQL_TYPE} = $params{SELF}->{ANONYMOUS_COLUMN}->factory_sql_type qw(GYEARMONTH);
		} 
		elsif (grep($_ eq $base, split(/\s+/,XS_GMONTHDAY_TYPE ))) {
				$h->{SQL_TYPE} = $params{SELF}->{ANONYMOUS_COLUMN}->factory_sql_type qw(GMONTHDAY);
		} 
		elsif (grep($_ eq $base, split(/\s+/,XS_BOOLEAN_TYPE ))) {
				$h->{SQL_TYPE} = $params{SELF}->{ANONYMOUS_COLUMN}->factory_sql_type qw(BOOLEAN);
		} 
		else {
			confess $h->{BASE}.":  base non converted ";
		}
	}
	else { # user defined type
		print STDERR $h->{BASE},": user defined type\n" if $params{DEBUG};
	}
	return bless $h,SIMPLE_TYPE_CLASS;
}

sub _get_simple_type_from_node {
  my $node=shift;
  my %params=@_;
  my $h=_get_type($node,%params);
  return _get_simple_type_x($h,%params);
}
sub _get_type_x {
	my $node=shift;
	my $level=shift;
	my %params=@_;
	my $type = $node->type();
	if (defined $type) {
		return ref($type) eq '' && $type =~/^xs:/ 
			? _get_simple_type_x( { BASE => $type },%params)
			: $type;
	}
	my $r=ref($node->{_content_}->[0]);
	return undef if $r =~/::ComplexType$/;
	return _get_simple_type_from_node($node->{_content_}->[0],%params) if $r =~/::SimpleType$/;
	confess $r;
}

sub _parse_x {
	my $parent=shift;
	my $level=shift;
	my $parent_table=shift;
	my $types=shift;
	my %params=@_;
	for my $node(@{$parent->{_content_}}) {
		my $r=ref($node);
		if ($r =~/::Element$/) {
			my $name = $node->name();
			$node->{complete_name}=$parent->{complete_name}.'/'.$name;
			my ($maxoccurs,$minoccurs,$type) = (nvl($node->{_maxOccurs},1),nvl($node->{_minOccurs},1),_get_type_x($node,$level + 1,%params));
			$maxoccurs=UNBOUNDED if $maxoccurs eq 'unbounded';
			if (defined $type) {
				if ($maxoccurs > 1 && ref($type) eq SIMPLE_TYPE_CLASS ) {
					my $column = $params{COLUMN_CLASS}->new(
						PATH		=> $node->{complete_name}
						,TYPE		=> Storable::dclone($params{ID_SQL_TYPE})
						,MINOCCURS	=> $minoccurs
						,MAXOCCURS	=> $maxoccurs
						,PATH_REFERENCE => $node->{complete_name}
						,INTERNAL_REFERENCE => 1
					);
					if (defined $parent_table->{XSD_SEQ}) {	   #the table is a sequence or choise
						$column->{XSD_SEQ}=$parent_table->{XSD_SEQ}; 
						++$parent_table->{XSD_SEQ} unless $parent_table->{CHOISE}; #the columns of a choise have the same xsd_seq
					}
					$parent_table->add_columns($column);
					my $table = $params{TABLE_CLASS}->new(
						PATH		    => $node->{complete_name}
						,TABLE_IS_TYPE  => 1
					);
					$table->get_sql_name(%params); #force the resolve of sql name
					$table->get_constraint_name('pk',%params); #force the resolve of pk constraint 
					$table->add_columns(
						$params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(ID))
						,$params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(SEQ))
					);
					my $value_col=$params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(VALUE));
					$value_col->set_attrs_value(TYPE => $type);
					$table->add_columns($value_col);
					$parent_table->add_child_tables($table);
				}
				else {
					my $column = $params{COLUMN_CLASS}->new(
						PATH		=> $node->{complete_name}
						,TYPE		=> $type
						,MINOCCURS	=> $minoccurs
						,MAXOCCURS	=> $maxoccurs
					);
					if (defined $parent_table->{XSD_SEQ}) {	   #the table is a sequence or choise
						$column->{XSD_SEQ}=$parent_table->{XSD_SEQ}; 
						++$parent_table->{XSD_SEQ} unless $parent_table->{CHOISE}; #the columns of a choise have the same xsd_seq
					}
					$parent_table->add_columns($column);
				}
			}
			else {  				  #anonymous type - converted into a table
				my $table = $params{TABLE_CLASS}->new(
					 PATH		=> $node->{complete_name}
				);
				$table->get_sql_name(%params); #force the resolve of sql name
				$table->get_constraint_name('pk',%params); #force the resolve of pk constraint
				$table->add_columns($params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(ID)));

				my $maxocc=nvl($params{MAXOCCURS},1);
				$table->set_attrs_value(MAXOCCURS => $maxocc) 	if $maxocc > 1;
				$table->set_attrs_value(MAXOCCURS => $maxoccurs) 	if $maxoccurs > 1;
				$parent_table->add_child_tables($table);

				my $column = $params{COLUMN_CLASS}->new(	 #hoock to the parent the column 
					  NAME		=> $name
					  ,PATH		=> 	undef
					  ,TYPE		=>  Storable::dclone($params{ID_SQL_TYPE})
					  ,MINOCCURS	=> $minoccurs
					  ,MAXOCCURS	=> $maxoccurs
					  ,PATH_REFERENCE	=> $node->{complete_name}
				  );
				if (defined $parent_table->{XSD_SEQ}) {	   #the table is a xs:sequence or a xs:choice 
					$column->{XSD_SEQ}=$parent_table->{XSD_SEQ}; 
					++$parent_table->{XSD_SEQ} unless $parent_table->{CHOISE}; 
				}	
				$parent_table->add_columns($column);
				_parse_x($node,$level + 1,$table,$types,%params);
			}
		}
		elsif ($r=~/::ComplexType$/) {
			my $name=$node->name();
			if (defined $name) {
				$node->{complete_name}=$parent->{complete_name}.'/'.$name;
				my $table = $params{TABLE_CLASS}->new (
					 PATH		=> $node->{complete_name}
					,TABLE_IS_TYPE	=> 1
					,COMPLEX_TYPE	=> 1
					,XSD_SEQ	=> 1
				);
				$table->get_sql_name(%params); #force the resolve of sql name
				$table->get_constraint_name('pk',%params); #force the resolve of pk constraint 
				$table->add_columns(
					$params{SELF}->{ANONYMOUS_COLUMN}->factory_column qw(ID)
					,$params{SELF}->{ANONYMOUS_COLUMN}->factory_column qw(SEQ)
				);
				push @$types,$table;
				_parse_x($node,$level + 1,$table,undef,%params);
			}						
			else {
				$node->{complete_name}=$parent->{complete_name};
				_parse_x($node,$level + 1,$parent_table,$types,%params);
			}
		}
		elsif ($r=~/::Choice$/) {
			$node->{complete_name}=$parent->{complete_name};
			my $maxoccurs=nvl($node->{_maxOccurs},1);
			$maxoccurs=UNBOUNDED if $maxoccurs eq 'unbounded';
			if ($maxoccurs > 1) {
				my $table = $params{TABLE_CLASS}->new(
					NAME		=> DEFAULT_OCCURS_TABLE_PREFIX.$parent_table->get_attrs_value qw(NAME)
					,PATH		=> undef
					,MAXOCCURS 	=> $maxoccurs
					,CHOISE		=> 1
				);
				$table->get_sql_name(%params); #force the resolve of sql name
				$table->get_constraint_name('pk',%params); #force the resolve of pk constraint 
				$table->add_columns(
					$params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(ID))
					,$params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(SEQ))
				);
				$parent_table->add_child_tables($table);

				my $column = $params{COLUMN_CLASS}->new(	 
					NAME		=> $table->{NAME}
					,PATH		=> 	undef
					,TYPE		=>  Storable::dclone($params{ID_SQL_TYPE})
					,MINOCCURS	=> 0
					,MAXOCCURS	=> 1
					,PATH_REFERENCE	=> $table->{NAME}
				);
				if (defined $parent_table->{XSD_SEQ}) {	  
					$column->{XSD_SEQ}=$parent_table->{XSD_SEQ}; 
					++$parent_table->{XSD_SEQ} unless $parent_table->{CHOISE}; 
				}
				$parent_table->add_columns($column);
				_parse_x($node,$level + 1,$table,$types,%params);
			}
			else {
				$parent_table->{CHOISE}=1;
				$parent_table->{XSD_SEQ}=0 unless defined $parent_table->{XSD_SEQ};
				_parse_x($node,$level + 1,$parent_table,$types,%params);
				delete $parent_table->{CHOISE};
			}
		}
		elsif ($r=~/::Sequence$/) {
			$node->{complete_name}=$parent->{complete_name};
			my $maxoccurs=nvl($node->{_maxOccurs},1);
			$maxoccurs=UNBOUNDED if $maxoccurs eq 'unbounded';
			if ($maxoccurs > 1) {
				my $table = $params{TABLE_CLASS}->new(
					NAME		=> DEFAULT_OCCURS_TABLE_PREFIX.$parent_table->get_attrs_value(qw(NAME))
					,MAXOCCURS	=> $maxoccurs
				);
				$table->get_sql_name(%params); #force the resolve of sql name
				$table->get_constraint_name('pk',%params); #force the resolve of pk constraint 
				$table->add_columns(
					$params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(ID))
					,$params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(SEQ))
				);
				$parent_table->add_child_tables($table);

				my $column = $params{COLUMN_CLASS}->new (	 #hook the the column to the parent table 
					NAME		=> $table->{NAME}
					,TYPE		=> Storable::dclone($params{ID_SQL_TYPE})
					,MINOCCURS	=> 0
					,MAXOCCURS	=> 1
					,PATH_REFERENCE	=> $table->{NAME}
				);
				if (defined $parent_table->{XSD_SEQ}) {	   #the table is a sequence or a choise 
					$column->{XSD_SEQ}=$parent_table->{XSD_SEQ}; 
					++$parent_table->{XSD_SEQ} unless $parent_table->{CHOISE};
				}
				$parent_table->add_columns($column);
				_parse_x($node,$level + 1,$table,$types,%params);
			}
			else {
				$parent_table->{XSD_SEQ}=0 unless defined $parent_table->{XSD_SEQ};
				_parse_x($node,$level + 1,$parent_table,$types,%params);
			}
		}
		elsif ($r=~/::SimpleType$/) {
			my $name=$node->name();
			if (defined $name) {
				$node->{complete_name}=$parent->{complete_name}.'/'.$name;
				my @cols=(
					$params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(ID))
					,$params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(SEQ))
					,$params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(VALUE))
				);
				$cols[-1]->set_attrs_value( TYPE => _get_simple_type_from_node($node,%params));
				my $table = $params{TABLE_CLASS}->new(
					 PATH		=> $node->{complete_name}
					,MAXOCCURS	=> 1
					,XSD_SEQ	=> 0
					,TABLE_IS_TYPE	=> 1
					,SIMPLE_TYPE	=> 1
					,TYPE       => $node  
 				);
				$table->add_columns(@cols);
				$table->get_sql_name(%params); #force the resolve of sql name
				$table->get_constraint_name('pk',%params); #force the resolve of pk constraint 
				push @$types,$table;
			}
			next;
		}
		else {
			confess "$r: unknow type";
		}
	}
}

sub _parse_user_def_types {
	my $tables=shift;
	my $types=shift;
	my %params=@_;
	confess "param ID_SQL_TYPE not set" unless defined $params{ID_SQL_TYPE};
	for my $t(@$tables) {
		my $child_tables=$t->get_attrs_value qw(CHILD_TABLES);
		_parse_user_def_types($child_tables,$types,%params);
		for my $c($t->get_columns) {
			if (ref($c->{TYPE}) eq '') {
				my $ty=(grep($c->{TYPE} eq $_->get_attrs_value(qw(NAME)),@$types))[0] || confess $c->{TYPE}.": type not found ";
				if ($ty->{SIMPLE_TYPE}) {
					$c->{TYPE}=_get_simple_type_from_node($ty->{TYPE},%params);
				}
				elsif ($ty->{COMPLEX_TYPE}) {		  
					my $h=Storable::dclone($params{ID_SQL_TYPE});
					$c->{PATH_REFERENCE}=$ty->{PATH};
					$c->{TYPE}=$h; 
				}
				else {
					confess Dumper($ty).": not simple or complex type";
				}
			}
			else {
				next if defined $c->{TYPE}->{SQL_TYPE};
				my $t=(grep($c->{TYPE}->{BASE} eq $_->get_attrs_value(qw(NAME)),@$types))[0];
				if ($t->{SIMPLE_TYPE}) {
					$c->{TYPE}=_get_simple_type_from_node($t->{TYPE},%params);
					confess Dumper($c->{TYPE}.": not SQL_TYPE") unless defined $c->{TYPE}->{SQL_TYPE}; 
				}
				confess Dumper($t->{TYPE}.": type non converted ") unless defined $c->{TYPE};
			}
		}
	}
}

sub _parse {
	my $r=shift;
	my %params=@_;
	my $root=$params{TABLE_CLASS}->new (
		NAME			=> undef
		,PATH			=> '/'
		,CHOISE			=> 1
		,TYPES			=> []
	);
	$root->get_sql_name(%params); #force the resolve of sql name 
	$root->get_constraint_name('pk',%params); #force the resolve of pk constraint
	$root->add_columns($params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(ID)));
	_parse_x($r,0,$root,$root->{TYPES},%params);
	_parse_user_def_types($root->{CHILD_TABLES},$root->{TYPES},%params);
	_parse_user_def_types($root->{TYPES},$root->{TYPES},%params);
	return $root;
}

sub  parsefile {
	my ($self,$file_name,%params)=@_;
	my $r = Rinchi::XMLSchema->parsefile($file_name);
	$r->{complete_name} = '';
	$params{SELF}=$self;
	for my $k qw(ID_SQL_TYPE TABLE_CLASS COLUMN_CLASS) {
		$params{$k}=$self->{$k};
	}
	$params{TABLENAME_LIST}={};
	$params{CONSTRAINT_LIST}={};
	return _parse($r,%params);
}


sub new {
	my $class=shift;
	my %params=@_;
	my $namespace=$params{DB_NAMESPACE};
	croak "no param DB_NAMESPACE spec" unless defined $namespace;
	$params{CATALOG_CLASS}='blx::xsdsql::xml::'.$namespace.'::catalog';
	$params{TABLE_CLASS}='blx::xsdsql::xml::'.$namespace.'::table';
	$params{COLUMN_CLASS}='blx::xsdsql::xml::'.$namespace.'::column';
	for my $cl qw( CATALOG_CLASS TABLE_CLASS COLUMN_CLASS ) {
		ev('use',$params{$cl});
	}
	$params{ANONYMOUS_COLUMN}=$params{COLUMN_CLASS}->new;
	$params{ID_SQL_TYPE}=$params{ANONYMOUS_COLUMN}->factory_column(qw(ID))->get_attrs_value(qw(TYPE));
	return bless \%params,$class;
}
	
sub  get_db_namespaces {
	my @n=();
	for my $i(@INC) {
		my $dir=File::Spec->catdir($i,'blx','xsdsql','xml');
		next unless  -d "$dir";
		next unless opendir(my $fd,$dir);
		while(my $d=readdir($fd)) {
			next unless -d File::Spec->catdir($dir,$d);
			next if $d eq '.';
			next if $d eq '..';
			push @n,$d;
		}
		closedir($fd);
	}
	return wantarray ? @n : \@n;
}

if ($0 eq __FILE__) {
	use strict;
	use warnings;
	use Data::Dumper;
	my $p=blx::xsdsql::parser->new(DB_NAMESPACE => 'pg'); 
	my $t=$p->parsefile($ARGV[0]);
	print Dumper($t);
}



1;



__END__



=head1  NAME

blx::xsdsql::parser -  parser for xsd files 

=cut

=head1 SYNOPSIS

use blx::xsdsql::parser

=cut


=head1 DESCRIPTION

this package is a class - instance it with the method new


=head1 FUNCTIONS

this module defined the followed functions

new - constructor 

	PARAMS:
		DB_NAMESPACE -   database namespace  (default not set) 


parsefile - parse a xsd file
 
	the first param if an object compatible with the input of Rinchi::XMLSchema::parsefile, normally a file name    
	the method return a tree of objects rapresented the  tables of database 


get_db_namespaces - static method 

	the method return an array of namespace founded 



=head1 EXPORT

None by default.


=head1 EXPORT_OK
	
None

=head1 SEE ALSO

See blx:.xsdsql::generator for generate the schema of the database and blx::xsdsql:xml from read/write a xml file from/into a database 

=head1 AUTHOR

lorenzo.bellotti, E<lt>bellzerozerouno@tiscali.itE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
