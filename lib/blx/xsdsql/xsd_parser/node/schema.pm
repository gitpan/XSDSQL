package blx::xsdsql::xsd_parser::node::schema;

use strict;
use warnings;
use integer;
use Carp;
use Data::Dumper;
use File::Basename;

use blx::xsdsql::ut qw(nvl);
use blx::xsdsql::xsd_parser::path_map;
use base qw(blx::xsdsql::xsd_parser::node);

use constant {
	STD_NAMESPACE		=>  'http://www.w3.org/2001/XMLSchema'
};

my %_ATTRS_R=(
	ID_SQL_TYPE	=> sub  { 
		my $h=Storable::dclone($_[0]->{ID_SQL_TYPE});
		return blx::xsdsql::xsd_parser::type::simple->_new(SQL_T_ => $h);
	}
);

my %_ATTRS_W=(
	TYPES	=> sub {
		my ($self,$types)=@_;
		confess "not implemented\n";
		return 1;
	}

);

sub _get_attrs_w { return \%_ATTRS_W; }
sub _get_attrs_r { return \%_ATTRS_R; }

sub _set_std_namespace {
	my ($self,%params)=@_;
	for my $k(keys %$self) {
		if (nvl($self->{$k}) eq STD_NAMESPACE) {
			if ($k=~/^xmlns:(\w+)$/) {
				$self->{STD_NAMESPACE_ABBR}=$1;
				delete $self->{$k};
			}
			else {
				confess "$k: wrong abbr for standard namespace\n";
			}
		}
		elsif ($k=~/^xmlns:(\w+)$/) {
			$self->{USER_NAMESPACE_ABBR}->{$1}=delete $self->{$k};
		}
		elsif ($k eq 'xmlns') {
			$self->{DEFAULT_NAMESPACE}=delete $self->{$k};
		}
		elsif ($k eq 'targetNamespace')  {
			$self-> {URI}=delete $self->{$k};
		}
	}
	croak "not std namespace in schema" unless defined $self->{STD_NAMESPACE_ABBR};
	return $self;
}


sub set_table_names {
	my ($self,$table,%params)=@_;
	my %p=%$self;
	$table->_set_sql_name(%p); #force the resolve of sql name
	$table->_set_constraint_name('pk',%p); #force the resolve of pk constraint
	$table->_set_view_sql_name(%p);   #force the resolve of view sql name
	$table->_set_sequence_name(%p) if $table->is_root_table; #force the resolve of the corresponding sequence name
	$table->set_attrs_value(URI => $self->get_attrs_value qw(URI));  #set the URI attribute

	$table->_add_columns(
		$self->get_attrs_value qw(ANONYMOUS_COLUMN)->_factory_column(qw(VALUE))->set_attrs_value(NAME => 'sysattrs',SYS_ATTRIBUTES => 1)
	);

	return $self;
}

sub _set_root_table_before {
	my ($self,%params)=@_;

	my $root=$self->get_attrs_value qw(TABLE_CLASS)->new (
		PATH			=> '/'
		,CHOICE			=> 1
	);

	$self->set_attrs_value(TABLENAME_LIST => $params{TABLENAME_LIST},CONSTRAINT_LIST => $params{CONSTRAINT_LIST});
	$self->set_table_names($root,%params);
	$root->_add_columns($self->get_attrs_value qw(ANONYMOUS_COLUMN)->_factory_column(qw(ID)));
	$self->set_attrs_value(TABLE => $root);
	return $self;
}


sub _set_root_table_after {
	my ($self,%params)=@_;
	return $self;
	my $t=$self->get_root_table;
	$t->_add_columns(
		$self->get_attrs_value qw(ANONYMOUS_COLUMN)->_factory_column(qw(VALUE))->set_attrs_value(NAME => 'sysattrs',SYS_ATTRIBUTES => 1)
	);
	return $self;
}

sub _parse_group_ref {  # flat the columns of groups table  into $table
	my ($self,$table,$type_node_names,%params)=@_;
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
		next if ($c->is_pk || $c->is_sys_attributes) && ! $params{START_FLAG};  #bypass the column if is the primary keys or sysattrs col  and not a start table 
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
			$self->_debug(__LINE__,' change path of column ',$nc->get_full_name," from '$cpath' to '$path'"); 
			$nc->set_attrs_value(PATH	=> $path);
			$p=$path;
		}


		if (defined $p && !$nc->is_group_reference) {  #register new path
			if (defined (my $col=$params{PATH}->{$p})) {
				$self->_debug(__LINE__,$p,': path already register for column ',$nc->get_full_name,' - pred column is ',$col->get_full_name);
				unless ($params{START_FLAGS}) {		 # a column into a group has priority to a column with same path
					$col->set_attrs_value(DELETE => 1);	  # the pred column is marked for deletion
				}
				else {
					$self->_debug(__LINE__,$p,' the column ',$nc->get_full_name, ' is bypassed');
					next;
				}
			}
			$params{PATH}->{$p}=$nc;
		}


		if ($nc->is_group_reference && $nc->get_max_occurs <= 1) { #flat the columns of ref table into $table
			++$fl;
			my $ty=$nc->get_attrs_value qw(TYPE)->get_attrs_value qw(NAME);
			my $ref=$type_node_names->{$ty}->get_attrs_value qw(TABLE);
			confess "no such table ref for column ".$c->get_full_name."(type '$ty')\n" unless defined $ref;
			$self->_debug(__LINE__,$nc->get_full_name,": the columun ref table group '",$ref->get_sql_name,"' with maxoccurs <=1 - flating  the columns of table !!");
			${$params{MAX_XSD_SEQ}}=$max_xsd_seq;
			my @cols=$self->_parse_group_ref($ref,$type_node_names,%params,START_FLAG => 0,CHOICE => $nc->is_choice);
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
	$table->_reset_columns;
	$table->_add_columns(grep(!$_->get_attrs_value qw(DELETE),@newcols));
	return undef;
}

sub _adj_element_ref {
	my ($self,$c,%params)=@_;
	my $fl=0;
	for my $col($self->get_root_table->get_columns) {
		if ($c->get_name eq $col->get_name) {
			$c->set_attrs_value(
					TYPE				=> $col->get_attrs_value(qw(TYPE))
					,REF				=> 0
			);
			if (defined (my $path_ref=$col->get_path_reference)) {
				$c->set_attrs_value(
						PATH_REFERENCE		=> $path_ref
				);
			}
			$fl=1;
			last;
		}
	}
	confess "ref not found for path ".nvl($c->get_path)."\n" unless $fl;
	return $c;
}

sub _adj_attr_ref {
	my ($self,$c,%params)=@_;
	my $name=$c->get_attrs_value qw(NAME);
	my $ty=$self->_get_global_attr($name,%params);
	confess "$name: not found into global attrs\n" unless defined $ty;
	$c->set_attrs_value(REF => 0,TYPE => $ty);
}

sub _adj_ref {
	my ($self,$c,%params)=@_;
	return $c->get_attrs_value qw(ATTRIBUTE) ? $self->_adj_attr_ref($c,%params) : $self->_adj_element_ref($c,%params); 
}

sub _resolve_custom_types {
	my ($self,$tables,$types,%params)=@_;
	$self->_debug(__LINE__,'start resolve custom types');
	for my $t(@$tables) {
		my $child_tables=$t->get_child_tables;
		$self->_resolve_custom_types($child_tables,$types,%params);
		$self->_parse_group_ref($t,$types,%params,START_FLAG => 1) unless  $self->get_attrs_value qw(NO_FLAT_GROUPS);
		for my $c($t->get_columns) {
			next if $c->is_pk || $c->is_sys_attributes;
			$self->_adj_ref($c,%params) if $c->get_attrs_value qw(REF);
			if (defined  (my $ctype=$c->get_attrs_value qw(TYPE))) {
				if (defined (my $new_ctype=$ctype->resolve_type($types))) {
					$self->_debug(__LINE__,'col ',$c->get_full_name,' with type of type ',ref($new_ctype));
					$new_ctype->link_to_column($c,%params,TABLE => $t,SCHEMA => $self,DEBUG => $self->get_attrs_value qw(DEBUG));
				}
				else {
					$self->_debug(__LINE__," the resolution of type '",$ctype->get_attrs_value qw(FULLNAME),"' for column '",$c->get_full_name,"' is post posted"); 
				}
			}
			else {
				$self->_debug(__LINE__,'column ,',$c->get_full_name,' without type');
				confess $c->get_full_name.": column without type\n";
			}
		}
	}
	return $self;
}


sub _add_child_schema {
	my ($self,$child_schema,$ns)=@_;
	my %p=map {  ($_,$self->get_attrs_value($_));  }   qw(TABLE_DICTIONARY COLUMN_DICTIONARY RELATION_DICTIONARY);
	$child_schema->set_attrs_value(%p,CHILD_SCHEMA => 1);  
	push @{$self->{CHILDS_SCHEMA}},{  SCHEMA => $child_schema,NAMESPACE => $ns };
	return $self;
}

sub _new {
	my ($class,%params)=@_;
	my $self=$class->SUPER::_new(%params);
	$self->{CHILDS_SCHEMA}=[];
	$self->{PATH}='/';
	return $self;
}

sub trigger_at_start_node {
	my ($self,%params)=@_;
	$self->set_attrs_value(PATH => '/');

	for my $k(keys %$self) {
		next unless $k=~/PREFIX$/;
		$params{$k}=$self->{$k};
	}
	$self->_set_std_namespace(%params);
	$self->_set_root_table_before(%params);
	$self->{TYPES}=[];
	$self->{ATTRIBUTES}={};
	return $self;
}

sub trigger_at_end_node {
	my ($self,%params)=@_;

	$self->_set_root_table_after(%params);

	for my $k(keys %$self) {
		next unless $k=~/PREFIX$/;
		$params{$k}=$self->{$k};
	}

	my $types=$self->get_attrs_value qw(TYPES);
	my @type_tables=map { my $t=$_->get_attrs_value qw(TABLE); defined $t ? $t : (); }  @$types;
	my %type_node_names=map  {  ($_->get_attrs_value qw(name),$_); } @$types;

	$self->_resolve_custom_types(\@type_tables,\%type_node_names,%params);
	$self->_resolve_custom_types([$self->get_root_table],\%type_node_names,%params);

	my %type_table_paths=map {  my $path=$_->get_attrs_value qw(PATH); defined $path ? ($path,$_) : ();  } @type_tables;
	$self->{TYPE_NAMES}={ map {  my $name=$_->get_attrs_value qw(NAME); defined $name ? ($name,$_) : ();  } @type_tables  };     
	$self->{TYPE_PATHS}={ map {  my $path=$_->get_attrs_value qw(PATH); defined $path ? ($path,$_) : ();  } @type_tables };

	return $self;
}

sub _mapping_paths {
	my ($self,$type_paths,%params)=@_;
	confess ref($type_paths).": internal error - 1^ param must be a hash\n" unless ref($type_paths) eq 'HASH';
	my $pr=$self->_fusion_params(%params);
	my $m=blx::xsdsql::xsd_parser::path_map->new(%$pr);
	my $root=$self->get_root_table;
	$self->{MAPPING_PATH}=$m->mapping_paths($root,$type_paths,%$pr);
	return $self;
}


sub _factory_dictionary {
	my ($self,$dictionary_type,$name,%params)=@_;
	my $t=$self->get_attrs_value qw(TABLE_CLASS)->new(NAME => $name);
	$t->_set_sql_name(%params,TABLENAME_LIST => $self->get_attrs_value qw(TABLENAME_LIST));  #force the resolve of sql name
	$t->_set_constraint_name('pk',%params,CONSTRAINT_LIST => $self->get_attrs_value qw(CONSTRAINT_LIST)); #force the resolve of pk constraint
	$t->_add_columns($self->get_attrs_value qw(ANONYMOUS_COLUMN)->_factory_dictionary_columns($dictionary_type,%params));
	return $t;
}


sub _create_dictionary_objects {
	my ($self,%params)=@_;
	my %p=map { 
		my $k=$_.'_NAME';
		my $v=$self->{$k};
		confess "$k: internal error - key not set\n" unless defined $v;
		($_,$self->_factory_dictionary($_,$v,%params));
	} qw(SCHEMA_DICTIONARY TABLE_DICTIONARY COLUMN_DICTIONARY RELATION_DICTIONARY);
	$self->set_attrs_value(%p);
	return $self;
}



sub add_types {
	my $self=shift;
	push @{$self->{TYPES}},@_;
	return $self;
}

sub _add_attrs {
	my $self=shift;
	for my $col(@_) {
		my ($name,$type)=map { $col->get_attrs_value($_); } qw(NAME TYPE);
		$self->{ATTRIBUTES}->{$name}=$type;
	}
	return $self;
}

sub _get_global_attr {
	my ($self,$name,%params)=@_;
	return $self->{ATTRIBUTES}->{$name};
}

sub get_std_namespace_attr {
	my ($self,%params)=@_;
	return $self->{STD_NAMESPACE_ABBR};
}

sub get_root_table {
	my ($self,%params)=@_;
	return $self->{TABLE};
}

sub get_types_name {
	my ($self,%params)=@_;
	my $types=$self->{TYPE_NAMES};
	return undef unless defined $types;
	return wantarray ? %$types : $types;
}

sub get_types_path {
	my ($self,%params)=@_;
	my $types=$self->{TYPE_PATHS};
	return undef unless defined $types;
	return wantarray ? %$types : $types;
}	

=pod
sub get_dictionary_table {
	my ($self,$type,%params)=@_;
	croak "type (1^ param) not set" unless $type;
	return $self->get_attrs_value($type);
}

sub get_dictionary_data {
	my ($self,$dictionary_type,%params)=@_;
	croak "dictionary_type (1^ arg)  non defined" unless defined $dictionary_type;
	if ($dictionary_type eq 'SCHEMA_DICTIONARY') {
		my %data=map { ($_,$self->get_attrs_value($_)); } qw(URI element_form_default attribute_form_default); 
		return wantarray ? %data : \%data;
	}
	croak "$dictionary_type: invalid value";
}
=cut

=pod
sub get_sequence_name {
	my ($self,%params)=@_;
	my $t=$self->get_root_table;
	return undef unless $t;
	return $t->get_sequence_name(%params);
}
=cut


sub get_childs_schema {
	my ($self,%params)=@_;
	my $a=$self->{CHILDS_SCHEMA};
	return wantarray ? @$a : $a;
}

sub find_schema_by_namespace {
	my ($self,$namespace,%params)=@_;
	for my $h($self->get_childs_schema) {
		if (defined (my $ns=$h->{NAMESPACE})) {
			return $h->{SCHEMA} if $ns eq $namespace;
		}
	}
	return undef;
}



sub find_schema_by_namespace_abbr {
	my ($self,$ns,%params)=@_;
	if (defined (my $namespace=$self->{USER_NAMESPACE_ABBR}->{$ns})) {
		return $self if $self->{URI} eq $namespace;  #this is the same schema
		return $self->find_schema_by_namespace($namespace,%params);
	}
	$self->_debug(__LINE__,"$ns: not find URI from this namespace abbr");
	return undef;
}


1;

__END__




=head1  NAME

blx::xsdsql::xsd_parser::node::schema - internal class for parsing schema 

=cut



