package blx::xsdsql::xml;

use strict;
use warnings FATAL => 'all';
use integer;
use Carp;
use XML::Parser;
use XML::Writer;
use File::Basename;
use Data::Dumper;
use blx::xsdsql::ut qw( nvl ev);


sub _fusion_params {
	my ($self,%params)=@_;
	my %p=%$self;
	for my $p(keys %params) {
		$p{$p}=$params{$p};
	}
	return \%p;
}


sub _prepared_insert {
	my ($self,$table,%params)=@_;
	croak "not table def " unless defined $table;
	my $sqlname=$table->get_sql_name;
	$self->{PREPARED}->{$sqlname}->{INSERT}=$self->{SQL_BINDING}->get_clone
		unless defined $self->{PREPARED}->{$sqlname}->{INSERT};
	$self->{PREPARED}->{$sqlname}->{INSERT}->insert_binding($table,TAG => $params{TAG});
	return $self->{PREPARED}->{$sqlname}->{INSERT};
}

sub _insert_seq_inc {
	my ($p,%params)=@_; 
	my $colv=($p->get_binding_columns(PK_ONLY => 1))[1];
	$p->insert_binding(undef,TAG => $params{TAG},NO_PK => 1);
	$p->bind_column($colv->{COL},$colv->{VALUE} + 1,TAG => $params{TAG});
	return $p;
}


sub _prepared_query {
	my ($self,$table,%params)=@_;
#	print STDERR $params{TAG},": table arg not set\n" if defined $params{TAG} && ! $table;
#	confess $params{TAG}.": table arg not set\n" unless $table; 
	confess $params{TAG}.": ID param not set\n" if exists $params{ID} && ! defined $params{ID}; 
	my $sqlname=$table->get_sql_name;
	$self->{PREPARED}->{$sqlname}->{QUERY}=$self->{SQL_BINDING}->get_clone
		unless defined $self->{PREPARED}->{$sqlname}->{QUERY};
	return $self->{PREPARED}->{$sqlname}->{QUERY}->query_rows($table,$params{ID},TAG => $params{TAG})
		if defined $params{ID};
	return $self->{PREPARED}->{$sqlname}->{QUERY};
}

sub _prepared_delete {
	my ($self,$table,%params)=@_;
	my $sqlname=$table->get_sql_name;
	$self->{PREPARED}->{$sqlname}->{DELETE}=$self->{SQL_BINDING}->get_clone
		unless defined $self->{PREPARED}->{$sqlname}->{DELETE};
	$self->{PREPARED}->{$sqlname}->{DELETE}->delete_rows_for_id($table,$params{ID},TAG => $params{TAG})
		if defined $params{ID};
	return $self->{PREPARED}->{$sqlname}->{DELETE};
}


sub _read {
	my ($self,%params)=@_;	
	my $p=$self->_fusion_params(%params);
	my $fd=nvl($p->{FD},*STDIN); 
	my $schema=$p->{SCHEMA};
	croak "SCHEMA param not set" unless defined $schema;
	$self->{_PARAMS}=$p;
	$p->{SQL_BINDING}->set_attrs_value(SEQUENCE_NAME => $schema->get_sequence_name)
		unless defined $p->{SQL_BINDING}->get_attrs_value qw(SEQUENCE_NAME); 
	$self->{PARSER}->setHandlers($self->get_handler);
	my $root=$schema->get_root_table;
	my $insert=$self->_prepared_insert($root,TAG => __LINE__);
	$self->{STACK}=[ { TABLE => $root,PREPARED =>  $insert } ];
	$self->{PARSER}->parse($fd,ROOT => $root,LOAD_INSTANCE => $self);
	$insert->execute(TAG => __LINE__);
	my $id=($insert->get_binding_values)[0];
	return $id;
}


sub _write {
	my ($self,%params)=@_;
	my $p=$self->_fusion_params(%params);
	my $fd=nvl(delete $p->{FD},*STDOUT); 
	my $schema=$p->{SCHEMA};
	croak "SCHEMA param not set" unless defined $schema;
	$self->{_PARAMS}=$p;
	$p->{SQL_BINDING}->set_attrs_value(SEQUENCE_NAME => $schema->get_sequence_name)
		unless defined $p->{SQL_BINDING}->get_attrs_value qw(SEQUENCE_NAME); 
	$p->{XMLWRITER}->setOutput($fd);
	$p->{OUTPUT_STREAM}=$p->{XMLWRITER};
	my $root_id=$p->{ROOT_ID};
	my $root_table=$schema->get_root_table;
	croak "ROOT_ID param not spec" unless defined $root_id;
	$self->{_PARAMS}=$p;
	return undef unless $root_id=~/^\d+$/;
	my $root_row=$self->_prepared_query($root_table,ID => $root_id,TAG => __LINE__)->fetchrow_arrayref;
	if (defined $root_row) {
		$self->_write_xml(LEVEL => 0,ROOT_ROW => $root_row,TABLE => $root_table);
	}
	$self->finish(('QUERY',$p->{DELETE} ? 'DELETE' : ())) if defined $params{SCHEMA} || defined $params{ROOT_ID};
	return defined $root_row ? $self : undef;
}


sub _execute {
	my ($self,$p,%params)=@_;
	my $r=ref($p);
	if ($r eq 'HASH') {
		for my $v(values %$p) {
			$self->_execute($v,%params);
		}
	}
	elsif ($r =~ /::sql_binding$/) {
		$p->execute(%params);
	}
}

sub _debug_tc {
	my ($self,$path,%params)=@_;
	my $tc=$self->{_PARAMS}->{SCHEMA}->resolve_path($path);
	if ($self->{DEBUG}) {
		if (ref($tc) eq 'HASH') {
			print STDERR "(D ".$params{TAG}.") '$path' mapping to column "
				,$tc->{T}->get_sql_name,'.'
				,$tc->{C}->get_sql_name,"\n";
		}
		elsif (ref($tc) eq 'ARRAY') {
			print STDERR "(D ",$params{TAG},") '$path' mapping to tables \n";
			for my $t(@$tc) {
				print STDERR "\t\t\t"
					,$t->{T}->get_sql_name
					,(defined $t->{C} ? '.'.$t->{C}->get_sql_name : '')
					,"\n";
			}
		}
		else {
			croak Dumper($tc).": not a hash or array";
		}
	}
	return $tc;
}

sub _unpath_table {
	my ($self,$stack,$tc,%params)=@_;
	confess $tc->{T}->get_sql_name.": table is not an unpath sequence table\n" unless $tc->{T}->is_unpath_sequence;
	my $prepared_tag=$tc->{T}->get_sql_name;
	if ($stack->{UNPATH_PREPARED}->{$prepared_tag}) {
		if 	($stack->{UNPATH_COLSEQ}->{$prepared_tag} >= $tc->{C}->get_column_sequence) {
			$stack->{UNPATH_PREPARED}->{$prepared_tag}->execute(TAG => __LINE__);
			_insert_seq_inc($stack->{UNPATH_PREPARED}->{$prepared_tag},TAG => __LINE__);
		}
	}
	else {
		my $sth=$self->_prepared_insert($tc->{T},TAG => __LINE__);
		my ($id)=$sth->get_binding_values(PK_ONLY => 1,TAG => __LINE__);
			confess "internal errror: {TABLE_REF_FROM}->{T} is not defined\n"
					." for ".$tc->{T}->get_sql_name."\n"
				 unless defined $tc->{TABLE_REF_FROM}->{T};

		my $p=$tc->{TABLE_REF_FROM}->{T}->is_unpath_sequence
				? $stack->{UNPATH_PREPARED}->{$tc->{TABLE_REF_FROM}->{T}->get_sql_name}
				: $stack->{PREPARED};
		$p->bind_column($tc->{TABLE_REF_FROM}->{C},$id,TAG => __LINE__);				
		$stack->{UNPATH_PREPARED}->{$prepared_tag}=$sth;
	}
	$stack->{UNPATH_COLSEQ}->{$prepared_tag}=$tc->{C}->get_column_sequence;
	return $stack->{UNPATH_PREPARED}->{$prepared_tag};
}

my %H=(
	Start	=>   sub {
		my $self=$_[0]->{LOAD_INSTANCE};		
		my $path=$self->_decode('/'.join('/',(@{$_[0]->{Context}},($_[1]))));
		print STDERR "(D ",__LINE__,") > '$path'\n" if $self->{DEBUG};
		my $stack=$self->{STACK}->[-1];
		my $tc=_debug_tc($self,$path,TAG => __LINE__);
		
		if (ref($tc) eq 'ARRAY') {  #is a path for a table
			my $table=$tc->[-1]->{T};
			my $table_name=$table->get_sql_name;
			if (scalar(@$tc) == 2) {
				my ($parent_table,$parent_column)=($tc->[0]->{T},$tc->[0]->{C});
				if ($parent_column->get_max_occurs > 1) {
					my $prepared_tag=$parent_column->get_sql_name;
					if ($stack->{EXTERNAL_REFERENCE}->{$prepared_tag}) {
						_insert_seq_inc($stack->{EXTERNAL_REFERENCE}->{$prepared_tag},TAG => __LINE__); #increment the value of the seq column
					}
					else {
						my $p=$self->_prepared_insert($parent_column->get_table_reference,TAG => __LINE__);
						my ($id)=$p->get_binding_values(PK_ONLY => 1,TAG => __LINE__);
						$stack->{PREPARED}->bind_column($parent_column,$id,TAG => __LINE__);
						$stack->{EXTERNAL_REFERENCE}->{$prepared_tag}=$p;
					}
					push @{$self->{STACK}},{  PREPARED => $self->{PREPARED}->{$table_name}->{INSERT}  };
				}
				else {
					$self->_prepared_insert($table,TAG => __LINE__);
					my ($id)=$self->{PREPARED}->{$table_name}->{INSERT}->get_binding_values(PK_ONLY => 1,TAG => __LINE__);
					$stack->{PREPARED}->bind_column($parent_column,$id,TAG => __LINE__);
					push @{$self->{STACK}},{  PREPARED => $self->{PREPARED}->{$table_name}->{INSERT}  };
 				}
			}
			else {
				confess "$path: tc return != 3 elements\n"  if scalar(@$tc) != 3;
				my ($gran_parent_table,$gran_parent_column)=($tc->[-3]->{T},$tc->[-3]->{C});
				my ($parent_table,$parent_column)=($tc->[-2]->{T},$tc->[-2]->{C});
				my ($curr_table,$curr_column)=($tc->[-1]->{T},$tc->[-1]->{C});
				my $parent_tag=$parent_table->get_sql_name;
				
				if ($parent_table->is_unpath_sequence) {
					if ($stack->{UNPATH_PREPARED}->{$parent_tag}) {
						#confess "not implemented\n";
						if 	($stack->{UNPATH_COLSEQ}->{$parent_tag} >= $parent_column->get_column_sequence) {
							$stack->{UNPATH_PREPARED}->{$parent_tag}->execute(TAG => __LINE__);
							_insert_seq_inc($stack->{UNPATH_PREPARED}->{$parent_tag},TAG => __LINE__);
						}
					}
					else {
						my $sth=$self->_prepared_insert($parent_table,TAG => __LINE__);
						my ($id)=$sth->get_binding_values(PK_ONLY => 1,TAG => __LINE__);				
						$stack->{PREPARED}->bind_column($gran_parent_column,$id,TAG => __LINE__);
						$stack->{UNPATH_PREPARED}->{$parent_tag}=$sth;
					}
					$stack->{UNPATH_COLSEQ}->{$parent_tag}=$parent_column->get_column_sequence;
				} 
				else {
					confess $table->get_sql_name.": not implemented\n";
				}
				my $sth=$self->_prepared_insert($curr_table,TAG => __LINE__);
				my ($id)=$sth->get_binding_values(PK_ONLY => 1,TAG => __LINE__);
				$stack->{UNPATH_PREPARED}->{$parent_tag}->bind_column($parent_column,$id,TAG => __LINE__);
				my $curr_tag=$curr_table->get_sql_name;
				push @{$self->{STACK}},{  PREPARED => $self->{PREPARED}->{$curr_tag}->{INSERT}  };
			}
		}
		elsif ($tc->{C}->is_internal_reference) { #the column is an occurs of simple types
			my $prepared_tag=$tc->{C}->get_sql_name;
			if ($stack->{INTERNAL_REFERENCE}->{$prepared_tag}) {
				_insert_seq_inc($stack->{INTERNAL_REFERENCE}->{$prepared_tag},TAG => __LINE__); #increment the value of the seq column
			}
			else {
				my $p=$self->_prepared_insert($tc->{C}->get_table_reference,TAG => __LINE__);
				my ($id)=$p->get_binding_values(PK_ONLY => 1,TAG => __LINE__);
				if ($stack->{PREPARED}->get_binding_table != $tc->{T}) {#$tc->{T} is an unpath sequence table
					my $sth=$self->_unpath_table($stack,$tc);
					$sth->bind_column($tc->{C},$id,TAG => __LINE__);
				} 
				else {
					$stack->{PREPARED}->bind_column($tc->{C},$id,TAG => __LINE__);
				}
				$stack->{INTERNAL_REFERENCE}->{$prepared_tag}=$p;
			}
			$stack->{VALUE}='';
		}
		elsif (my $table_ref=$tc->{C}->get_table_reference) {
			confess "$path: ref to '".$tc->{C}->get_path_reference."' not implemented";
		} 
		else {  #normal data column
			$stack->{VALUE}='';
			if ($tc->{T}->is_unpath_sequence) {
				my $sth=$self->_unpath_table($stack,$tc);
			}
			else {
					#empty
			}
		}
	}  # Start
	,End	=>  sub {
		my $self=$_[0]->{LOAD_INSTANCE};		
#		return undef if scalar(@{$self->{STACK}}) == 0;
		my $path=$self->_decode('/'.join('/',(@{$_[0]->{Context}},($_[1]))));
		print STDERR "(D ",__LINE__,") < '$path'\n" if $self->{DEBUG};
		my $stack=$self->{STACK}->[-1];
		my $tc=_debug_tc($self,$path,TAG => __LINE__);
		if (ref($tc) eq 'ARRAY') { #path ref a table
			delete $stack->{INTERNAL_REFERENCE};    #for execute in error
			delete $stack->{EXTERNAL_REFERENCE};    #for execute in error
			$self->_execute($stack,TAG => __LINE__);
			pop @{$self->{STACK}};
		}
		elsif ($tc->{C}->is_internal_reference) { #the column is an occours of simple types
			my $prepared_tag=$tc->{C}->get_sql_name;
			my $sth=$stack->{INTERNAL_REFERENCE}->{$prepared_tag};
			my $value_column=(($sth->get_binding_columns)[2])->{COL};
			$sth->bind_column($value_column,$stack->{VALUE},TAG => __LINE__);
			$sth->execute(TAG => __LINE__);
		}
		elsif (my $table_ref=$tc->{C}->get_table_reference) {
			confess "$path: ref to ".$tc->{C}->get_path_reference." not implemented";
		} 
		else { #normal data column
			if ($tc->{T}->is_unpath_sequence) {
				my $prepared_tag=$tc->{T}->get_sql_name;
				$stack->{UNPATH_PREPARED}->{$prepared_tag}->bind_column($tc->{C},$stack->{VALUE},TAG => __LINE__);
			}
			else {
				$stack->{PREPARED}->bind_column($tc->{C},$stack->{VALUE},TAG => __LINE__);
			}
		}
	}  #End
	,Char		=> sub {
		my $self=$_[0]->{LOAD_INSTANCE};		
		return undef if scalar(@{$self->{STACK}}) < 1;
		my ($path,$value)=($self->_decode('/'.join('/',@{$_[0]->{Context}})),$self->_decode($_[1]));
		my $stack=$self->{STACK}->[-1];
		$stack->{VALUE}.=$value if defined $stack->{VALUE};
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


sub _write_xml {
	my ($self,%params)=@_;
	my $p=$self->{_PARAMS};
	my $ostr=$p->{OUTPUT_STREAM};
	if (defined $params{ROOT_ROW}) {
		$ostr->xmlDecl($p->{ENCODING},$p->{STANDALONE});
		my $row=$params{ROOT_ROW};
		my $root=$p->{SCHEMA}->get_root_table;
		my @cols=$root->get_columns;
		$self->_prepared_delete($root,ID => $row->[0],TAG => __LINE__) if $p->{DELETE_ROWS};

	
		for my $i(1..scalar(@$row) - 1) {
			next unless defined $row->[$i];
			my $col=$cols[$i];
			if (my $table=$col->get_table_reference) {
				my $tag=basename($table->get_attrs_value qw(PATH));
				{
					my %start_params=();
					$start_params{'xmlns:xsi'}=$p->{SCHEMA_INSTANCE} if defined $p->{SCHEMA_INSTANCE};
					$start_params{'xsi:noNamespaceSchemaLocation'}=$p->{SCHEMA_NAME} if defined $p->{SCHEMA_NAME};
					$ostr->startTag($tag,%start_params);
				}
				$self->_write_xml(ID => $row->[$i],TABLE	=> $table,LEVEL	=> 1);
				$ostr->endTag($tag) if defined $tag;
			}
			else { 
				$self->_write_xml(ROW_FOR_ID => $row,TABLE	=> $root,LEVEL	=> 1);
			}
			$ostr->end;
			return $self;
		}
		croak "no such column for xml root";
	}

	my $table=$params{TABLE};
	my $r=$params{ROW_FOR_ID};
	$r=$self->_prepared_query($table,ID => $params{ID},TAG => __LINE__)->fetchrow_arrayref unless defined $r;
	$self->_prepared_delete($table,ID => $r->[0],TAG => __LINE__) if $p->{DELETE_ROWS};

	for my $i(1..scalar(@$r) - 1) {
		my $col=($table->get_columns)[$i];
		next unless defined  $col->get_xsd_seq;
		my $value=$r->[$i];
		next unless defined $value;
		if (my $table=$col->get_table_reference) {
			if (!$col->is_internal_reference) {
				if (defined $table->get_attrs_value qw(PATH)) {
					if (!$table->is_type) { 
						my $tag=basename($table->get_attrs_value qw(PATH));
						$ostr->startTag($tag);
						$self->_write_xml(ID => $value,TABLE	=> $table,LEVEL	=> $params{LEVEL} + 1);
						$ostr->endTag($tag);
					}
					else {  #the column reference a complex type
						my $cur=$self->_prepared_query($table,ID => $value,TAG => __LINE__);
						my $tag=basename($col->get_attrs_value qw(PATH));
						$self->_prepared_delete($table,ID => $value,TAG => __LINE__) if $p->{DELETE_ROWS};
 						while(my $r=$cur->fetchrow_arrayref()) {
							if ($col->is_group_reference) {
								$self->_write_xml(TABLE	=> $table,LEVEL	=> $params{LEVEL},ROW_FOR_ID	=> $r);										
							}
							else {
								$ostr->startTag($tag);
								$self->_write_xml(TABLE	=> $table,LEVEL	=> $params{LEVEL} + 1,ROW_FOR_ID	=> $r);	
								$ostr->endTag($tag);
							}
						}
					}
				}
				else {	# is a sequence table
					my $cur=$self->_prepared_query($table,ID => $value,TAG => __LINE__);
					$self->_prepared_delete($table,ID => $value,TAG => __LINE__) if $p->{DELETE_ROWS};
					while(my $r=$cur->fetchrow_arrayref) {
						$self->_write_xml(TABLE	=> $table,LEVEL	=> $params{LEVEL},ROW_FOR_ID	=> $r);	
					}
				}
			}
			else   { #the column reference a simple type
				my $cur=$self->_prepared_query($table,ID => $value,TAG => __LINE__);
				my $tag=basename($col->get_attrs_value qw(PATH));
				while (my $r=$cur->fetchrow_arrayref) {
					$ostr->dataElement($tag,$r->[2]);                              
				}
				$self->_prepared_delete($table,ID => $value,TAG => __LINE__) if $p->{DELETE_ROWS};
			}
		}
		else {
			if (my $path=$col->get_attrs_value(qw(PATH))) {
				my $tag=basename($path);
				$ostr->dataElement($tag,$value);                              
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
	return bless \%params,$class;
}

sub read {
	my $self=shift;
	return $self->_read(@_);
}


sub write {
	my $self=shift;
	return $self->_write(@_);
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
			but then params DB_NAMESPACE, DB_CONN must be set
		DB_NAMESPACE => set the property (Es: pg for postgres or oracle for oracle) used only if SQL_BINDING is not set
		DB_CONN     => DBI connection used only if SQL_BINDING is not set
		SCHEMA_INSTANCE => schema instance (Ex: http://www.w3.org/2001/XMLSchema-instance) - default none
		SCHEMA_NAME     => schema name (Ex: schema.xsd) - default none
		SCHEMA   	=> schema object generated by blx::xsdsql::parser::parse



read - read a xml file and put into the database
	
	PARAMS:
		FD   =>  input file description (default stdin) 
	the method return the id inserted into the  root table


write - write a xml file from database

	PARAMS:
		FD - output file descriptor (default stdout)
		ROOT_ID    => root_id - the result of the method read
		DELETE_ROWS     => if true write to FD and delete the rows from the database
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

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIG 

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
