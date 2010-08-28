package blx::xsdsql::xml;

use strict;
use warnings;
use integer;
use Carp;
use XML::Parser;
use XML::Writer;
use File::Basename;
use blx::xsdsql::ut qw( nvl ev);

use constant {
	 NO_REF_PATH => ': internal error - no such column with ref this path '
	,NO_PATH_RESOLVED => ': internal error - no path resolved '
	,STACK_CORRUPTED => ': stack corrupted'
	,NO_SUCH_COLUMN => ': no such column'
	
};


sub _find_column_from_path_reference {
	my $self=shift;
	my $path=shift;
	my $r=$self->{COLUMNS}->{PATH_REFERENCE}->{$path};
	return defined $r ? @$r : (); #put  a tupla (table,column)
}

sub _get_sql_binding {
	my $self=shift;
	return $self->{SQL_BINDING}->get_clone;
}

my %H=(
	Start	=>   sub {
		my $self=$_[0]->{LOAD_INSTANCE};		
		my $path=$self->_decode('/'.join('/',(@{$_[0]->{Context}},($_[1]))));
		my $table=$self->{TABLES}->{PATH}->{$path};
		if  (defined $table && !$table->get_attrs_value qw(TABLE_IS_TYPE))  {	 # is e path for a table not type
			print STDERR "> $path\n" if $self->{DEBUG};
			my $parent=$self->{STACK}->[-1];
			$self->{PREPARED}->{$table->get_sql_name}->{INSERT}=$self->_get_sql_binding
				unless defined $self->{PREPARED}->{$table->get_sql_name}->{INSERT};
			unless (defined $parent->{INDIRECT_REF}->{PREPARED})  {  # this is the first child
				my ($parent_table,$parent_column) = $self->_find_column_from_path_reference($path);
				confess $path.NO_REF_PATH unless defined $parent_column;
				if ($parent_table->get_sql_name eq $parent->{TABLE}->get_sql_name) {  #Ok $table is relationated 1 <-> 1 with the parent
					$self->{PREPARED}->{$table->get_sql_name}->{INSERT}->insert_binding($table,TAG => __LINE__);
					my ($id)=$self->{PREPARED}->{$table->get_sql_name}->{INSERT}->get_binding_values(PK_ONLY => 1);
					$parent->{PREPARED}->bind_column($parent_column,$id,TAG => __LINE__); #bound the parent column with the child
				}
				else {
					#the reference is 1 to many - search the column relationated with $table into the stack
					($parent->{INDIRECT_REF}->{TABLE},$parent->{INDIRECT_REF}->{COLUMN})=$self->_find_column_from_path_reference($path);	
					confess $path.NO_REF_PATH unless defined $parent->{INDIRECT_REF}->{COLUMN};
					$parent->{INDIRECT_REF}->{PREPARED}=$self->_get_sql_binding;
					$parent->{INDIRECT_REF}->{PREPARED}->insert_binding($parent->{INDIRECT_REF}->{TABLE},TAG => __LINE__);
					my $path_resolved=$parent->{INDIRECT_REF}->{TABLE}->get_attrs_value qw(PATH_RESOLVED);
					confess $parent->{INDIRECT_REF}->{TABLE}->get_sql_name.NO_PATH_RESOLVED  unless defined $path_resolved;
					$parent_column=$parent->{TABLE}->find_columns(PATH_REFERENCE => $path_resolved);
					my ($id,$seq)=$parent->{INDIRECT_REF}->{PREPARED}->get_binding_values(PK_ONLY => 1);
					$self->{PREPARED}->{$parent->{TABLE}->get_sql_name}->{INSERT}->bind_column($parent_column,$id,TAG => __LINE__);
					$self->{PREPARED}->{$table->get_sql_name}->{INSERT}->insert_binding($table,TAG => __LINE__);
					($id)=$self->{PREPARED}->{$table->get_sql_name}->{INSERT}->get_binding_values(PK_ONLY => 1); 
					$parent->{INDIRECT_REF}->{PREPARED}->bind_column($parent->{INDIRECT_REF}->{COLUMN},$id,TAG => __LINE__);
				}
			}
			else {  #indirect ref with seq > 0 (not first child)
				my $parent_column = $parent->{INDIRECT_REF}->{TABLE}->find_columns(PATH_REFERENCE => $path); 
				confess $path.NO_REF_PATH unless defined $parent_column;
				$self->{PREPARED}->{$table->get_sql_name}->{INSERT}->insert_binding($table,TAG => __LINE__);
				if ($parent_column->get_attrs_value qw(XSD_SEQ) <= $parent->{INDIRECT_REF}->{COLUMN}->get_attrs_value qw(XSD_SEQ)) { #set a new sequence
					$parent->{INDIRECT_REF}->{PREPARED}->execute(TAG => __LINE__); 	#register the pred sequence
					my ($id,$seq)=$parent->{INDIRECT_REF}->{PREPARED}->get_binding_values(PK_ONLY => 1);
					$parent->{INDIRECT_REF}->{PREPARED}->insert_binding($parent->{INDIRECT_REF}->{TABLE},PK_SEQ_VALUES => [ $id,++$seq],TAG => __LINE__);					
					($id)=$self->{PREPARED}->{$table->get_sql_name}->{INSERT}->get_binding_values(PK_ONLY => 1);
					$parent->{INDIRECT_REF}->{PREPARED}->bind_column($parent_column,$id,TAG => __LINE__);
				}
				else {
						confess $path.": not implemented";
				}
				$parent->{INDIRECT_REF}->{COLUMN}=$parent_column;
			}
			push @{$self->{STACK}},{  ORIG_PATH_NAME	=>  $path,TABLE => $table,PREPARED => $self->{PREPARED}->{$table->get_sql_name}->{INSERT}  };
		}
		elsif (scalar(@{$self->{STACK}}) > 0) {	#init the value of the current column
			my $node_current_table=$self->{STACK}->[-1];
			my $column_path=$node_current_table->{TABLE}->get_attrs_value(qw(TABLE_IS_TYPE)) 
					? $node_current_table->{TABLE}->resolve_path_for_table_type($node_current_table->{ORIG_PATH_NAME},$path)
					: $path;
			my $column=$node_current_table->{TABLE}->find_columns(PATH => $column_path);
			if (defined($column)) {
				my $path_ref=$column->get_attrs_value qw(PATH_REFERENCE);
				if (defined $path_ref) {  #the column reference a other table 
					my $table_ref=$self->{TABLES}->{PATH}->{$path_ref};
					$self->{PREPARED}->{$table_ref->get_sql_name}->{INSERT}=$self->_get_sql_binding
						unless defined  $self->{PREPARED}->{$table_ref->get_sql_name}->{INSERT};
					if (!defined $node_current_table->{COLUMN_REFERENCE} || $node_current_table->{COLUMN_REFERENCE}->{NAME} ne $column->get_sql_name) {
						$self->{PREPARED}->{$table_ref->get_sql_name}->{INSERT}->insert_binding($table_ref,TAG => __LINE__);
						$node_current_table->{COLUMN_REFERENCE} = {
																		NAME	=> 	   $column->get_sql_name
																		,PREPARED =>   $self->{PREPARED}->{$table_ref->get_sql_name}->{INSERT} 
																  };
						$self->{PREPARE}->{$node_current_table->{TABLE}->get_sql_name}=$self->_get_sql_binding
							unless (defined $self->{PREPARE}->{$node_current_table->{TABLE}->get_sql_name});
						my ($id,$seq)=$node_current_table->{COLUMN_REFERENCE}->{PREPARED}->get_binding_values(PK_ONLY => 1);
						$self->{PREPARED}->{$node_current_table->{TABLE}->get_sql_name}->{INSERT}->bind_column($column,$id,TAG => __LINE__);				
					}
					else {
						my ($id,$seq)=$node_current_table->{COLUMN_REFERENCE}->{PREPARED}->get_binding_values(PK_ONLY => 1);
						$node_current_table->{COLUMN_REFERENCE}->{PREPARED}->insert_binding(undef,PK_SEQ_VALUES => [ $id,++$seq],TAG => __LINE__)
					}																																					  
																	  
					push @{$self->{STACK}},{  
						TABLE				=> $table_ref
						,ORIG_PATH_NAME 	=> $path
						,REF_FROM_COLUMN	=> $node_current_table->{COLUMN_REFERENCE}
						,VALUE				=> $column->is_internal_reference ? '' : undef
					};
				}
				else { 
					$node_current_table->{VALUE}=''; #init the value
				}
			}
			else {
				confess $path.NO_PATH_RESOLVED;
			}
		}
		else {
		   confess  "$path: stack corrupted";
		}
	}
	,End	=>  sub {
		my $self=$_[0]->{LOAD_INSTANCE};		
		return undef if scalar(@{$self->{STACK}}) == 0;
		my $path=$self->_decode('/'.join('/',(@{$_[0]->{Context}},($_[1]))));
		my $node_current_table=$self->{STACK}->[-1];
		my $table_name=$node_current_table->{TABLE}->get_sql_name;
		if ($path eq nvl($node_current_table->{ORIG_PATH_NAME})) {	 #  is the end of data into a table
			print STDERR "< $path\n" if $self->{DEBUG};
			$node_current_table->{INDIRECT_REF}->{PREPARED}->execute(TAG => __LINE__) if defined $node_current_table->{INDIRECT_REF}->{PREPARED};
			my $sth=$self->{PREPARED}->{$table_name}->{INSERT};
			if (defined $node_current_table->{REF_FROM_COLUMN}) {
				my ($id,$seq)=$node_current_table->{REF_FROM_COLUMN}->{PREPARED}->get_binding_values(PK_ONLY => 1);
				my $col=$node_current_table->{TABLE}->find_columns(PK_SEQ => 0) || confess NO_SUCH_COLUMN;
				$sth->bind_column($col,$id,TAG => __LINE__);
				$col=$node_current_table->{TABLE}->find_columns(PK_SEQ => 1) || confess NO_SUCH_COLUMN;
				$sth->bind_column($col,$seq,TAG => __LINE__);
				if (defined $node_current_table->{VALUE}) {
					my $col=$node_current_table->{TABLE}->find_columns(VALUE_COL => 1) || confess NO_SUCH_COLUMN;
					$sth->bind_column($col,$node_current_table->{VALUE},TAG => __LINE__);
				}				
				print STDERR "$table_name: insert row ($id,$seq)\n"	 if $self->{DEBUG};
			}
			else {
				#empty 
			}
			$sth->execute(TAG => __LINE__);
			pop @{$self->{STACK}};
		}
		else {	 #is a column
			my $column_path=$node_current_table->{TABLE}->get_attrs_value(qw(TABLE_IS_TYPE)) 
					? $node_current_table->{TABLE}->resolve_path_for_table_type($node_current_table->{ORIG_PATH_NAME},$path)
					: $path;
			my $column=$node_current_table->{TABLE}->find_columns(PATH => $column_path);
			confess $path.NO_SUCH_COLUMN  unless defined $column;
			my $value=delete $node_current_table->{VALUE};
			print STDERR $path,' => \'',nvl($value,'<undef>'),"'\n" if $self->{DEBUG};
			my $sth=$self->{PREPARED}->{$table_name}->{INSERT};
			$sth->bind_column($column,$value,TAG => __LINE__);
		}
	}
	,Char		=> sub {
		my $self=$_[0]->{LOAD_INSTANCE};		
#		return undef if scalar(@{$self->{STACK}}) <=1;
		return undef if scalar(@{$self->{STACK}}) < 1;
		my ($path,$value)=($self->_decode('/'.join('/',@{$_[0]->{Context}})),$self->_decode($_[1]));
		my $node_current_table=$self->{STACK}->[-1];
		$node_current_table->{VALUE}.=$value if defined $node_current_table->{VALUE};
	}
);

sub get_handler {
	my $self=shift;
	return %H;
}


sub _decode {
	my $self=shift;
	return $_[0] if scalar(@_) <= 1;
	return @_;
}

sub _generate_table {
	my $self=shift;
	my $table=shift;
	my %params=@_;
	$params{TABLES_LIST}->{PATH}->{ $table->{PATH} }=$table if defined $table->{PATH};
	$params{TABLES_LIST}->{NAME}->{ $table->get_sql_name }=$table;
	return $params{TABLES_LIST};
}	

sub _get_tables {
	my $self=shift;
	my $table=shift;
	my %params=@_;
	$params{TABLES_LIST}={ PATH => {},NAME => {} }  if nvl($table->{PATH}) eq '/';
	$self->_generate_table($table,%params);
	for my $t($table->get_child_tables) {
		$self->_get_tables($t,%params);
	}
	if (nvl($table->{PATH}) eq '/') {
		for my $t(@{$table->{TYPES}}) {
			$self->_get_tables($t,%params);
		}
	}
	return nvl($table->{PATH}) eq '/' ? delete $params{TABLES_LIST} : undef; 
}

sub _generate_column {
	my $self=shift;
	my $table=shift;
	my %params=@_;
	for my $col($table->get_columns) {
		my $path=$col->get_attrs_value qw(PATH_REFERENCE);
		next unless defined $path;
		$params{COLUMNS_LIST}->{PATH_REFERENCE}->{$path}=[$table,$col];  
	}
	return $self;
}

sub _get_columns { #assoc a path_reference to a table,column
	my $self=shift;
	my $table=shift;
	my %params=@_;
	$params{COLUMNS_LIST}={ PATH_REFERENCE => {} }  if nvl($table->{PATH}) eq '/';
	$self->_generate_column($table,%params);
	for my $t($table->get_child_tables) {
		$self->_get_columns($t,%params);
	}
	if (nvl($table->{PATH}) eq '/') {
		for my $t(@{$table->{TYPES}}) {
			$self->_get_columns($t,%params);
		}
	}
	return nvl($table->{PATH}) eq '/' ? delete $params{COLUMNS_LIST} : undef; 
}

sub _write_xml {
	my ($self,%params)=@_;
	my %fixed_params=%params;
	for my $k ( @{$params{NOT_FIXED_PARAMS}} ) {
		delete $fixed_params{$k}
	}
	if (defined $params{ROOT_ROW}) {
		$self->{OUTPUT_STREAM}->xmlDecl($params{ENCODING},$params{STANDALONE});
		my $row=$params{ROOT_ROW};
		my @cols=$self->{ROOT}->get_columns;
		if ($params{DELETE_ROWS}) {
			my $table=$self->{ROOT};
			$self->{PREPARED}->{$table->get_sql_name}->{DELETE}=$self->_get_sql_binding
				unless defined $self->{PREPARED}->{$table->get_sql_name}->{DELETE};
			$self->{PREPARED}->{$table->get_sql_name}->{DELETE}->delete_rows_for_id($table,$row->[0],TAG => __LINE__);
		}
		for my $i(1..scalar(@$row) - 1) {
			next unless defined $row->[$i];
			my $col=$cols[$i];
			my $path_reference=$col->get_attrs_value(qw(PATH_REFERENCE));
			if (defined $path_reference) {
				my $table=$self->{TABLES}->{PATH}->{$path_reference};
				my $tag=basename($table->get_attrs_value qw(PATH));
				$self->{OUTPUT_STREAM}->startTag($tag);
				$self->{PREPARED}->{$table->get_sql_name}->{QUERY}=$self->_get_sql_binding
					unless defined $self->{PREPARED}->{$table->get_sql_name}->{QUERY};
				$self->_write_xml(ID => $row->[$i],TABLE	=> $table,LEVEL	=> 1,%fixed_params);
				$self->{OUTPUT_STREAM}->endTag($tag) if defined $tag;
			}
			else { # this is a simple xml 
				my $table=$self->{ROOT};
#				$self->_write_xml(ID => $row->[0],TABLE	=> $table,LEVEL	=> 1,%fixed_params);
				$self->_write_xml(ROW_FOR_ID => $row,TABLE	=> $table,LEVEL	=> 1,%fixed_params);
			}
			$self->{OUTPUT_STREAM}->end;
			return $self;
		}
		croak "no such column for xml root";
	}

	my $table=$params{TABLE};
	my $r=$params{ROW_FOR_ID};
	unless (defined $r) {
		$self->{PREPARED}->{$table->get_sql_name}->{QUERY}=$self->_get_sql_binding
			unless defined $self->{PREPARED}->{$table->get_sql_name}->{QUERY};
		$r=$self->{PREPARED}->{$table->get_sql_name}->{QUERY}->query_rows($table,$params{ID},TAG => __LINE__)->fetchrow_arrayref;
	}
	my $id=undef;

	if ($params{DELETE_ROWS}) {
		$self->{PREPARED}->{$table->get_sql_name}->{DELETE}=$self->_get_sql_binding
			unless defined $self->{PREPARED}->{$table->get_sql_name}->{DELETE};
		$self->{PREPARED}->{$table->get_sql_name}->{DELETE}->delete_rows_for_id($table,$r->[0],TAG => __LINE__);
	}
	for my $i(1..scalar(@$r) - 1) {
		my $col=($table->get_columns)[$i];
		#$id=$r->[$i] if $col->{COLUMN_NAME} eq 'ID';
		next unless defined  $col->get_attrs_value qw(XSD_SEQ);
		my $value=$r->[$i];
		next unless defined $value;
		if (defined $col->get_attrs_value qw(PATH_REFERENCE)) {
			my $table=$self->{TABLES}->{PATH}->{$col->get_attrs_value(qw(PATH_REFERENCE))};
			$table=$self->{TABLES}->{NAME}->{$col->get_attrs_value(qw(PATH_REFERENCE))} unless defined $table;
			croak $col->get_attrs_value qw(PATH_REFERENCE),': no such table with this PATH_REFERENCE' unless defined $table;
			if (!$col->is_internal_reference) {
				if (defined $table->get_attrs_value qw(PATH)) {
					if (!$table->get_attrs_value qw(TABLE_IS_TYPE)) { 
						my $tag=basename($table->get_attrs_value qw(PATH));
						$self->{OUTPUT_STREAM}->startTag($tag);
						$self->_write_xml(ID => $value,TABLE	=> $table,LEVEL	=> $params{LEVEL} + 1,%fixed_params);
						$self->{OUTPUT_STREAM}->endTag($tag);
					}
					else {  #the column reference a complex type
						$self->{PREPARED}->{$table->get_sql_name}->{QUERY}=$self->_get_sql_binding
							unless defined $self->{PREPARED}->{$table->get_sql_name}->{QUERY};
						my $cur=$self->{PREPARED}->{$table->get_sql_name}->{QUERY}->query_rows($table,$value,TAG => __LINE__);
						my $tag=basename($col->get_attrs_value qw(PATH));
						if ($params{DELETE_ROWS}) {
							$self->{PREPARED}->{$table->get_sql_name}->{DELETE}=$self->_get_sql_binding
								unless defined $self->{PREPARED}->{$table->get_sql_name}->{DELETE};
							$self->{PREPARED}->{$table->get_sql_name}->{DELETE}->delete_rows_for_id($table,$value,TAG => __LINE__);
						}
						while(my $r=$cur->fetchrow_arrayref()) {
							$self->{OUTPUT_STREAM}->startTag($tag);
							$self->_write_xml(TABLE	=> $table,LEVEL	=> $params{LEVEL} + 1,ROW_FOR_ID	=> $r,%fixed_params);	
							$self->{OUTPUT_STREAM}->endTag($tag);
						}
					}
				}
				else {	# is a sequence table
					$self->{PREPARED}->{$table->get_sql_name}->{QUERY}=$self->_get_sql_binding
						unless defined $self->{PREPARED}->{$table->get_sql_name}->{QUERY};
					my $cur=$self->{PREPARED}->{$table->get_sql_name}->{QUERY}->query_rows($table,$value,TAG => __LINE__);
					if ($params{DELETE_ROWS}) {
						$self->{PREPARED}->{$table->get_sql_name}->{DELETE}=$self->_get_sql_binding
							unless defined $self->{PREPARED}->{$table->get_sql_name}->{DELETE};
						$self->{PREPARED}->{$table->get_sql_name}->{DELETE}->delete_rows_for_id($table,$value,TAG => __LINE__);
					}
					while(my $r=$cur->fetchrow_arrayref()) {
						$self->_write_xml(TABLE	=> $table,LEVEL	=> $params{LEVEL},ROW_FOR_ID	=> $r,%fixed_params);	
					}
				}
			}
			else   { #the column reference a simple type
				$self->{PREPARED}->{$table->get_sql_name}->{QUERY}=$self->_get_sql_binding
					unless defined $self->{PREPARED}->{$table->get_sql_name}->{QUERY};
				my $cur=$self->{PREPARED}->{$table->get_sql_name}->{QUERY}->query_rows($table,$value,TAG => __LINE__);
				my $tag=basename($col->get_attrs_value qw(PATH));
				while (my $r=$cur->fetchrow_arrayref()) {
#					$self->{OUTPUT_STREAM}->put_line("\t"x$params{LEVEL},"<$tag>",$r->[2],"</$tag>");
					$self->{OUTPUT_STREAM}->dataElement($tag,$r->[2]);                              
				}
				if ($params{DELETE_ROWS}) {
					$self->{PREPARED}->{$table->get_sql_name}->{DELETE}=$self->_get_sql_binding
						unless defined $self->{PREPARED}->{$table->get_sql_name}->{DELETE};
					$self->{PREPARED}->{$table->get_sql_name}->{DELETE}->delete_rows_for_id($table,$value,TAG => __LINE__);
				}
			}
		}
		else {
			my $path=$col->get_attrs_value qw(PATH);
			if (defined ($path)) {
				my $tag=basename($path);
				$self->{OUTPUT_STREAM}->dataElement($tag,$value);                              
			}
		}
	}
	return  $self;
}

sub new {
	my ($class,%params)=@_;
	$params{PARSER}=XML::Parser->new unless defined $params{PARSER};
	$params{XMLWRITER}=XML::Writer->new unless defined $params{XMLWRITER};
	unless (defined $params{SQL_BINDING}) {
		croak "DB_NAMESPACE param not def" unless defined $params{DB_NAMESPACE};
		croak "DB_CONN param not def" unless defined $params{DB_CONN};
		my $sql_binding='blx::xsdsql::xml::'.$params{DB_NAMESPACE}.'::sql_binding';
		ev('use',$sql_binding);
		$params{SQL_BINDING}=$sql_binding->new(%params);
	}
	my $self=bless \%params,$class;
	($self->{TABLES},$self->{COLUMNS})=($self->_get_tables($params{ROOT_TABLE},%params),$self->_get_columns($params{ROOT_TABLE},%params))
		if defined $params{ROOT_TABLE};
	return $self;
}

sub read {
	my $self=shift;	
	my %params=@_;
	my $fd=nvl($params{FD},*STDIN); 
	my $root=nvl($params{ROOT_TABLE},$self->{ROOT_TABLE});
	croak "ROOT_TABLE param not spec" unless defined $root;
	$self->{PARSER}->setHandlers($self->get_handler);
	my ($old_tables,$old_columns,$old_schema);
	if (defined $params{ROOT_TABLE}) {
		($old_tables,$self->{TABLES})=($self->{TABLES},$self->_get_tables($root,%params));
		($old_columns,$self->{COLUMNS})=($self->{COLUMNS},$self->_get_columns($root,%params));
	}
	my $root_key=$root->get_sql_name;
	$self->{PREPARED}->{$root_key}->{INSERT}=$self->_get_sql_binding;
	$self->{PREPARED}->{$root_key}->{INSERT}->insert_binding($root,TAG => __LINE__);
	$self->{STACK}=[ { TABLE => $root,PREPARED =>  $self->{PREPARED}->{$root_key}->{INSERT} } ];
	$self->{PARSER}->parse($fd,ROOT => $root,LOAD_INSTANCE => $self);
	$self->{PREPARED}->{$root_key}->{INSERT}->execute(TAG => __LINE__);
	my $id=($self->{PREPARED}->{$root_key}->{INSERT}->get_binding_values)[0];
	if (defined $params{ROOT_TABLE}) {
		($self->{TABLES},$self->{COLUMNS})=($old_tables,$old_columns); 
		$self->finish qw(INSERT);
	}
	return $id;
}


sub write {
	my $self=shift;
	my %params=@_;
	my $fd=nvl($params{FD},*STDOUT);
	$self->{XMLWRITER}->setOutput($fd);
	$self->{OUTPUT_STREAM}=$self->{XMLWRITER};
	my $root_id=nvl($params{ROOT_ID},$self->{ROOT_ID});
	my $root_table=nvl($params{ROOT_TABLE},$self->{ROOT_TABLE});
	croak "ROOT_ID param not spec" unless defined $root_id;
	croak "ROOT_TABLE param not spec" unless defined $root_table;
	return undef unless $root_id=~/^\d+$/;
	$self->{PREPARED}->{$root_table->get_sql_name}->{QUERY}=$self->_get_sql_binding;
	my $root_row=$self->{PREPARED}->{$root_table->get_sql_name}->{QUERY}->query_rows($root_table,$root_id,TAG => __LINE__)->fetchrow_arrayref;
	if (defined $root_row) {
		my @not_fixed_params = qw(ROOT_ROW LEVEL TABLE ID  ROW_FOR_ID ); #params not passed in recursive
		$self->{ROOT}=$root_table;
		my ($old_tables,$old_columns,$old_schema);
		if (defined $params{ROOT_TABLE}) {
			($old_tables,$self->{TABLES})=($self->{TABLES},$self->_get_tables($params{ROOT_TABLE},%params));
			($old_columns,$self->{COLUMNS})=($self->{COLUMNS},$self->_get_columns($params{ROOT_TABLE},%params));
		}
		($old_schema,$self->{SCHEMA_NAME})=($self->{SCHEMA_NAME},$params{SCHEMA_NAME}) if defined  $params{SCHEMA_NAME};
		$self->_write_xml(NOT_FIXED_PARAMS => \@not_fixed_params,LEVEL => 0,ROOT_ROW => $root_row,DELETE_ROWS => $params{DELETE_ROWS});
		delete $self->{ROOT};
		($self->{TABLES},$self->{COLUMNS})=($old_tables,$old_columns) if defined $params{ROOT_TABLE};
		$self->{SCHEMA_NAME}=$old_schema if defined $params{SCHEMA_NAME};
	}
	$self->finish(('QUERY',$params{DELETE} ? 'DELETE' : ())) if defined $params{ROOT_TABLE};
	return defined $root_row ? $self : undef;
}

sub finish {
	my $self=shift;
	if (defined $self->{PREPARED}) {
		for my $k(keys %{$self->{PREPARED}}) {
			next unless scalar(@_) == 0 || grep($_ eq $k,@_);
			for my $j(keys %{$self->{PREPARED}->{$k}}) { 
				delete($self->{PREPARED}->{$k}->{$j})->finish;
			}
		}
	}
	return $self;
}

sub DESTROY { $_[0]->finish; }

1;

__END__

=head1  NAME

blx::xsdsql::xml - read/write xml file from/to sql database 

=cut

=head1 SYNOPSIS

use blx::xsdsql::xml

=cut


=head1 DESCRIPTION

this package is a class - instance it with the method new


=head1 FUNCTIONS

this module defined the followed functions

new - constructor   
	
	PARAMS:
		XMLWRITER  => instance of class XML::Writer
			if is not set the object instance automatically
		XMLPARSER  => instance of class XML::Parser
			if is not set the object instance automatically
		SQL_BINDING => instance of class blx::xsdsql::xml::sql_binding or a subclass
			if is not set the object instance automatically 
			but then params DB_NAMESPACE and DB_CONN must be set
		DB_NAMESPACE => set the property (Es: pg for postgres or oracle for oracle) used only if SQL_BINDING is not set
		DB_CONN     => DBI connection used only if SQL_BINDING is not set
		ROOT_TABLE => tree object tables - this is the output of method blx:.xsdsql::parser::parse



read - read a xml file and put into the database
	
	PARAMS:
		FD   =>  input file description (default stdin) 
		ROOT_TABLE => root_table object (default param ROOT_TABLE in the constructor)
	the method return the id inserted into the  root table


write - write a xml from a database

	PARAMS:
		FD - output file descriptor (default stdout)
		ROOT_TABLE => root_table object (default param ROOT_TABLE in the constructor)
		ROOT_ID    => root_id - the result of the method read
		DELETE_ROWS     => if true write to FD e delete the rows from the database
	the method return the self object if root_id exist in the database else return undef



finish -  close the sql statement prepared
	
	the method return the self object

=cut



=head1 EXPORT

None by default.


=head1 EXPORT_OK
	
none 

=head1 SEE ALSO

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
