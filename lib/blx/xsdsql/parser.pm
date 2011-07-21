package blx::xsdsql::parser;

use strict;
use warnings FATAL => 'all';
use integer;
use Carp;
use POSIX;

use File::Basename;
use Data::Dumper;
use Rinchi::XMLSchema;

use blx::xsdsql::ut qw(nvl ev);
use blx::xsdsql::schema;
use blx::xsdsql::IStream;

use constant {
			 DEFAULT_OCCURS_TABLE_PREFIX 		=> 'm_'
			,UNBOUNDED							=> INT_MAX
			,XS_STRING_TYPE						=> 'string  normalizedString  token  base64Binary  hexBinary duration ID IDREF  IDREFS  NMTOKEN NMTOKENS language Name QName NCName anyURI' 
			,XS_INTEGER_TYPE					=> 'integer integer  nonPositiveInteger  negativeInteger  long  int  short  byte  nonNegativeInteger  unsignedLong  unsignedInt  unsignedShort  unsignedByte  positiveInteger'
			,XS_DOUBLE_TYPE						=> 'double'
			,XS_FLOAT_TYPE				    	=> 'float'
			,XS_DECIMAL_TYPE					=> 'decimal'
			,XS_DATETIME_TYPE					=> 'dateTime'
			,XS_DATE_TYPE						=> 'date'
			,XS_TIME_TYPE						=> 'time'
			,XS_GYEAR_TYPE						=> 'gYear'
			,XS_GYEARMONTH_TYPE					=> 'gYearMonth'
			,XS_GMONTHDAY_TYPE					=> 'gMonthDay'
			,XS_BOOLEAN_TYPE					=> 'boolean'
			,SIMPLE_TYPE_CLASS					=> 'blx::xsdsql::xml::simple_type'
			,STRING_MAXSIZE						=>  INT_MAX
			,XML_STD_NAMESPACES					=>  'xs xsd' 
			,DEFAULT_TABLE_DICTIONARY_NAME		=>  'table_dictionary'
			,DEFAULT_COLUMN_DICTIONARY_NAME		=>  'column_dictionary'
			,DEFAULT_RELATION_DICTIONARY_NAME	=>  'relation_dictionary'
};

sub _autodetect_xml_namespaces { #is a brutal autodetect namespaces from a xml schema
	my ($file_name,%params)=@_;
	croak "$file_name: file not found\n" unless -e $file_name;
	croak "$file_name: not regular file\n" unless -f $file_name;
	open(my $fd,'<',$file_name) || croak "$file_name: cannot open: $!";
	my $is=blx::xsdsql::IStream->new(INPUT_STREAM => $fd,MAX_PUSHBACK_SIZE => 10);

	my ($encoding,$ns);
	while(my $line=$is->get_line) {
		last if length($line) == 0;
		next if $line=~/^\s*$/;

		if ($line=~/^.*<\?xml\s+version="[^"]+"\s+encoding="([^"]+)"\s*\?>/) {
			$encoding=$1;
			last;
		}
		
		if ($line=~/^.*<\?xml\s+version="[^"]+".*\?>/) {	# "
			$encoding='utf-8';
			last;
		}

		close $fd;
		croak "$file_name: is not an xml file (no such header)\n";
	}
	
	unless (defined $encoding) {
		close $fd;
		croak "$file_name: is not an xml file (no such header after a EOF)\n";
	}
	
	while(my $line=$is->get_line) {
		last if length($line) == 0;
		next if $line=~/^\s*$/;
		next if $line=~/^\s*<!--/;  #one line comment
		if ($line=~/^\s*<xs:schema\s(.*)>/) {
			my $attrs=$1;
			my @ns=$attrs=~/xmlns:(\w+)/g;
			$ns=\@ns if scalar(@ns);
			last;
		}
		close $fd;
		croak "$file_name: is not an xml schema file (no such xs:schema node)\n";
	}
	close $fd;
	
	croak "$file_name: is not an xml schema file (no such xs:schema node after a EOF)\n"
		unless defined $ns;

	return $ns;
}

sub _debug {
	my ($n,@l)=@_;
	$n='<undef>' unless defined $n; 
	print STDERR 'parser (D ',$n,'): ',join(' ',grep(defined $_,@l)),"\n"; 
	return  undef;
}

sub _get_type {
	my $parent=shift;
	my $r=ref($parent);
	my %type=();
	$type{RESTRICTIONS}=[];
	if ($r =~/::SimpleType$/) {
		for my $e(@{$parent->{_content_}}) {
			my $r=ref($e); 
			if ($r=~/::Restriction$/) {
				$type{BASE}=$e->base();
			}
			elsif ($r =~/::Union$/) {
				$type{BASE}='xs:string';
			}
			else {
				_debug(__LINE__,Dumper($e));
				confess  $r.": type not implemented";
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
	my ($h,%params)=@_;
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
	elsif (defined $params{TYPE_NAMES})  { # user defined type
		my $base=$h->{BASE};
		my $basetype=$params{TYPE_NAMES}->{$base};
		confess "$base: non type found" unless defined $basetype;
		my $ty=_get_type($basetype->{TYPE});
		push @{$h->{RESTRICTIONS}},@{$ty->{RESTRICTIONS}};  #merge restrictions
		$h->{BASE}=$ty->{BASE};   #change the type
		return _get_simple_type_x($h,%params);		
	}
	else {
		_debug(__LINE__,$h->{BASE}.": user defined type - resolved next time") if $params{DEBUG};		
	}
	return bless $h,SIMPLE_TYPE_CLASS;
}

sub _get_simple_type_from_node {
  my ($node,%params)=@_;
  my $h=_get_type($node,%params);
  return _get_simple_type_x($h,%params);
}

sub _get_type_x {
	my ($node,$level,%params)=@_;
	my $type = $node->type();
	if (defined $type) {
		return ref($type) eq '' && $type =~/^xs:/ 
			? _get_simple_type_x( { BASE => $type },%params)
			: $type;
	}
	my $i=0;while (ref($node->{_content_}->[$i]) =~/::Annotation$/) { ++$i; } #annotation skipped
	my $content=$node->{_content_}->[$i];
	return bless({},SIMPLE_TYPE_CLASS) unless defined $content;
	my $r=ref($content);
	return undef if $r =~/::ComplexType$/;
	return _get_simple_type_from_node($content,%params) if $r =~/::SimpleType$/;
	confess $r;
}

sub _parse_x {
	my ($parent,$level,$parent_table,$types,%params)=@_;
	my $isparent_choice=$parent_table->get_attrs_value qw(CHOICE);
	for my $node(@{$parent->{_content_}}) {
		my $r=ref($node);
		if ($r =~/::Element$/) {
			my $name = $node->name();
			$node->{complete_name}=$parent->{complete_name}.'/'.$name;
			my ($maxoccurs,$minoccurs,$type) = (nvl($node->{_maxOccurs},1),nvl($node->{_minOccurs},1),_get_type_x($node,$level + 1,%params));
			$maxoccurs=UNBOUNDED if $maxoccurs eq 'unbounded';
			$minoccurs=0 if $isparent_choice;
			if (defined $type) {
				if ($maxoccurs > 1  && ref($type) eq SIMPLE_TYPE_CLASS) {
					my $column = $params{COLUMN_CLASS}->new(
						PATH		=> $node->{complete_name}
						,TYPE		=> Storable::dclone($params{ID_SQL_TYPE})
						,MINOCCURS	=> $minoccurs
						,MAXOCCURS	=> $maxoccurs
						,INTERNAL_REFERENCE => 1
						,CHOICE		=> $isparent_choice
					);
					if (defined $parent_table->get_xsd_seq) {	   #the table is a sequence or choice
						$column->set_attrs_value(XSD_SEQ => $parent_table->get_xsd_seq); 
						$parent_table->_inc_xsd_seq unless $isparent_choice; #the columns of a choice have the same xsd_seq
					}
					$parent_table->add_columns($column);
					my $table = $params{TABLE_CLASS}->new(
						PATH		    => $node->{complete_name}
						,TABLE_IS_TYPE  => 0
						,DEEP_LEVEL			=> $level
						,INTERNAL_REFERENCE => 1
					);
					$table->get_sql_name(%params); #force the resolve of sql name
					$table->get_constraint_name('pk',%params); #force the resolve of pk constraint
					$table->get_view_sql_name(%params);   #force the resolve of view sql name
					$table->add_columns(
						$params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(ID))
						,$params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(SEQ))
					);
					my $value_col=$params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(VALUE));
					$value_col->set_attrs_value(TYPE => $type,PATH => $node->{complete_name},CHOICE => $isparent_choice);
					$table->add_columns($value_col);
					$column->set_attrs_value(TABLE_REFERENCE => $table,PATH_REFERENCE => $table->get_path);
					$parent_table->add_child_tables($table);
				}
				else {
					my $column = $params{COLUMN_CLASS}->new(
						PATH		=> $node->{complete_name}
						,TYPE		=> $type
						,MINOCCURS	=> $minoccurs
						,MAXOCCURS	=> $maxoccurs
						,CHOICE 	=> $isparent_choice
					);
					if (defined $parent_table->get_xsd_seq) {	   #the table is a sequence or choice
						$column->set_attrs_value(XSD_SEQ => $parent_table->get_xsd_seq); 
						$parent_table->_inc_xsd_seq unless $isparent_choice; #the columns of a choice have the same xsd_seq
					}

					$parent_table->add_columns($column);
				}
			}
			else {  				  #anonymous type - converted into a table
				my $table = $params{TABLE_CLASS}->new(
					 PATH				=> $node->{complete_name}
					 ,DEEP_LEVEL		=> $level
				);
				$table->get_sql_name(%params); #force the resolve of sql name
				$table->get_constraint_name('pk',%params); #force the resolve of pk constraint
				$table->get_view_sql_name(%params);   #force the resolve of view sql name
				$table->add_columns($params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(ID)));

				my $maxocc=nvl($params{MAXOCCURS},1);
				$table->set_attrs_value(MAXOCCURS => $maxocc) 	if $maxocc > 1;
				$table->set_attrs_value(MAXOCCURS => $maxoccurs) 	if $maxoccurs > 1;
				$parent_table->add_child_tables($table);

				my $column = $params{COLUMN_CLASS}->new(	 #hoock to the parent the column 
					  NAME				=> $name
					  ,PATH				=> 	undef
					  ,TYPE				=>  Storable::dclone($params{ID_SQL_TYPE})
					  ,MINOCCURS		=> $minoccurs
					  ,MAXOCCURS		=> $maxoccurs
					  ,PATH_REFERENCE	=> $node->{complete_name}
					  ,CHOICE			=> $isparent_choice
				  );
				if (defined $parent_table->get_xsd_seq) {	   #the table is a xs:sequence or a xs:choice 
					$column->set_attrs_value(XSD_SEQ => $parent_table->get_xsd_seq); 
					$parent_table->_inc_xsd_seq unless $isparent_choice; 
				}	
				$parent_table->add_columns($column);
				_parse_x($node,$level + 1,$table,$types,%params,PARENT_PATH => $table->get_path);
			}
		}
		elsif ($r=~/::ComplexType$/) {
			my $name=$node->name();
			if (defined $name) {
				$node->{complete_name}=$parent->{complete_name}.'/'.$name;
				my $table = $params{TABLE_CLASS}->new (
					 PATH			=> $node->{complete_name}
					,TABLE_IS_TYPE	=> 1
					,COMPLEX_TYPE	=> 1
					,XSD_SEQ		=> 1
					,DEEP_LEVEL		=> $level
				);
				$table->get_sql_name(%params); #force the resolve of sql name
				$table->get_constraint_name('pk',%params); #force the resolve of pk constraint 
				$table->get_view_sql_name(%params);   #force the resolve of view sql name

				$table->add_columns(
					$params{SELF}->{ANONYMOUS_COLUMN}->factory_column qw(ID)
					,$params{SELF}->{ANONYMOUS_COLUMN}->factory_column qw(SEQ)
				);
				push @$types,$table;
				_parse_x($node,$level + 1,$table,undef,%params,PARENT_PATH => $table->get_path);
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
					NAME			=> DEFAULT_OCCURS_TABLE_PREFIX.$parent_table->get_attrs_value qw(NAME)
					,PATH			=> undef
					,MAXOCCURS 		=> $maxoccurs
					,CHOICE			=> 1
					,DEEP_LEVEL		=> $level
					,PARENT_PATH	=> $params{PARENT_PATH}
				);
				$table->get_sql_name(%params); #force the resolve of sql name
				$table->get_constraint_name('pk',%params); #force the resolve of pk constraint 
				$table->get_view_sql_name(%params);   #force the resolve of view sql name

				$table->add_columns(
					$params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(ID))
					,$params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(SEQ))
				);
				$parent_table->add_child_tables($table);

				my $column = $params{COLUMN_CLASS}->new(	 
					NAME				=> $table->{NAME}
					,PATH				=> 	undef
					,TYPE				=>  Storable::dclone($params{ID_SQL_TYPE})
					,MINOCCURS			=> 0
					,MAXOCCURS			=> 1
					,PATH_REFERENCE		=> $table->get_path
					,TABLE_REFERENCE 	=> $table
					,CHOICE				=> $isparent_choice
				);
				if (defined $parent_table->get_xsd_seq) {	  
					$column->set_attrs_value(XSD_SEQ => $parent_table->get_xsd_seq); 
					$parent_table->_inc_xsd_seq unless $isparent_choice; 
				}
				$parent_table->add_columns($column);
				_parse_x($node,$level + 1,$table,$types,%params);
			}
			else {
				$parent_table->set_attrs_value(CHOICE => 1);
				$parent_table->set_attrs_values(XSD_SEQ => 0) unless defined $parent_table->get_xsd_seq; 
				_parse_x($node,$level + 1,$parent_table,$types,%params);
				$parent_table->set_attrs_value(CHOICE => $isparent_choice);
			}
		}
		elsif ($r=~/::Sequence$/) {
			$node->{complete_name}=$parent->{complete_name};
			my $maxoccurs=nvl($node->{_maxOccurs},1);
			$maxoccurs=UNBOUNDED if $maxoccurs eq 'unbounded';
			if ($maxoccurs > 1) {
				my $table = $params{TABLE_CLASS}->new(
					NAME			=> DEFAULT_OCCURS_TABLE_PREFIX.$parent_table->get_attrs_value(qw(NAME))
					,MAXOCCURS		=> $maxoccurs
					,DEEP_LEVEL		=> $level
					,PARENT_PATH	=> $params{PARENT_PATH}
				);
				$table->get_sql_name(%params); #force the resolve of sql name
				$table->get_constraint_name('pk',%params); #force the resolve of pk constraint 
				$table->get_view_sql_name(%params);   #force the resolve of view sql name

				$table->add_columns(
					$params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(ID))
					,$params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(SEQ))
				);
				$parent_table->add_child_tables($table);

				my $column = $params{COLUMN_CLASS}->new (	 #hook the column to the parent table 
					NAME				=> $table->{NAME}
					,TYPE				=> Storable::dclone($params{ID_SQL_TYPE})
					,MINOCCURS			=> 0
					,MAXOCCURS			=> 1
					,PATH_REFERENCE		=> $table->get_path
					,TABLE_REFERENCE	=> $table
					,CHOICE				=> $isparent_choice
				);
				if (defined $parent_table->get_xsd_seq) {	   #the table is a sequence or a choice 
					$column->set_attrs_value(XSD_SEQ => $parent_table->get_xsd_seq); 
					$parent_table->_inc_xsd_seq unless $isparent_choice;
				}
				$parent_table->add_columns($column);
				_parse_x($node,$level + 1,$table,$types,%params);
			}
			else {
				$parent_table->set_attrs_value(XSD_SEQ => 0) unless defined $parent_table->get_xsd_seq; 
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
				$cols[-1]->set_attrs_value( TYPE => _get_simple_type_from_node($node,%params),PATH => $node->{complete_name});
				my $table = $params{TABLE_CLASS}->new(
					 PATH			=> $node->{complete_name}
					,MAXOCCURS		=> 1
					,XSD_SEQ		=> 0
					,TABLE_IS_TYPE	=> 1
					,SIMPLE_TYPE	=> 1
					,TYPE       	=> $node
					,DEEP_LEVEL		=> $level
 				);
				$table->get_sql_name(%params); #force the resolve of sql name
				$table->get_constraint_name('pk',%params); #force the resolve of pk constraint 
				$table->get_view_sql_name(%params);   #force the resolve of view sql name
				$table->add_columns(@cols);
				push @$types,$table;
			}
			next;
		}
		elsif ($r=~/::Annotation$/) {
			#ignored
		}
		elsif ($r=~/::Group$/) {
			my $ref=$node->ref;
			if (defined $ref) {  # is a reference 
				my ($maxoccurs,$minoccurs) = (nvl($node->{_maxOccurs},1),nvl($node->{_minOccurs},1));
 				$maxoccurs=UNBOUNDED if $maxoccurs eq 'unbounded';
				$minoccurs=0 if $isparent_choice;
				my $name=nvl($node->name,$ref);
				my $column = $params{COLUMN_CLASS}->new(
					PATH		=> $parent->{complete_name}
					,NAME		=> $name
					,TYPE		=> $ref
					,MINOCCURS	=> $minoccurs
					,MAXOCCURS	=> $maxoccurs
					,GROUP_REF	=> 1
					,CHOICE		=> $isparent_choice
				);
				if (defined $parent_table->get_xsd_seq) {	   #the table is a sequence or choice
					$column->set_attrs_value(XSD_SEQ => $parent_table->get_xsd_seq); 
					$parent_table->_inc_xsd_seq unless $isparent_choice; #the columns of a choice have the same xsd_seq
				}
				$parent_table->add_columns($column);
			}
			else {
				my $name=$node->name();
				if (defined $name) {
					$node->{complete_name}='/'.$name;
					my $table = $params{TABLE_CLASS}->new (
						 PATH			=> $node->{complete_name}
						,NAME			=> $name
						,TABLE_IS_TYPE	=> 1
						,GROUP_TYPE		=> 1
						,XSD_SEQ		=> 1
						,COMPLEX_TYPE	=> 1
						,DEEP_LEVEL		=> $level
					);
					$table->get_sql_name(%params); #force the resolve of sql name
					$table->get_constraint_name('pk',%params); #force the resolve of pk constraint 
					$table->get_view_sql_name(%params);   #force the resolve of view sql name

					$table->add_columns(
						$params{SELF}->{ANONYMOUS_COLUMN}->factory_column qw(ID)
						,$params{SELF}->{ANONYMOUS_COLUMN}->factory_column qw(SEQ)
					);
					push @$types,$table;
					_parse_x($node,$level + 1,$table,undef,%params,PARENT_PATH => $table->get_path);
				}
				else {
					confess "invalid xsd: group without name or ref"	
				}
			}
		}
		else {
			confess "$r: unknow type";
		}
	}
}

sub _resolve_simple_type {
	my ($t,$types,%params)=@_;
	my $ty=(grep($t eq $_->get_attrs_value(qw(NAME)),@$types))[0];
	return $ty if defined $ty;
	for my $ns(@{$params{XML_NAMESPACES}}) {
		next if $ns eq 'xs';  
		$ty=(grep($t eq $ns.':'.$_->get_attrs_value(qw(NAME)),@$types))[0];
		last if defined $ty;		
	}
	return $ty;
}

sub _parse_group_ref {  # flat the columns of groups table  into $table
	my ($table,%params)=@_;
	if ($params{START_FLAG}) {
		$params{PATH}={};
		my $z=-1;
		$params{MAX_XSD_SEQ}=\$z;
		$params{START_TABLE}=$table;
	}
	my $max_xsd_seq=${$params{MAX_XSD_SEQ}};
	my $pred_xsd_seq=!$params{START_FLAG} && $params{CHOICE} ? $max_xsd_seq : undef; 
	my $fl=0;
	my @newcols=();
	for my $c($table->get_columns) {
		next if $c->is_pk && ! $params{START_FLAG};  #bypass the primary keys if is not a start table 
		my $p=$c->get_path;
		my $nc=$params{START_FLAG} ? $c : $c->shallow_clone;

		if (defined ( my $xsd_seq=$nc->get_xsd_seq)) {  # change xsd_seq
			if (defined $pred_xsd_seq && $xsd_seq == $pred_xsd_seq) {
				$xsd_seq=$max_xsd_seq;
			}
			else  {
				$pred_xsd_seq=$xsd_seq;
				$xsd_seq=++$max_xsd_seq;
			}
			$nc->set_attrs_value(XSD_SEQ => $xsd_seq);
			unless ($params{START_FLAG}) {
				$nc->set_attrs_value(CHOICE => $params{CHOICE});
				$nc->set_attrs_value(MINOCCURS => 0) if $params{CHOICE}; 
			}
		}

		if  (!$params{START_FLAG}  && defined (my $cpath=$nc->get_path)) {  #change the path of the column
			my $path=$params{START_TABLE}->is_unpath ? $params{START_TABLE}->get_parent_path : $params{START_TABLE}->get_path;
			$path.='/'.basename($cpath) unless $nc->is_group_reference;
			_debug(__LINE__,' change path of column ',$nc->get_full_name," from '$cpath' to '$path'") if $params{DEBUG};
			$nc->set_attrs_value(PATH	=> $path);
			$p=$path;
		}


		if (defined $p && !$nc->is_group_reference) {  #register new path
			if (defined (my $col=$params{PATH}->{$p})) {
				_debug(__LINE__,$p,': path already register for column ',$nc->get_full_name,' - pred column is ',$col->get_full_name)
					if $params{DEBUG};
				unless ($params{START_FLAGS}) {		 # a column into a group has priority to a column with same path
					$col->set_attrs_value(DELETE => 1);	  # the pred column is marked for deletion
				}
				else {
					_debug(__LINE__,$p,' the column ',$nc->get_full_name, ' is bypassed')
						if $params{DEBUG};
					next;
				}
			}
			$params{PATH}->{$p}=$nc;
		}


		if ($nc->is_group_reference && $nc->get_max_occurs <= 1) { #flat the columns of ref table into $table
			++$fl;
			my $ty=$nc->get_attrs_value qw(TYPE);
			my $ref=$params{TYPE_NAMES}->{$ty};
			confess "no such table ref for column ".$c->get_full_name."(type '$ty')\n" unless defined $ref;
			_debug(__LINE__,$nc->get_full_name,": the columun ref table group '",$ref->get_sql_name,"' with maxoccurs <=1 - flating  the columns of table !!")
				if $params{DEBUG};
			${$params{MAX_XSD_SEQ}}=$max_xsd_seq;
			my @cols=_parse_group_ref($ref,%params,START_FLAG => 0,CHOICE => $nc->is_choice);
			$max_xsd_seq=${$params{MAX_XSD_SEQ}};
			push @newcols,@cols;
		}
		else {
			push @newcols,$nc
		}
	}	   #for
	${$params{MAX_XSD_SEQ}}=$max_xsd_seq;
	return @newcols unless $params{START_FLAG};
	return undef unless $fl; # no group ref column
	$table->reset_columns;
	$table->add_columns(grep(!$_->get_attrs_value qw(DELETE),@newcols));
	return undef;
}


sub _parse_user_def_types {
	my ($tables,$types,%params)=@_;
	for my $t(@$tables) {
		my $child_tables=$t->get_attrs_value qw(CHILD_TABLES);
		_parse_user_def_types($child_tables,$types,%params);
		_parse_group_ref($t,%params,START_FLAG => 1) unless  $params{NO_FLAT_GROUPS};
		for my $c($t->get_columns) {
			next if $c->is_pk;
			my $ctype=$c->get_attrs_value qw(TYPE);
			if (ref($ctype) eq '') {
				my $ty=_resolve_simple_type($ctype,$types,%params);
				confess "$ctype: type not found\n" unless defined $ty;
				if ($ty->{SIMPLE_TYPE}) {
					my $type=_get_simple_type_from_node($ty->{TYPE},%params);
					if ($c->get_max_occurs > 1) {						
						my $table = $params{TABLE_CLASS}->new(
							PATH		    	=> $c->get_path
							,TABLE_IS_TYPE  	=> 0
							,DEEP_LEVEL			=> $t->get_deep_level + 1
							,INTERNAL_REFERENCE => 1
						);
						$table->get_sql_name(%params); #force the resolve of sql name
						$table->get_constraint_name('pk',%params); #force the resolve of pk constraint
						$table->get_view_sql_name(%params);   #force the resolve of view sql name
						my $value_col=$params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(VALUE));
						$value_col->set_attrs_value(TYPE => $type,PATH => $c->get_path);
						$table->add_columns(
							$params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(ID))
							,$params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(SEQ))
							,$value_col
						);
						$c->set_attrs_value(
							PATH_REFERENCE 			=> $table->get_path
							,INTERNAL_REFERENCE 	=> 1
							,TYPE 					=> Storable::dclone($params{ID_SQL_TYPE})
							,TABLE_REFERENCE 		=> $table
						);
						$t->add_child_tables($table);						
					}
					else {
						$c->set_attrs_value(TYPE => $type);
					}
				}
				elsif ($ty->{COMPLEX_TYPE}) {
					delete $c->{INTERNAL_REFERENCE};  #the column is not an internal reference
					my $h=Storable::dclone($params{ID_SQL_TYPE});
					if (ref($ty) =~ /::table$/) {
						$c->set_attrs_value(PATH_REFERENCE => $ty->get_path,TABLE_REFERENCE => $ty,TYPE => $h);
					}
					else {
						$c->set_attrs_value(PATH_REFERENCE => $ty->{PATH},TYPE => $h); 
					}
				}
				else {
					_debug(__LINE__,Dumper($ty)) if $params{DEBUG};
					confess " not simple or complex type\n";
				}
			}
			else {
				next if defined $ctype->{SQL_TYPE};
				next unless scalar(%$ctype); #skip if an empty hash
				my $base= $ctype->{BASE};
				unless (defined $base) {
					_debug(__LINE__,Dumper($ctype)) if $params{DEBUG};
					confess " type without base\n";
				}
				my @base=ref($base) eq 'ARRAY' ? @$base : ($base);
				my @outtype=();
				for my $base(@base) {
					my $t=$params{TYPE_NAMES}->{$base};
					unless (defined $t) {
						_debug(__LINE__,Dumper($base)) if $params{DEBUG};
						confess "base not found into types for column\n";
					}
					if ($t->{SIMPLE_TYPE}) {
						my $st=_get_simple_type_from_node($t->{TYPE},%params);
						unless (defined $st->{SQL_TYPE}) {
							_debug(__LINE__,"base --> ".$base."\n".Dumper($t->{TYPE}))
								if $params{DEBUG};
							confess "not SQL_TYPE\n"; 
						}
						push @outtype,$st;
					}
				}
				$c->{TYPE}=scalar(@outtype) == 1 ? $outtype[0] : \@outtype;
			}
		} #for on columns
	}  # for on tables
}


sub _factory_dictionary {
	my ($dictionary_type,$name,%params)=@_;
	my $t=$params{TABLE_CLASS}->new(NAME => $name);
	$t->get_sql_name(%params);  #force the resolve of sql name
	$t->get_constraint_name('pk',%params); #force the resolve of pk constraint
	$t->add_columns($params{SELF}->{ANONYMOUS_COLUMN}->factory_dictionary_columns($dictionary_type,%params));
	return $t;
}

sub _parse {
	my ($r,%params)=@_;
	for my $p qw( TABLENAME_LIST  CONSTRAINT_LIST) {
		confess "param $p not defined or it's wrong" if ref($params{$p}) ne 'HASH';
	}
	my $root=$params{TABLE_CLASS}->new (
		NAME			=> undef
		,PATH			=> '/'
		,CHOICE			=> 1
	);

	$root->get_sql_name(%params); #force the resolve of sql name 
	$root->get_constraint_name('pk',%params); #force the resolve of pk constraint
	$root->get_view_sql_name(%params); #force the resolve of the corresponding view name 	
	$root->get_sequence_name(%params); #force the resolve of the corresponding sequence name
	$root->add_columns($params{SELF}->{ANONYMOUS_COLUMN}->factory_column(qw(ID)));
	my $types=[];
	_parse_x($r,0,$root,$types,%params,PARENT_PATH => $root->get_path);
	my %type_names=map { ($_->get_attrs_value(qw(NAME)),$_) } grep(defined $_->get_attrs_value(qw(NAME)),@$types);
	my %p=(
			%params
			,TYPE_NAMES 		=> \%type_names
	);
	_parse_user_def_types($types,$types,%p);
	_parse_user_def_types($root->{CHILD_TABLES},$types,%p);
	
	my $schema=blx::xsdsql::schema->new(%params,TYPES => $types,ROOT => $root);
	$schema->mapping_paths(DEBUG => $params{DEBUG}); 

	my $td=_factory_dictionary('TABLE_DICTIONARY',nvl($params{TABLE_DICTIONARY_NAME},DEFAULT_TABLE_DICTIONARY_NAME),%params);
	my $cd=_factory_dictionary('COLUMN_DICTIONARY',nvl($params{COLUMN_DICTIONARY_NAME},DEFAULT_COLUMN_DICTIONARY_NAME),%params);
	my $rd=_factory_dictionary('RELATION_DICTIONARY',nvl($params{RELATION_DICTIONARY_NAME},DEFAULT_RELATION_DICTIONARY_NAME),%params);
	$schema->set_attrs_value(TABLE_DICTIONARY	=> $td,COLUMN_DICTIONARY => $cd,RELATION_DICTIONARY => $rd);
	return $schema;
}

sub _fusion_params {
	my ($self,%params)=@_;
	my %p=%$self;
	for my $p(keys %params) {
		$p{$p}=$params{$p};
	}
	return \%p;
}

sub parsefile {
	my ($self,$file_name,%params)=@_;
	my $r=Rinchi::XMLSchema->parsefile($file_name);
	$r->{complete_name} = '' unless defined $r->{complete_name};
	print STDERR Dumper($r),"\n" if $params{SCHEMA_DUMPER};
	my $p=$self->_fusion_params(%params);
	$p->{SELF}=$self;
	for my $k qw(ID_SQL_TYPE TABLE_CLASS COLUMN_CLASS) {
		$p->{$k}=$self->{$k};
	}
	$p->{TABLENAME_LIST}={};
	$p->{CONSTRAINT_LIST}={};
	for my $k qw(TABLE_PREFIX VIEW_PREFIX SEQUENCE_PREFIX) {
		$p->{$k}='' unless defined $p->{$k};
	}
	$p->{XML_NAMESPACES}=_autodetect_xml_namespaces($file_name);
	return _parse($r,%$p);
}


sub new {
	my ($class,%params)=@_;
	my $namespace=$params{DB_NAMESPACE};
	croak "no param DB_NAMESPACE spec" unless defined $namespace;

	for my $cl qw(catalog table column) {
		my $class=uc($cl).'_CLASS';
		$params{$class}='blx::xsdsql::xml::'.$namespace.'::'.$cl;
		ev('use',$params{$class});
	}
	$params{ANONYMOUS_COLUMN}=$params{COLUMN_CLASS}->new;
	$params{ID_SQL_TYPE}=$params{ANONYMOUS_COLUMN}->factory_column(qw(ID))->get_attrs_value(qw(TYPE));
	return bless \%params,$class;
}
	
sub get_db_namespaces {
	my @n=();
	for my $i(@INC) {
		my $dir=File::Spec->catdir($i,'blx','xsdsql','xml');
		next unless  -d $dir;
		next if $dir=~/^\./;
		next unless opendir(my $fd,$dir);
		while(my $d=readdir($fd)) {
			next if $d=~/^\./;
			next unless -d File::Spec->catdir($dir,$d);
			push @n,$d;
		}
		closedir($fd);
	}
	return wantarray ? @n : \@n;
}


if ($0 eq __FILE__) { #for local test
	use strict;
	use warnings;
	use Data::Dumper;
	my $p=blx::xsdsql::parser->new(DB_NAMESPACE => 'pg'); 
	my $root_table=$p->parsefile($ARGV[0],SCHEMA_DUMPER => $ARGV[1]);
	#print STDERR Dumper($t);
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
		DB_NAMESPACE 	=>   database namespace  (default not set) 
		DEBUG		 	=> 	 set debug mode

parsefile - parse a xsd file
 
	the first param must be an object compatible with the input of Rinchi::XMLSchema::parsefile, normally a file name    
	the method return a blx::xsdsql::schema object
	
	PARAMS:
		TABLE_PREFIX 				=>  prefix for tables - the default is none
		VIEW_PREFIX  				=>  prefix for views  - the default is none
		SEQUENCE_PREFIX 			=>  prefix for the sequences - the default is none
		ROOT_TABLE_NAME				=>  the name of the root table - the default is 'ROOT'
		TABLE_DICTIONARY_NAME 		=>  the name of the table dictionary
		COLUMN_DICTIONARY_NAME 		=>  the name of the colunm dictionary
		RELATION_DICTIONARY_NAME 	=>  the name of the relation dictionary
		SCHEMA_DUMPER 				=>  print on STDERR the dumper of the schema generated by Runchi::XMLSchema
		DEBUG		 				=>  set debug mode
		NO_FLAT_GROUPS				=>  no flat the columns of table groups with maxoccurs <= 1 into the ref table

get_db_namespaces - static method 

	the method return an array of database namespace founded (Ex: pg) 


=head1 EXPORT

None by default.


=head1 EXPORT_OK
	
None

=head1 SEE ALSO

See blx:.xsdsql::generator for generate the schema of the database and blx::xsdsql:xml from read/write a xml file from/into a database 

=head1 AUTHOR

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
