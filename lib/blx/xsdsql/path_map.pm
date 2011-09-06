package blx::xsdsql::path_map;

use strict;
use warnings FATAL => 'all';
use Carp;
use Data::Dumper;

use blx::xsdsql::ut qw(nvl);


our %_ATTRS_R=();
our %_ATTRS_W=();


sub _fusion_params {
	my ($self,%params)=@_;
	my %p=%$self;
	for my $p(keys %params) {
		$p{$p}=$params{$p};
	}
	return \%p;
}

sub _debug {
	return $_[0] unless $_[0]->{DEBUG};
	my ($self,$n,@l)=@_;
	$n='<undef>' unless defined $n; 
	print STDERR 'path_map (D ',$n,'): ',join(' ',grep(defined $_,@l)),"\n"; 
	return $self;
}


sub _register_attribute {
	my ($self,%params)=@_;
	my $tag=$params{TAG};
	$self->_debug($tag,'register column attribute ',$params{C}->get_name,' with (',$params{C}->get_full_name,')');
	$params{ATTRIBUTES}->{$params{T}->get_sql_name}->{$params{C}->get_name}=$params{C};
	return $self;
}

sub _link_tables {  # link column $t1.$c1 => $t2.id 
	my ($self,$t1,$c1,$t2,%params)=@_;
	$self->{LINK_TABLES}->{$t1->get_sql_name}->{$t2->get_sql_name}=$c1;
	return $self;
}

sub _register_path {
	my ($self,%params)=@_;
	my $tag=$params{TAG};
	my $path=defined $params{C}  
		? $params{C}->get_attrs_value(qw(PATH))
		: $params{T}->get_attrs_value(qw(PATH));
		
	if ($params{ORIG_PATH_NAME}) {
		$path=$self->_resolve_relative_path($params{ORIG_PATH_NAME},$params{T},$path,%params);
	}
	else {
		confess "(E $tag) ORIG_PATH_NAME not def for type table " if $params{T}->is_type;
	}
	unless ($path) {
		$self->_debug(__LINE__,Dumper($params{C}));
		confess "(E $tag) path not set\n";
	}

	my $ret=sub {
		if (defined $params{C}) { #map path into a column
			my $h={ T => $params{T},C => $params{C}};
			my @stack=@{$params{STACK}};
			$h->{STACK}=\@stack if $params{T}->is_unpath || $params{T}->is_group_type; 
			$self->_debug($tag,'register column path ',$path,' with (',$params{C}->get_full_name,')');
			return $h;
		}
		else { #map path into a tables stack 
			$params{STACK}=[] unless defined $params{STACK};
			push @{$params{STACK}},{ T => $params{T} };
			$self->_debug($tag,'register table path ',$path,' with ('.
				join(',',map { $_->{T}->get_sql_name.(defined $_->{C} ? '.'.$_->{C}->get_sql_name : '') } @{$params{STACK}})
				.')');
			return $params{STACK};
		}
		confess "dead code\n";
	}->();

	if (my $tc=$params{PATH}->{$path}) {  #path is already register
		if ($self->{DEBUG}) {  #check the consistenze $tc and $ret
			$self->_debug($tag,"$path: path already register");
			confess "check consistence 1 failed " if ref($tc) eq 'ARRAY' && ref($ret) ne 'ARRAY';
			confess "check consistence 2 failed " if ref($tc) eq 'HASH' && ref($ret) ne 'HASH';
			confess "check consistence 3 failed " if ref($tc) eq 'ARRAY' && $tc->[-1]->{T}->get_sql_name ne $ret->[-1]->{T}->get_sql_name;

			if (ref($tc) eq 'HASH' && $tc->{C}->get_full_name ne $ret->{C}->get_full_name) {
				$self->_debug(__LINE__,$tc->{C}->get_full_name,$ret->{C}->get_full_name);
				$self->_debug(__LINE__,$ret->{T}->get_sql_name,$ret->{T}->is_group_type);
				$self->_debug(__LINE__,$tc->{T}->get_sql_name,$tc->{T}->is_group_type);
				$self->_debug(__LINE__," consistence 4 failed");
			}

			confess "check consistence 4 failed " if ref($tc) eq 'HASH' && $tc->{C}->get_full_name ne $ret->{C}->get_full_name;
		}
	}
	else {
		my $p=$params{PATH};
		$p->{$path}=$ret;
		if (my $ns=$params{XML_NAMESPACES}) {
			for my $n(@$ns) {
				next if $n eq 'xs';
				my $newpath=join('/',map {  length($_) ? $n.':'.$_ : $_;    } split('/',$path));
				$p->{$newpath}=$ret;
			}
		}
	}

	return $path;	
}


sub _resolve_path_ref {
	my ($self,$table,$col,$path_ref,%params)=@_;
	$self->_debug($params{TAG},'col',"'".$col->get_full_name."'","ref path  '$path_ref'");
	my $tab_ref=$params{TYPE_PATHS}->{$path_ref};
	return $tab_ref if defined $tab_ref;
	for my $child($table->get_child_tables) {
		return $child if nvl($child->get_attrs_value('PATH'),'') eq $path_ref;
	}
	return undef;
}

sub _resolve_relative_path {
	my ($self,$startpath,$table,$relative_path,%params)=@_;
	my $tag=$params{TAG};
	confess "(E $tag) null relative path\n" unless $relative_path;
	my ($path,$x,$t)=($relative_path,-1,$table);
	while(!$t->get_attrs_value qw(PATH)) {
		$t=$params{STACK}->[$x--]->{T};
	}
	$path=$startpath.substr($path,length($t->get_attrs_value qw(PATH)));
	return $path;
}

sub _mapping_path {
	my ($self,$table,%params)=@_;
	my $tag=$params{TAG};
	if ($table->get_path && !$table->is_group_type) {
		$self->_register_path(%params,T => $table,C => undef,TAG => __LINE__);
		$params{STACK}=[];
	}

	for my $col($table->get_columns) {
		next if $col->is_pk;
		if ($col->is_attribute) {
			$self->_register_attribute(%params,T => $table,C => $col,TAG => __LINE__);
			next;
		}
		my ($path_ref,$table_ref)=$col->get_attrs_value qw(PATH_REFERENCE TABLE_REFERENCE);
		if (defined $path_ref || defined $table_ref) {
			if (defined $table_ref) {  #the column ref a table
				if ($col->is_internal_reference) {
					$self->_register_path(%params,T => $table,C => $col,TAG => __LINE__);
					if ($table_ref->is_simple_content_type)  {
						for my $col($table_ref->get_columns) {
							next unless $col->is_attribute;
							$self->_register_attribute(%params,T => $table_ref,C => $col,TAG => __LINE__);
						}
					}
				}
				else {
					$self->_link_tables($table,$col,$table_ref);
					my $orig_path_name=$params{ORIG_PATH_NAME};
					if (my $path=$col->get_path) {
						$orig_path_name=$self->_resolve_relative_path(
							nvl($params{ORIG_PATH_NAME},$table->get_path)
							,$table
							,$path
							,%params
							,TAG => __LINE__
						);
							
					}
					my @stack=({ T =>  $table,C => $col });
					@stack=(@{$params{STACK}},@stack) if ! $table->get_path || $table->is_group_type;				
					$self->_mapping_path($table_ref,%params,STACK => \@stack,ORIG_PATH_NAME => $orig_path_name);
				}
			}
			else {	# the column ref a path of an unknow table
				confess "(E $tag) $path_ref: the column has internal reference and table_ref is not a table: '".$col->get_full_name."'\n"
					 if $col->is_internal_reference;
				my $t=$self->_resolve_path_ref($table,$col,$path_ref,%params,TAG => __LINE__);
				croak "$path_ref: path not resolved from '".$col->get_full_name."'\n" unless defined $t;
				$self->_link_tables($table,$col,$t);
				$col->set_attrs_value(TABLE_REFERENCE => $t);
				my $orig_path_name=$params{ORIG_PATH_NAME};
				if (my $path=$col->get_path) {
					$orig_path_name=$self->_resolve_relative_path(
						nvl($params{ORIG_PATH_NAME},$table->get_attrs_value qw(PATH))
						,$table
						,$path
						,%params
						,TAG => __LINE__
					); 
				}
				my @stack=({ T =>  $table,C => $col });
				@stack=(@{$params{STACK}},@stack) if ! $table->get_path || $table->is_group_type;				
				$self->_mapping_path($t,%params,STACK => \@stack,ORIG_PATH_NAME => $orig_path_name);
			}
		}
		else {
			$self->_register_path(%params,T => $table,C => $col,TAG => __LINE__) if defined $col->get_path;
		}
	}
	return undef;
}

sub mapping_paths {
	my ($self,$root_table,$type_paths,%params)=@_;
	my %path_translate=();
	my %attr_translate=();
	my $p=$self->_fusion_params(%params);
	my %savekey=%$self;
	$self->{DEBUG}=$params{DEBUG} if exists $params{DEBUG};
	$self->_mapping_path($root_table,%$p,PATH => \%path_translate,TYPE_PATHS => $type_paths,STACK => [],ATTRIBUTES => \%attr_translate);
	$self->set_attrs_value(TC => \%path_translate,ATTRS => \%attr_translate); 
	$self->{DEBUG}=$savekey{DEBUG};
	return $self;
}

sub resolve_path { #return an array if resolve into tables otherwise an hash
	my ($self,$path,%params)=@_;
	croak "1^ arg not set" unless defined $path;
	my $a=$self->{TC}->{$path};
	croak "$path: path not resolved ".nvl($params{TAG}) unless defined $a;
	return $a;
}


sub resolve_attributes {
	my ($self,$table_name,@attrnames)=@_;
	my @cols=map { 	$self->{ATTRS}->{$table_name}->{$_} } @attrnames;
	return @cols if wantarray;
	return scalar(@cols) <= 1 ? $cols[0] : \@cols;
}

sub resolve_column_link {
	my ($self,$t1,$t2,%params)=@_;
	my ($n1,$n2)=($t1->get_sql_name,$t2->get_sql_name);
	my $col=$self->{LINK_TABLES}->{$n1}->{$n2};
	croak $n1.' => '.$n2.": link not resolved \n" unless defined $col;
	return $col;
}

sub new {
	my ($classname,%params)=@_;
	my $self=bless {},$classname;
	$self->set_attrs_value(%params);
	return $self;
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

1;

__END__

=head1  NAME

blx::xsdsql::path_map - mapping a xml path to table/column 

=cut

=head1 SYNOPSIS

use blx::xsdsql::path_map

=cut


=head1 DESCRIPTION

this package is a class - instance it with the method new


=head1 FUNCTIONS

this module defined the followed functions

new - constructor   

	params:
		DEBUG - emit debug info 
		

mapping_paths - mapping the all path node to tables and columns

	arguments
		$root_table - the output of the parser
		$type_paths - the output of the parser

	params:
		DEBUG - emit debug info 

	the method return the self object


resolve_path - return the table and the column associated  to the the pathnode
				the method return an array ref if the path is associated to a tables
				otherwise return an hash if the path is associated to a column

	arguments
		absolute node path 
		
	params:
		DEBUG - emit debug info 



resolve_column_link - return a column that link 2 tables

	the arguments are  a parent table and a child tables
	

resolve_attributes - return columns that bind node attributes
	
	the arguments are a table name and a attribute node name list


set_attrs_value   - set a value of attributes

	the arguments are a pairs NAME => VALUE	
	the method return a self object



get_attrs_value  - return a list  of attributes values

	the arguments are a list of attributes name


=head1 EXPORT


None by default.


=head1 EXPORT_OK

None

=head1 SEE ALSO

	blx::xsdsql::schema  - mapping an xsd into a objects grouped in a schema object

=head1 AUTHOR

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut


	
