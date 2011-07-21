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


sub _debug {
	return $_[0] unless $_[0]->{DEBUG};
	my ($self,$n,@l)=@_;
	$n='<undef>' unless defined $n; 
	print STDERR 'xml (D ',$n,'): ',join(' ',grep(defined $_,@l)),"\n"; 
	return $self;
}

sub _debug_stack {
	return $_[0] unless $_[0]->{DEBUG};
	my ($self,$n,%params)=@_;
	my $stack=nvl($params{STACK},$self->{STACK});
	$params{INDEX}= [ (0..scalar(@$stack) - 1) ] unless defined $params{INDEX};
	$params{INDEX}=[ $params{INDEX} ] if ref($params{INDEX}) eq '';
	for my $i(@{$params{INDEX}}) {
		my @line=();
		my $h=$stack->[$i];
		for my $k(sort keys %$h) {
			my $v=$h->{$k};
			my $r=ref($v);
			if ($r =~/::sql_binding$/) {
				push @line,"$k: EXECUTE ".($v->is_execute_pending ? 'PENDING' : 'COMPLETED').' for table '.$v->get_binding_table->get_sql_name;
			}
			elsif ($r eq '')  {
				if (defined $v) {
					push @line,"$k => $v";
				}
				else {
					push @line,"$k => undef";
				}
			}
			else {
					push @line,"$k => $r";
			}
		}
		$self->_debug($n,@line);	
	}
	return $self;
}

sub _fusion_params {
	my ($self,%p)=@_;
	my %params=%$self;
	for my $p(keys %p) {
		$params{$p}=$p{$p};
	}

	$params{ROOT_TAG_PARAMS}=[] unless defined $params{ROOT_TAG_PARAMS};
	$params{ROOT_TAG_PARAMS}=[  map { ($_,$params{ROOT_TAG_PARAMS}->{$_}) }  keys %{$params{ROOT_TAG_PARAMS}} ]
		if ref($params{ROOT_TAG_PARAMS}) eq 'HASH';
	$params{ROOT_TAG_PARAMS}=[ split(",",$params{ROOT_TAG_PARAMS}) ]
		if ref($params{ROOT_TAG_PARAMS}) eq '';
	croak "ROOT_TAG_PARAMS param wrong type\n" unless ref($params{ROOT_TAG_PARAMS}) eq 'ARRAY';
	push @{$params{ROOT_TAG_PARAMS}},('xmlns:xsi',$params{SCHEMA_INSTANCE}) 
		if defined $params{SCHEMA_INSTANCE};
	push @{$params{ROOT_TAG_PARAMS}},('xsi:noNamespaceSchemaLocation',$params{SCHEMA_NAME}) 
		if defined $params{SCHEMA_NAME};

	return \%params;
}

sub _is_equal {
	my ($self,$t1,$t2,%params)=@_;
	confess "param 1 not set\n" unless defined $t1;
	confess "param 2 not set\n" unless defined $t2;
	my $r=$t1 == $t2 #same pointer
		|| $t1->get_sql_name eq $t2->get_sql_name ? 1 : 0;
	return $r unless $self->{DEBUG};
	$self->_debug($params{TAG},'not equal ',$t1->get_sql_name,' <==> ',$t2->get_sql_name)
		unless $r;
	return $r;
}

sub _get_prepared_insert {
	my ($self,$tag,%params)=@_;
	$tag=$tag->get_sql_name if ref($tag) =~/::table$/;
	confess Dumper($tag).": not a string or table\n" unless ref($tag) eq '';
	$self->{PREPARED}->{$tag}->{INSERT};
}

sub _prepared_insert {
	my ($self,$table,%params)=@_;
	confess "param 1 not set\n" unless defined $table;
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
	$insert->execute(TAG => __LINE__); # if $insert->is_execute_pending;
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
	my @out=();
	if ($r eq 'HASH') {
		for my $v(values %$p) {
			push @out,$self->_execute($v,%params);
		}
	}
	elsif ($r =~ /::sql_binding$/) {
		if ($params{CHECK_ONLY}) {
			return ($p);
		}
		else {
			if ($params{IGNORE_NOT_PENDING}) {
				$p->execute(%params) if $p->is_execute_pending;
			}
			else {
				$p->execute(%params);
			}
		}
	}
	return @out;
}

sub _push {  
	my ($self,$v,%params)=@_;
	if ($self->{DEBUG}) {
		$self->_debug($params{TAG},'PUSH STACK'
			,sub {
				my $p=$v->{PREPARED};
				return $p 
					? ("table ",$p->get_binding_table->get_sql_name)
					: ();
			}->());
	}
	$v->{PATH}=$self->{_CURRENT_PATH};
	push @{$self->{STACK}},$v;
	return $v;
}

sub _pop {
	my ($self,%params)=@_;
	confess "empty stack " if scalar(@{$self->{STACK}}) == 0;
	if ($self->{DEBUG}) {
		my $v=$self->{STACK}->[-1];
		$self->_debug($params{TAG},'POP STACK'
			,sub {
				my $p=$v->{PREPARED};
				return $p 
					? ("table ",$p->get_binding_table->get_sql_name)
					: ();
			}->());

		my @p=$self->_execute($v,%params,CHECK_ONLY => 1);
		my $e=0;
		for my $p(@p) {
			 if ($p->is_execute_pending) {
				$self->_debug($params{TAG},'EXECUTE PENDING - table ',$p->get_binding_table->get_sql_name,' has execute pending');
				++$e;
			 }
		}
		confess "execute pending\nkeys ".join(' ',keys(%$v))."\n" if $e;		
	}
	pop @{$self->{STACK}};
	return scalar(@{$self->{STACK}}) == 0 ? undef : $self->{STACK}->[-1];
}

sub _get_stack {
	my ($self,%params)=@_;
	confess "empty stack " if scalar(@{$self->{STACK}}) == 0;
	my $s=$self->{STACK}->[-1];
	if ($self->{DEBUG} && !$params{NOT_DEBUG}) {
		my @a=map {
			my $p=$s->{$_};
			my @out=();
			if (ref($p) =~/::sql_binding$/) {
				push @out,("$_ binding table ",$p->get_binding_table->get_sql_name);
			}
			else {
				push @out,("$_ generic key") if defined $p;
			}
			@out;
		} sort keys %$s;
		$self->_debug($params{TAG},'GET STACK',@a);		
	}
	return $s;
}


sub _resolve_path {
	my ($self,$path,%params)=@_;
	my $tc=$self->{_PARAMS}->{SCHEMA}->resolve_path($path);
	if ($self->{DEBUG}) {
		my $tag=$params{TAG};
		if (ref($tc) eq 'HASH') {
			$self->_debug($tag,$path,'mapping to column',$tc->{C}->get_full_name);
		}
		elsif (ref($tc) eq 'ARRAY') {
			$self->_debug(
				$tag
				,$path
				,"mapping to tables\n"
				,sub {
					my @out=();
					for my $i(0..scalar(@$tc) - 1) {
						my $t=$tc->[$i];
						push @out,
						  "\t\t\t"
							.$t->{T}->get_sql_name
							.(defined $t->{C} ? '.'.$t->{C}->get_sql_name : '')
							.($i == scalar(@$tc) - 1 ? '' : "\n");
					}
					return @out;
				}->()
				);
		}
		else {
			confess Dumper($tc).": not a hash or array";
		}
	}
	return $tc;
}

sub _resolve_link {
	my ($self,$t1,$t2,%params)=@_;
	my $tag=delete $params{TAG};
	my $column=$self->{_PARAMS}->{SCHEMA}->resolve_column_link($t1,$t2,%params);
	if ($self->{DEBUG}) {
		$self->_debug($tag,$column->get_full_name,' => '.$t2->get_sql_name);	
	}
	return $column;
}

sub _unpath_table {
	my ($self,$stack,$tc,%params)=@_;
	confess $tc->{T}->get_sql_name."table is not an unpath sequence table"
		unless $tc->{T}->is_unpath;
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
		my $trf=$tc->{STACK}->[-1];
		my $p=$trf->{T}->is_unpath
				? $stack->{UNPATH_PREPARED}->{$trf->{T}->get_sql_name}
				: $stack->{PREPARED};

		$p->bind_column($trf->{C},$id,TAG => __LINE__);				
		$stack->{UNPATH_PREPARED}->{$prepared_tag}=$sth;
	}
	$stack->{UNPATH_COLSEQ}->{$prepared_tag}=$tc->{C}->get_column_sequence;
	return $stack->{UNPATH_PREPARED}->{$prepared_tag};
}


sub _search_into_stack {
	my ($self,$f,%params)=@_;
	my $stack=delete $params{STACK};
	$stack=$self->{STACK} unless defined $stack;
	my $p=undef;
	if (ref($f) =~/::table$/)  {
		for my $i(0..scalar(@$stack) - 1) {
			my $st=$stack->[$i];
			if ($self->_is_equal($st->{PREPARED}->get_binding_table,$f,%params)) { 
				$p=$i;
				last;
			}
		}
	}
	elsif (ref($f) eq 'CODE') {
		for my $i(0..scalar(@$stack) - 1) {
			my $st=$stack->[$i];
			if ($f->($st)) { 
				$p=$i;
				last;
			}
		}
	}
	else {
		confess ref($f).": unknow type\n"; 
	}
	return $p;
}


sub _start_group_type {
	my ($self,$tc,%params)=@_;
	confess $tc->{T}->get_sql_name.": is not a group type table\n"
		unless $tc->{T}->is_group_type;
	$self->_debug(__LINE__,"start group type for column",$tc->{C}->get_full_name);
	my $stack=$self->_get_stack(TAG => __LINE__); 
	if ($self->_is_equal($tc->{T},$stack->{PREPARED}->get_binding_table,TAG => __LINE__)) {  #	
		if (defined $stack->{GROUP_TYPE_COLSEQ}) {
			if ($stack->{GROUP_TYPE_COLSEQ} >= $tc->{C}->get_column_sequence) {
				my $sth=$stack->{PREPARED};
				delete $stack->{EXTERNAL_REFERENCE}; 
				$sth->execute(TAG => __LINE__);
				_insert_seq_inc($sth,TAG => __LINE__); #increment the value of the seq column
			}		
		}
	}
	else {
		confess "bad group stack\n" if  scalar(@{$tc->{STACK}}) > 0 && $tc->{STACK}->[0]->{T}->is_group_type; 
		if ($tc->{STACK} && scalar(@{$tc->{STACK}}) > 1) {
			my ($pt_name)=($stack->{PREPARED}->get_binding_table(TAG => __LINE__)->get_sql_name);
			my $p=undef;
			for my $i(0..scalar(@{$tc->{STACK}}) - 1) {
				my $st=$tc->{STACK}->[$i];
				if ($st->{T}->get_sql_name eq $pt_name) {
					$p=$i;
					last;
				}
			}
			confess "$pt_name: not found into stack" unless defined $p;
			if ($self->{DEBUG}) {
				for my $i($p..scalar(@{$tc->{STACK}}) - 1) {
					my $st=$tc->{STACK}->[$i];
					$self->_debug(__LINE__,"group_stack index $i for $pt_name",$st->{C}->get_full_name);
				}
			}
			$tc->{STACK}->[$p]->{STH}=$stack->{PREPARED};

			for my $i($p+1..scalar(@{$tc->{STACK}}) - 1) {
				my $st=$tc->{STACK}->[$i];
				$st->{STH}=$self->_prepared_insert($st->{T},TAG => __LINE__);
				my ($id)=$st->{STH}->get_binding_values(PK_ONLY => 1,TAG => __LINE__);
				my $parent=$tc->{STACK}->[$i - 1];
				$parent->{STH}->bind_column($parent->{C},$id,TAG => __LINE__);#
			}

			my $sth=$self->_prepared_insert($tc->{T},TAG => __LINE__);
			my ($id)=$sth->get_binding_values(PK_ONLY => 1,TAG => __LINE__);
			my $parent=$tc->{STACK}->[-1];
			$parent->{STH}->bind_column($parent->{C},$id,TAG => __LINE__);
			$stack=$self->_push({  PREPARED => $sth,VALUE => '' },TAG => __LINE__);
			$stack->{STACK}=$tc->{STACK};
			$stack->{STACK_INDEX}=$p + 1;
		}
		else {
			my $trf=$tc->{STACK}->[-1];
			my ($parent_table,$parent_column)=($trf->{T},$trf->{C});
			my $sth=$self->_prepared_insert($tc->{T},TAG => __LINE__);
			my ($id)=$sth->get_binding_values(PK_ONLY => 1,TAG => __LINE__);
			if ($self->_is_equal($parent_table,$stack->{PREPARED}->get_binding_table,TAG => __LINE__)) { 
				$stack->{PREPARED}->bind_column($parent_column,$id,TAG => __LINE__);
				$stack=$self->_push({  PREPARED => $sth,VALUE => '' },TAG => __LINE__);
			}
			else {				
				my $p=$self->_search_into_stack($parent_table,TAG => __LINE__);
				for my $i($p..scalar(@{$self->{STACK}}) - 1) {
					my $st=$self->{STACK}->[$i]->{PREPARED};
					my ($id)=$st->get_binding_values(PK_ONLY => 1,TAG => __LINE__);
					my $st_parent=$self->{STACK}->[$i - 1]->{PREPARED};
					my $parent_column=$self->_resolve_link($st_parent->get_binding_table,$st->get_binding_table,TAG => __LINE__);
					$st_parent->bind_column($parent_column,$id,TAG => __LINE__);#
				}
			}
		}
	}
	
	$stack->{GROUP_TYPE_COLSEQ}=$tc->{C}->get_column_sequence;	
	return $stack;
}


my %H=(
	Start	=>   sub {
		my $self=$_[0]->{LOAD_INSTANCE};		
		$self->{_CURRENT_PATH}=$self->_decode('/'.join('/',(@{$_[0]->{Context}},($_[1]))));
		$self->_debug(__LINE__,'> (start path)',$self->{_CURRENT_PATH},"\n");
		
		my $stack=$self->_get_stack(TAG => __LINE__);
		my $tc=_resolve_path($self,$self->{_CURRENT_PATH},TAG => __LINE__);
		
		if (ref($tc) eq 'ARRAY') {  #is a path for a table
			if (scalar(@$tc) == 2) {
				my ($table,$parent_table,$parent_column)=($tc->[-1]->{T},$tc->[0]->{T},$tc->[0]->{C});
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
					$stack=$self->_push({  PREPARED => $self->_get_prepared_insert($table)},TAG => __LINE__);
				}
				else {
					$self->_prepared_insert($table,TAG => __LINE__);
					my $p=$self->_get_prepared_insert($table);
					my ($id)=$p->get_binding_values(PK_ONLY => 1,TAG => __LINE__);
					$stack->{PREPARED}->bind_column($parent_column,$id,TAG => __LINE__);
					$stack=$self->_push({  PREPARED => $p },TAG => __LINE__);
				}
			}
			elsif (scalar(@$tc) == 3) {
				my ($gran_parent_table,$gran_parent_column)=($tc->[-3]->{T},$tc->[-3]->{C});
				my ($parent_table,$parent_column)=($tc->[-2]->{T},$tc->[-2]->{C});
				my ($curr_table,$curr_column)=($tc->[-1]->{T},$tc->[-1]->{C});
				my $parent_tag=$parent_table->get_sql_name;
				
				if ($parent_table->is_unpath) {
					if (my $p=$stack->{UNPATH_PREPARED}->{$parent_tag}) {
						#confess "not implemented\n";
						if 	($stack->{UNPATH_COLSEQ}->{$parent_tag} >= $parent_column->get_xsd_seq) {
							$p->execute(TAG => __LINE__);
							_insert_seq_inc($p,TAG => __LINE__);
						}
					}
					else {
						my $sth=$self->_prepared_insert($parent_table,TAG => __LINE__);
						my ($id)=$sth->get_binding_values(PK_ONLY => 1,TAG => __LINE__);				
						$stack->{PREPARED}->bind_column($gran_parent_column,$id,TAG => __LINE__);
						$stack->{UNPATH_PREPARED}->{$parent_tag}=$sth;
					}
					$stack->{UNPATH_COLSEQ}->{$parent_tag}=$parent_column->get_xsd_seq;
				} 
				else {
					$self->_debug(__LINE__,$curr_table->get_sql_name,': table is not an unpath ');
				}

				if ($self->_is_equal($stack->{PREPARED}->get_binding_table,$curr_table,TAG => __LINE__)) {
					if ($stack->{COLSEQ} >= $curr_column->get_column_sequence) {
						$stack->{PREPARED}->execute(TAG => __LINE__);
						_insert_seq_inc($stack->{PREPARED},TAG => __LINE__);
					}
					else {
							confess "not implemented\n";
					}
				}
				else {
					my $prepared_tag=$parent_column->get_sql_name;
					if ($parent_column->get_max_occurs > 1 && $stack->{EXTERNAL_REFERENCE}->{$prepared_tag}) {
						_insert_seq_inc($stack->{EXTERNAL_REFERENCE}->{$prepared_tag},TAG => __LINE__); #increment the value of the seq column
						my $curr_tag=$curr_table->get_sql_name;
						$stack=$self->_push({  PREPARED => $self->{PREPARED}->{$curr_tag}->{INSERT}},TAG => __LINE__);
					}
					else {
						my $sth=$self->_prepared_insert($curr_table,TAG => __LINE__);
						my ($id)=$sth->get_binding_values(PK_ONLY => 1,TAG => __LINE__);
						if ($stack->{UNPATH_PREPARED}) {
							$stack->{UNPATH_PREPARED}->{$parent_tag}->bind_column($parent_column,$id,TAG => __LINE__);
#							$stack->{EXTERNAL_REFERENCE}->{$prepared_tag}=$stack->{UNPATH_PREPARED}->{$parent_tag} if $parent_column->get_max_occurs > 1;
						}
						else {
							$stack->{PREPARED}->bind_column($parent_column,$id,TAG => __LINE__);
							$stack->{EXTERNAL_REFERENCE}->{$prepared_tag}=$sth if $parent_column->get_max_occurs > 1;
						}
						$stack=$self->_push({  PREPARED => $sth },TAG => __LINE__);
					}
				}
			}
			else {
				confess $self->{_CURRENT_PATH}.": tc return < 2 or > 3 elements \n";				
			}
		}
		elsif ($tc->{C}->is_internal_reference) { #the column is an occurs of simple types
			$self->_debug(__LINE__,$tc->{C}->get_full_name,' has internal reference');
			my $prepared_tag=$tc->{C}->get_sql_name;
			if ($stack->{INTERNAL_REFERENCE}->{$prepared_tag}) {
				_insert_seq_inc($stack->{INTERNAL_REFERENCE}->{$prepared_tag},TAG => __LINE__); #increment the value of the seq column
			}
			else {
				my $p=$self->_prepared_insert($tc->{C}->get_table_reference,TAG => __LINE__);
				my ($id)=$p->get_binding_values(PK_ONLY => 1,TAG => __LINE__);
				unless($self->_is_equal($stack->{PREPARED}->get_binding_table,$tc->{T},TAG => __LINE__)) {
					if ($tc->{T}->is_unpath) {
						my $sth=$self->_unpath_table($stack,$tc);
						$sth->bind_column($tc->{C},$id,TAG => __LINE__);
					}
					elsif ($tc->{T}->is_group_type) {
						$stack=$self->_start_group_type($tc);
						$stack->{PREPARED}->bind_column($tc->{C},$id,TAG => __LINE__);
					}
					else {
						$self->_debug_stack(__LINE__,INDEX => -1);
						$stack->{PREPARED}->execute(TAG => __LINE__);
						while(1) {
							$stack=$self->_pop(TAG => __LINE__);
							last if $self->_is_equal($stack->{PREPARED}->get_binding_table,$tc->{T},TAG => __LINE__);
							$stack->{PREPARED}->execute(TAG => __LINE__);
						}
						$stack->{PREPARED}->bind_column($tc->{C},$id,TAG => __LINE__); #if is set fail on test 004 						
					}
				} 
				else {
					$stack->{PREPARED}->bind_column($tc->{C},$id,TAG => __LINE__);
				}
				$stack->{INTERNAL_REFERENCE}->{$prepared_tag}=$p;
			}
			$stack->{VALUE}='';
		}
		elsif (my $table_ref=$tc->{C}->get_table_reference) {
			confess $self->{_CURRENT_PATH}.": ref to '".$tc->{C}->get_path_reference."' not implemented\n";
		} 
		else {  #normal data column
			$self->_debug(__LINE__,' starting column',$tc->{C}->get_full_name);
			$stack->{VALUE}='';
			if ($tc->{T}->is_unpath) {
				my $sth=$self->_unpath_table($stack,$tc);
			}
			elsif ($tc->{T}->is_group_type) {
				$stack=$self->_start_group_type($tc);
			}
			else {
					#empty
			}
		}
	}  # Start
	,End	=>  sub {
		my $self=$_[0]->{LOAD_INSTANCE};		
#		return undef if scalar(@{$self->{STACK}}) == 0;
		$self->{_CURRENT_PATH}=$self->_decode('/'.join('/',(@{$_[0]->{Context}},($_[1]))));
		$self->_debug(__LINE__,'< (end path)',$self->{_CURRENT_PATH},"\n");
		my $stack=$self->_get_stack(TAG => __LINE__);
		my $tc=_resolve_path($self,$self->{_CURRENT_PATH},TAG => __LINE__);
		if (ref($tc) eq 'ARRAY') { #path ref a table
			my ($parent_table,$parent_column)=($tc->[-2]->{T},$tc->[-2]->{C});
			delete $stack->{INTERNAL_REFERENCE};    #for execute in error
			delete $stack->{EXTERNAL_REFERENCE};    #for execute in error
			$self->_execute($stack,TAG => __LINE__,IGNORE_NOT_PENDING => 1);
			if	($stack->{PREPARED}->get_binding_table->is_group_type) {
				while(1) {
					$stack=$self->_pop(TAG => __LINE__);
					last if $self->_is_equal($stack->{PREPARED}->get_binding_table,$tc->[0]->{T},TAG => __LINE__);
					$stack->{PREPARED}->execute(TAG => __LINE__);
				}
			}
			else {
				$stack=$self->_pop(TAG => __LINE__); 
			}
		}
		elsif ($tc->{C}->is_internal_reference) { #the column is an occours of simple types
			my $prepared_tag=$tc->{C}->get_sql_name;
			my $sth=$stack->{INTERNAL_REFERENCE}->{$prepared_tag};
			my $value_column=(($sth->get_binding_columns)[2])->{COL};
			$sth->bind_column($value_column,$stack->{VALUE},TAG => __LINE__);
			$sth->execute(TAG => __LINE__);
			delete $stack->{VALUE};
		}
		elsif (my $table_ref=$tc->{C}->get_table_reference) {
			confess $self->{_CURRENT_PATH}.": ref to ".$tc->{C}->get_path_reference." not implemented";
		} 
		else { #normal data column
			$self->_debug(__LINE__,'ending column',$tc->{C}->get_full_name);
			
			if ($tc->{T}->is_unpath) {
				my $prepared_tag=$tc->{T}->get_sql_name;
				$stack->{UNPATH_PREPARED}->{$prepared_tag}->bind_column($tc->{C},$stack->{VALUE},TAG => __LINE__);
			}
			else {
				if ($stack->{STACK}) {					
					my $p=$stack->{STACK_INDEX};
					for my $i($p..scalar(@{$stack->{STACK}}) - 1) {
						my $e=$stack->{STACK}->[$i];
						if ($e->{STH}->is_execute_pending) {
							$e->{STH}->execute(TAG => __LINE__);
						}
						else {
							$self->_debug(__LINE__,$e->{STH}->get_binding_table->get_sql_name,': execute non pending');
						}
					}
				}
				my $value=$stack->{VALUE};
				while (!$self->_is_equal($tc->{T},$stack->{PREPARED}->get_binding_table,TAG => __LINE__)) {  #	
					$stack->{PREPARED}->execute(TAG => __LINE__);
					$stack=$self->_pop(TAG => __LINE__); 
				}
				$stack->{PREPARED}->bind_column($tc->{C},$value,TAG => __LINE__);				
			}
		}
	}  #End
	,Char		=> sub {
		my $self=$_[0]->{LOAD_INSTANCE};		
		return undef if scalar(@{$self->{STACK}}) < 1;
		my ($path,$value)=($self->_decode('/'.join('/',@{$_[0]->{Context}})),$self->_decode($_[1]));
		my $stack=$self->_get_stack(TAG => __LINE__,NOT_DEBUG => 1);
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


sub _tag_with_ns {
	my $ns=shift;
	$ns=$ns->[0] if ref($ns) eq 'ARRAY';
	$ns='' unless defined $ns;
	$ns=$ns.':' if length($ns) && $ns!~/:$/;
	return $ns;
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
				my @root_tag_params=@{$p->{ROOT_TAG_PARAMS}};
				croak join(",",@root_tag_params).": param ROOT_TAG_PARAMS is not an array of pairs key,value\n" 
					if scalar(@root_tag_params) % 2;
				my %root_tag_params=@root_tag_params;
				my @namespace_prefix=map {  my @out=(/^xmlns:(\w+)/ && $1 ne 'xsi' ? ($1) : ()); @out; } keys(%root_tag_params); 				
				croak join(",",@namespace_prefix).": multiple xml namespaces are not suppported\n" if scalar(@namespace_prefix) > 1;
				$tag=_tag_with_ns(\@namespace_prefix).$tag;
				$ostr->startTag($tag,@root_tag_params);
				$self->_write_xml(ID => $row->[$i],TABLE	=> $table,LEVEL	=> 1,NAMESPACE_PREFIX => \@namespace_prefix);
				$ostr->endTag($tag);

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
	confess nvl($params{ID}).": no such id\n" unless defined $r;
	$self->_prepared_delete($table,ID => $r->[0],TAG => __LINE__) if $p->{DELETE_ROWS};
	my $ns=_tag_with_ns($params{NAMESPACE_PREFIX});

	for my $i(1..scalar(@$r) - 1) {
		my $col=($table->get_columns)[$i];
		next unless defined  $col->get_xsd_seq;
		my $value=$r->[$i];
		if (my $table=$col->get_table_reference) {
			next unless defined $value;
			if (!$col->is_internal_reference) {
				if (defined $table->get_attrs_value qw(PATH)) {
					if (!$table->is_type) { 
						my $tag=$ns.basename($table->get_attrs_value qw(PATH));
						$ostr->startTag($tag);
						$self->_write_xml(ID => $value,TABLE	=> $table,LEVEL	=> $params{LEVEL} + 1,NAMESPACE_PREFIX => $ns);
						$ostr->endTag($tag);
					}
					else {  #the column reference a complex type
						my $cur=$self->_prepared_query($table,ID => $value,TAG => __LINE__);
						my $tag=$ns.basename($col->get_attrs_value qw(PATH));
						$self->_prepared_delete($table,ID => $value,TAG => __LINE__) if $p->{DELETE_ROWS};
 						while(my $r=$cur->fetchrow_arrayref()) {
							if ($col->is_group_reference) {
								$self->_write_xml(TABLE	=> $table,LEVEL	=> $params{LEVEL},ROW_FOR_ID	=> $r,NAMESPACE_PREFIX => $ns);										
							}
							else {
								$ostr->startTag($tag);
								$self->_write_xml(TABLE	=> $table,LEVEL	=> $params{LEVEL} + 1,ROW_FOR_ID	=> $r,NAMESPACE_PREFIX => $ns);	
								$ostr->endTag($tag);
							}
						}
					}
				}
				else {	# is a sequence table
					my $cur=$self->_prepared_query($table,ID => $value,TAG => __LINE__);
					$self->_prepared_delete($table,ID => $value,TAG => __LINE__) if $p->{DELETE_ROWS};
					while(my $r=$cur->fetchrow_arrayref) {
						$self->_write_xml(TABLE	=> $table,LEVEL	=> $params{LEVEL},ROW_FOR_ID	=> $r,NAMESPACE_PREFIX => $ns);	
					}
				}
			}
			else   { #the column reference a simple type
				my $cur=$self->_prepared_query($table,ID => $value,TAG => __LINE__);
				my $tag=$ns.basename($col->get_attrs_value qw(PATH));
				while (my $r=$cur->fetchrow_arrayref) {
					$ostr->dataElement($tag,$r->[2]);                              
				}
				$self->_prepared_delete($table,ID => $value,TAG => __LINE__) if $p->{DELETE_ROWS};
			}
		}
		else {
			if (my $path=$col->get_attrs_value(qw(PATH))) {
				if (defined $value || $col->get_min_occurs > 0) {
					my $tag=$ns.basename($path);
					$value='' unless defined $value;
					$ostr->dataElement($tag,$value);                              
				}
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
		croak "DB_NAMESPACE param not def\n" unless defined $params{DB_NAMESPACE};
		croak "DB_CONN param not def\n" unless defined $params{DB_CONN};
		my $sql_binding='blx::xsdsql::xml::'.$params{DB_NAMESPACE}.'::sql_binding';
		ev('use',$sql_binding);
		$params{SQL_BINDING}=$sql_binding->new(%params);
	}
	$params{SQL_BINDING}->{DEBUG_NAME}='xml';

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
		XMLWRITER  				=> instance of class XML::Writer
										if is not set the object instance automatically
		XMLPARSER  				=> instance of class XML::Parser
										if is not set the object instance automatically
		SQL_BINDING 			=> instance of class blx::xsdsql::xml::sql_binding or a subclass
										if is not set the object instance automatically 
										but then params DB_NAMESPACE, DB_CONN must be set
		DB_NAMESPACE 			=> set the property (Es: pg for postgres or oracle for oracle) used only if SQL_BINDING is not set
		DB_CONN     			=> DBI connection used only if SQL_BINDING is not set
		SCHEMA_INSTANCE 		=> schema instance (Ex: http://www.w3.org/2001/XMLSchema-instance) - default none
									this is a deprecated param - use ROOT_TAG_PARAMS param
		SCHEMA_NAME     		=> schema name (Ex: schema.xsd) - default none
									this is a deprecated param - use ROOT_TAG_PARAMS param
		SCHEMA   				=> schema object generated by blx::xsdsql::parser::parse
		EXECUTE_OBJECTS_PREFIX 	=> prefix for objects in execution
		EXECUTE_OBJECTS_SUFFIX 	=> suffix for objects in execution
		ROOT_TAG_PARAMS   		=> force a hash or array of key/value for root tag in write xml 
		 

read - read a xml file and put into the database
	
	PARAMS:
		FD   =>  input file description (default stdin) 
	the method return the id inserted into the  root table


write - write a xml file from database

	PARAMS:
		FD 						=>  output file descriptor (default stdout)
		ROOT_ID    				=> root_id - the result of the method read
		DELETE_ROWS     		=> if true write to FD and delete the rows from the database
		ROOT_TAG_PARAMS   		=> force a hash or array of key/value for root tag in write xml 

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
