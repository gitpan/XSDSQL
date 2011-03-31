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

sub _register_path {
	my %params=@_;
	my $tag=$params{TAG};
	my $path=defined $params{C}  
		? $params{C}->get_attrs_value(qw(PATH))
		: $params{T}->get_attrs_value(qw(PATH));
		
	if ($params{ORIG_PATH_NAME}) {
		$path=_resolve_relative_path($params{ORIG_PATH_NAME},$params{T},$path,%params);
	}
	else {
		confess "(E $tag) ORIG_PATH_NAME not def for type table " if $params{T}->is_type;
	}

	if (defined $path) {
		if (defined $params{PATH}->{$path}) {
			confess "(E $tag) $path: path altready register\n";
		}
		else {
			if (defined $params{C}) {
				my $h={ T => $params{T},C => $params{C}};
				if ($params{T}->is_unpath_sequence) {
					$h->{TABLE_REF_FROM}=$params{STACK}->[-1];
				}
				$params{PATH}->{$path}=$h; #map path into a column
				print STDERR "(D $tag) register column path '$path' with (".$params{T}->get_sql_name
					.(defined $params{C} ? ','.$params{C}->get_sql_name : '')
					.")\n"
						if $params{DEBUG};
			}
			else { #map path into a tables stack 
				$params{STACK}=[] unless defined $params{STACK};
				push @{$params{STACK}},{ T => $params{T} };
				$params{PATH}->{$path}=$params{STACK}; 
				print STDERR "(D $tag) register table path '$path' with ("
					.join(',',map { $_->{T}->get_sql_name.(defined $_->{C} ? '.'.$_->{C}->get_sql_name : '') } @{$params{PATH}->{$path}})
					.")\n"
					if $params{DEBUG};
			}
		}
	}
	else {
		confess "(E $tag) path not defined\n";
	}
	return $path;	
}

sub _resolve_path_ref {
	my ($table,$col,$path_ref,%params)=@_;
	print STDERR "(D ",$params{TAG},") col '",$col->get_full_name,"' ref path  '$path_ref'\n"
		if $params{DEBUG};
	return $path_ref if ref($path_ref) =~/::table/;
	my $tab_ref=$params{TYPE_PATHS}->{$path_ref};
	return $tab_ref if defined $tab_ref;
	for my $child($table->get_child_tables) {
		return $child if nvl($child->get_attrs_value('PATH'),'') eq $path_ref;
	}
	return undef;
}

sub _resolve_relative_path {
	my ($startpath,$table,$relative_path,%params)=@_;
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
	my ($table,%params)=@_;
	my $tag=$params{TAG};
	if ($table->get_path) {
		_register_path(%params,T => $table,C => undef,TAG => __LINE__);
		$params{STACK}=[];
	}
	for my $col($table->get_columns) {
		next if $col->is_pk;	
		if (my $path_ref=$col->get_path_reference) {
			if (ref($path_ref) =~/::table/) {  #the column ref a table (unpathed ?)
				if ($col->is_internal_reference) {
					$col->set_attrs_value(TABLE_REFERENCE => $path_ref);
					_register_path(%params,T => $table,C => $col,TAG => __LINE__)
				}
				else {
					$col->set_attrs_value(TABLE_REFERENCE => $path_ref);
					my $orig_path_name=$params{ORIG_PATH_NAME};
					if (my $path=$col->get_path) {
						$orig_path_name=_resolve_relative_path(
							nvl($params{ORIG_PATH_NAME},$table->get_path)
							,$table
							,$path
							,%params
							,TAG => __LINE__
						);
							
					}
					my @stack=({ T =>  $table,C => $col });
					@stack=(@{$params{STACK}},@stack) unless $table->get_path; 
					_mapping_path($path_ref,%params,STACK => \@stack,ORIG_PATH_NAME => $orig_path_name);
				}
			}
			else {
				confess "(E $tag) $path_ref: the column has internal reference and path_ref is not a table: ".$table->get_sql_name.'.'.$col->get_sql_name."\n"
					 if $col->is_internal_reference;
				my $t=_resolve_path_ref($table,$col,$path_ref,%params,TAG => __LINE__);
				croak "$path_ref: path not resolved from ".$table->get_sql_name.'.'.$col->get_sql_name."\n" 
					unless defined $t;
				$col->set_attrs_value(TABLE_REFERENCE => $t);
				my $orig_path_name=$params{ORIG_PATH_NAME};
				if (my $path=$col->get_path) {
					$orig_path_name=_resolve_relative_path(
						nvl($params{ORIG_PATH_NAME},$table->get_attrs_value qw(PATH))
						,$table
						,$path
						,%params
						,TAG => __LINE__
					); 
				}
				my @stack=({ T =>  $table,C => $col });
				@stack=(@{$params{STACK}},@stack) unless $table->get_path;				
				_mapping_path($t,%params,STACK => \@stack,ORIG_PATH_NAME => $orig_path_name);
			}
		}
		else {
			_register_path(%params,T => $table,C => $col,TAG => __LINE__)
		}
	}
	return undef;
}

sub mapping_paths {
	my ($self,$root_table,$type_paths,%params)=@_;
	my %path_translate=();
	my $p=$self->_fusion_params(%params);
	_mapping_path($root_table,%$p,PATH => \%path_translate,TYPE_PATHS => $type_paths,STACK => []);
	$self->set_attrs_value(TC => \%path_translate);
	return $self;
}

sub resolve_path { #return an array if resolve into tables otherwise an hash
	my ($self,$path,%params)=@_;
	croak "1^ arg not set" unless defined $path;
	my $a=$self->{TC}->{$path};
	croak "$path: path not resolved ".nvl($params{TAG}) unless defined $a;
	return $a;
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


	
