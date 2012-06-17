package blx::xsdsql::xsd_parser;

use strict;
use warnings FATAL => 'all';
use integer;
use Carp;
use POSIX;

use File::Basename;
use Data::Dumper;
use XML::Parser;

use blx::xsdsql::xsd_parser::node;
use blx::xsdsql::ut qw(nvl ev);
use blx::xsdsql::xsd_parser::schema;

use base qw(blx::xsdsql::common_interfaces blx::xsdsql::log);

use constant {
			DEFAULT_SCHEMA_DICTIONARY_NAME		=>  'schema_dictionary'
			,DEFAULT_TABLE_DICTIONARY_NAME		=>  'table_dictionary'
			,DEFAULT_COLUMN_DICTIONARY_NAME		=>  'column_dictionary'
			,DEFAULT_RELATION_DICTIONARY_NAME	=>  'relation_dictionary'
};


our %_ATTRS_R=();
our %_ATTRS_W=();


sub _get_attrs_w { return \%_ATTRS_W; }
sub _get_attrs_r { return \%_ATTRS_R; }


sub _push {  
	my ($self,$v,%params)=@_;
	if ($self->{DEBUG}) {
	}
	push @{$self->{STACK}},$v;
	return $v;
}

sub _pop {
	my ($self,%params)=@_;
	confess "empty stack " if scalar(@{$self->{STACK}}) == 0;
	if ($self->{DEBUG}) {
	}
	pop @{$self->{STACK}};
	return scalar(@{$self->{STACK}}) == 0 ? undef : $self->{STACK}->[-1];
}

sub _get_stack {
	my ($self,%params)=@_;
	confess "empty stack " if scalar(@{$self->{STACK}}) == 0;
	my $s=$self->{STACK}->[-1];
	if ($self->{DEBUG} && !$params{NOT_DEBUG}) {
	}
	return $s;
}


sub _to_obj {
	my ($self,$tag,%params)=@_;
	return blx::xsdsql::xsd_parser::node::factory_object($tag,%params);
}

sub _decode {
	my $self=shift;
	return $_[0] if scalar(@_) <= 1;
	return @_;
}

my %H=(
		Start => sub { 
			my ($expect,$node,%attrs)=@_;
			my $self=$expect->{LOAD_INSTANCE};
			my @params=(%{$expect->{PARAMS}},ATTRIBUTES => \%attrs);
			push @params,map {  ($_,$self->{$_}) } grep(ref($self->{$_}) eq '',keys %$self);
			my $stack=$self->get_attrs_value(qw(STACK));
			my $obj=$self->_to_obj($node,@params,STACK => $stack);
			$self->_debug(__LINE__,'> (start path)',$obj->get_attrs_value(qw(PATH))," with type ",ref($obj));
			$obj->trigger_at_start_node(%{$expect->{PARAMS}},PARSER => $self);
			if (ref($obj) =~/::schema$/) {
				$stack->[1]=$obj;
			}
			else {
				$self->_push($obj);
			}
			undef;
		}
		,End => sub {
			my ($expect,$node,%attrs)=@_;
			my $self=$expect->{LOAD_INSTANCE};
			my $obj=$self->_get_stack;
			$self->_debug(__LINE__,'< (end path)',$obj->get_attrs_value(qw(PATH))," with type ",ref($obj));
			$obj->trigger_at_end_node;
			if (ref($obj) =~ /::schema$/) {
				$obj->set_attrs_value(
							XMLDECL  => $self->get_attrs_value(qw(STACK))->[0]
				);
				$self->{SCHEMA_OBJECT}=$obj;
			}
			else {
				if (ref($obj)=~/Type$/ && (defined (my $name=$obj->get_attrs_value(qw(name))))) {
					$self->_debug(__LINE__,"type '$name' add to know types"); 
					$self->get_attrs_value(qw(STACK))->[1]->add_types($obj);
				}

				$self->_pop;
			}
			undef;
		}
		,XMLDecl => sub { 
			my ($expect,@decl)=@_;
			my $self=$expect->{LOAD_INSTANCE};
			$self->_push(\@decl);
		}
# 		,Char => sub { x("Char",@_); }
# 		,Proc => sub { x_("Proc",@_); }
# 		,Comment => sub { x("Comment",@_); }
# 		,CdataStart => sub { x_("CdataStart",@_); }
# 		,CdataEnd => sub { x_("CdataEnd",@_); }
# 		,Default => sub { x("Default",@_); }
# 		,Unparsed => sub { x_("Unparsed",@_); }
# 		,Notation => sub { x_("Notation",@_); }
# 		,ExternEnt => sub { x_("ExternEnt",@_); }
# 		,ExternEntFin => sub { x_("ExternEntFin",@_); }
# 		,Entity => sub { x_("Entity",@_); }
# 		,Element => sub { x_("Element",@_); }
# 		,Attlist => sub { x_("Attlist",@_); }
# 		,Doctype => sub { x_("Doctype",@_); }
# 		,DoctypeFin => sub { x_("DoctypeFin",@_); }
);
	
sub _set_childs_schema {
	my ($self,%params)=@_;
	for my $c(@{$self->get_attrs_value(qw(CHILDS_SCHEMA))}) {
		my ($schema,$sl,$ns,$params)=@$c;
		my $parser=blx::xsdsql::xsd_parser->new(DB_NAMESPACE => $params->{DB_NAMESPACE});
		$self->_debug(__LINE__,"parsing location '$sl' with namespace '$ns'"); 
		my $child_schema=$parser->parsefile($sl,%params,%$params,CHILD_SCHEMA_ => 1);
		$self->_debug(__LINE__,"end parsing location '$sl'");
		$schema->_add_child_schema($child_schema,$ns);
	}
	return $self;
}

sub _resolve_postposted_types {
	my ($self,$tables,$types,%params)=@_;
	$self->_debug(__LINE__,'start resolve postposted types');
	for my $t(@$tables) {
		my $child_tables=$t->get_child_tables;
		$self->_resolve_postposted_types($child_tables,$types,%params);
		for my $c($t->get_columns) {
			next if $c->is_pk || $c->is_sys_attributes;
			if (defined  (my $ctype=$c->get_attrs_value(qw(TYPE)))) {
				next if defined $ctype->resolve_type($types);
				my $type_fullname=$ctype->get_attrs_value(qw(FULLNAME));
				$self->_debug(__LINE__,'column  ',$c->get_full_name,' with type ',$type_fullname);
				if (defined (my $new_ctype=$ctype->resolve_external_type($params{SCHEMA}))) {
					$new_ctype->link_to_column($c,%params,TABLE => $t,DEBUG => $self->get_attrs_value(qw(DEBUG)));
				}
				else {
					confess "$type_fullname: failed the external resolution\n";
				}
			}
			else {
				confess $c->get_full_name.": column without type\n";
			}
		}
	}
	return $self;
}

sub _parse {
	my ($self,%params)=@_;
	$params{PARSER}->setHandlers(%H);
	$self->{STACK}=[];
	$self->{CHILDS_SCHEMA}=[];
	$params{PARSER}->parse($params{FD},LOAD_INSTANCE => $self,PARAMS => \%params);
	delete $self->{STACK};
	return delete $self->{SCHEMA_OBJECT};
}

sub parsefile {
	my ($self,$file_name,%params)=@_;
	my $p=$self->_fusion_params(%params);
	for my $k(qw(ID_SQL_TYPE TABLE_CLASS COLUMN_CLASS)) {
		$p->{$k}=$self->{$k};
	}
	for my $k(qw(TABLE_PREFIX VIEW_PREFIX SEQUENCE_PREFIX)) {
		$p->{$k}='' unless defined $p->{$k};
	}

	$p->{SCHEMA_DICTIONARY_NAME}=DEFAULT_SCHEMA_DICTIONARY_NAME unless defined $p->{SCHEMA_DICTIONARY_NAME};
	$p->{TABLE_DICTIONARY_NAME}=DEFAULT_TABLE_DICTIONARY_NAME unless defined $p->{TABLE_DICTIONARY_NAME};
	$p->{COLUMN_DICTIONARY_NAME}=DEFAULT_COLUMN_DICTIONARY_NAME unless defined $p->{COLUMN_DICTIONARY_NAME};
	$p->{RELATION_DICTIONARY_NAME}=DEFAULT_RELATION_DICTIONARY_NAME unless defined $p->{RELATION_DICTIONARY_NAME};

	$p->{TABLENAME_LIST}={} unless ref($p->{TABLENAME_LIST}) eq 'HASH';
	$p->{CONSTRAINT_LIST}={} unless ref($p->{CONSTRAINT_LIST}) eq 'HASH';

	my $fd=*STDIN;
	if (defined $file_name && $file_name ne '-') { 
		open($fd,"<",$file_name) or croak "$file_name: open error $!\n";
	}

	$p->{PARSER}=XML::Parser->new;
	my $schema=$self->_parse(%$p,FD	=> $fd);
	close $fd if defined $file_name && $file_name ne '-';
	delete $p->{PARSER};
	$schema->_create_dictionary_objects(%$p) unless $params{CHILD_SCHEMA_};
	$self->_set_childs_schema(%$p);

	my $types=[values(%{$schema->get_types_name})];
	$self->_resolve_postposted_types($types,$types,SCHEMA => $schema);
	$self->_resolve_postposted_types([$schema->get_root_table],$types,SCHEMA => $schema);

	my $type_table_paths=$schema->get_types_path;
	$schema->_mapping_paths($type_table_paths,%params);

	return bless $schema,'blx::xsdsql::xsd_parser::schema';
}

sub new {
	my ($class,%params)=@_;
	my $namespace=$params{DB_NAMESPACE};
	croak "no param DB_NAMESPACE spec" unless defined $namespace;

	for my $cl(qw(catalog table column)) {
		my $class=uc($cl).'_CLASS';
		$params{$class}='blx::xsdsql::xml::'.$namespace.'::'.$cl;
		ev('use',$params{$class});
	}
	$params{ANONYMOUS_COLUMN}=$params{COLUMN_CLASS}->new;
	$params{ID_SQL_TYPE}=$params{ANONYMOUS_COLUMN}->_factory_column(qw(ID))->get_attrs_value(qw(TYPE));
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
 
	the first param must be an object compatible with the input of XML::Parser::parse, normally a file name    
	the method return a blx::xsdsql::xsd_parser::schema object
	
	PARAMS:
		TABLE_PREFIX 				=>  prefix for tables - the default is none
		VIEW_PREFIX  				=>  prefix for views  - the default is none
		SEQUENCE_PREFIX 			=>  prefix for the sequences - the default is none
		ROOT_TABLE_NAME				=>  the name of the root table - the default is 'ROOT'
		TABLE_DICTIONARY_NAME 		=>  the name of the table dictionary
		COLUMN_DICTIONARY_NAME 		=>  the name of the colunm dictionary
		RELATION_DICTIONARY_NAME 	=>  the name of the relation dictionary
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
