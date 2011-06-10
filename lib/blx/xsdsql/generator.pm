package blx::xsdsql::generator;
use strict;
use warnings;
use Carp;
use blx::xsdsql::ut qw(nvl ev);

use constant {
	STREAM_CLASS => 'blx::xsdsql::OStream'
};


sub _fusion_params {
	my ($self,%params)=@_;
	my %p=%$self;
	for my $p(keys %params) {
		$p{$p}=$params{$p};
	}
	return \%p;
}

sub _check_table_filter {
	my ($self,$table,$level,%params)=@_;
	if (defined $self->{_PARAMS}->{LEVEL_FILTER}) {
		return 0  if $level != $self->{_PARAMS}->{LEVEL_FILTER};
	}
	if (defined $self->{_PARAMS}->{TABLES_FILTER}) {
		return 1 if $self->{_PARAMS}->{TABLES_FILTER}->{uc($table->get_sql_name)};
		my $path=$table->get_attrs_value qw(PATH);
		return 0 unless defined $path;
		return 1 if $self->{_PARAMS}->{TABLES_FILTER}->{$path};
		return 0;
	}
	return 1;
}

sub _check_view_limits {
	my ($self,$table,%params)=@_;
	my $p=$self->{_PARAMS};
	return 1 unless grep($_ eq $p->{COMMAND},qw( create_view drop_view));	
	return 1 unless $p->{MAX_VIEW_COLUMNS} || $p->{MAX_VIEW_JOINS};
	my $handle=$p->{HANDLE_OBJECT};
	if ($p->{MAX_VIEW_COLUMNS}) {
		return 1 if $p->{MAX_VIEW_COLUMNS} == -1; #no limit
		my @a=$handle->get_view_columns($table,%params);
		return 0 if scalar(@a) > $p->{MAX_VIEW_COLUMNS};
	}
	if ($p->{MAX_JOIN_COLUMNS}) {
		return 1 if $p->{MAX_VIEW_JOINS} == -1; #no limit
		my @a=$handle->get_join_columns($table,%params); 
		return 0 if scalar(@a) > $p->{MAX_VIEW_JOINS};
	}
	return 1;
}

sub _cross {
	my ($self,$table,%params)=@_;
	my $handle=$self->{_PARAMS}->{HANDLE_OBJECT};
	if ($self->_check_table_filter($table,$params{LEVEL}) && $self->_check_view_limits($table)) {
		$handle->table_header($table,%params) || return undef;
		for my $col($table->get_columns) {
			$handle->column($col,%params,TABLE => $table) || return undef;
		}
		$handle->table_footer($table,%params) || return undef;
	}
	for my $t($table->get_child_tables) {
		$self->_cross($t,%params,LEVEL => $params{LEVEL} + 1) || last;
	}
	if ($table->is_root_table) {
		my $types=$params{SCHEMA}->get_types_name;
		for my $k(keys %$types) {
			my $t=$types->{$k};
			next if $t->is_simple_type;
			$self->_cross($t,%params,LEVEL => -1) || last;			
		}
	}
	return $self; 
}


sub generate {
	my ($self,%params)=@_;
	my $p=$self->_fusion_params(%params);
	$p->{OUTPUT_NAMESPACE}='sql' unless $p->{OUTPUT_NAMESPACE};
	croak "param DB_NAMESPACE not set" unless $p->{DB_NAMESPACE};
	croak "param SCHEMA not set" unless $p->{SCHEMA};
	croak "param COMMAND not set" unless $p->{COMMAND};
	my $handle_class='blx::xsdsql::generator::'.$p->{OUTPUT_NAMESPACE}.'::'.$p->{DB_NAMESPACE}.'::handle::'.$p->{COMMAND};
	if (defined $p->{TABLES_FILTER}) {
		$p->{TABLES_FILTER}=[ $p->{TABLES_FILTER} ] if ref($p->{TABLES_FILTER}) eq '';
		croak "TABLES_FILTER param type not valid  - must be an array of scalar or a scalar not null\n" 
			unless ref($p->{TABLES_FILTER}) eq 'ARRAY';
		for my $e(@{$p->{TABLES_FILTER}}) {
			croak "TABLES_FILTER param type not valid  - must be an array of scalar or a scalar not null\n" 
				unless defined $e && ref($e) eq '';
		}
		$p->{TABLES_FILTER}={ map { /^\// ? ($_,1)  : (uc($_),1) ; } @{$p->{TABLES_FILTER}} }; #transform into hash
	}
	

	if ($p->{MAX_VIEW_COLUMNS} || $p->{MAX_VIEW_JOINS}) {
		my $catalog_class="blx::xsdsql::xml::".$p->{DB_NAMESPACE}."::catalog";
		ev('use',$catalog_class);
		my $catalog=$catalog_class->new;
		
		if (my $x=$p->{MAX_VIEW_COLUMNS}) {
			croak "param MAX_VIEW_COLUMNS not valid - must be a number > 0 or -1\n"	
				unless ref($x) eq '' && $x=~/^[+\-]{0,1}\d+$/ && $x >= -1;
			$p->{MAX_VIEW_COLUMNS}=$catalog->get_max_columns_view
				if $x == -1;
		}

		if (my $x=$p->{MAX_VIEW_JOINS}) {
			croak "param MAX_VIEW_JOINS not valid - must be a number > 0 or -1\n"	
				unless ref($x) eq '' && $x=~/^[+\-]{0,1}\d+$/ && $x >= -1;
			$p->{MAX_VIEW_JOINS}=$catalog->get_max_joins_view
				if $x == -1;
		}
	}
	
	my $fd=nvl($p->{FD},*STDOUT);
	$p->{STREAMER}=ref($fd) eq STREAM_CLASS 
		? $fd
		: sub {
			  ev('use ',STREAM_CLASS);
			  return STREAM_CLASS->new(OUTPUT_STREAM => $fd)
		}->();

	ev('use',$handle_class);
	$p->{HANDLE_OBJECT}=$handle_class->new(%$p);
	$self->{_PARAMS}=$p;

	my $objs=$p->{HANDLE_OBJECT}->get_binding_objects($p->{SCHEMA},%$p);
	if (defined $objs->[0]) {
		$p->{HANDLE_OBJECT}->header($objs->[0],%params) unless $p->{NO_HEADER_COMMENT};
	}
	my @tablename_list=();  #generate tables

	for my $t(@$objs) {
		$self->_cross($t,%$p,LEVEL => 0);
	}
	return $self;
}

sub new {
	my ($class,%params)=@_;
	return bless \%params,$class;
}

sub get_namespaces {
	my @n=();
	for my $i(@INC) {
		my $dirgen=File::Spec->catdir($i,'blx','xsdsql','generator');
		next unless  -d "$dirgen";
		next if $dirgen=~/^\./;
		next unless opendir(my $fd,$dirgen);
		while(my $d=readdir($fd)) {
			my $dirout=File::Spec->catdir($dirgen,$d);
			next unless -d $dirout;
			next if $d=~/^\./;
			next unless opendir(my $fd1,$dirout);
			while(my $d1=readdir($fd1)) {
				my $dirout=File::Spec->catdir($dirgen,$d,$d1);
				next unless -d $dirout;
				next if $d1=~/^\./;
				push @n,$d.'::'.$d1;
			}
			closedir $fd1;
		}
		closedir($fd);
	}
	return wantarray ? @n : \@n;
}

1;

__END__

=head1 NAME

blx::xsdsql::generator  -  generate the files for create table ,drop table ,add primary key,drop sequence,create sequence,drop view,create view 


=head1 SYNOPSIS

use blx::xsdsql::generator


=head1 DESCRIPTION

this package is a class - instance it with the method new

=cut


=head1 FUNCTIONS


new - constructor

	PARAMS:
		SCHEMA 				=> schema object generated by blx::xsdsql::parser::parse
		OUTPUT_NAMESPACE 	=> default sql
		DB_NAMESPACE     	=> default <none>
		FD  				=> streamer class, file descriptor  , array or string  (default *STDOUT)
		COMMAND      		=> create_table|drop_table|addpk|drop_sequence|create_sequence|drop_dictionary|create_dictionary 
		LEVEL_FILTER  		=> <n> -  produce code only for tables at level <n> (n >= 0) - root has level 0  (default none)
		TABLES_FILTER  		=> [<name>] - produce code only for tables in  <name> - <name> is a table_name or a xml_path 
		MAX_VIEW_COLUMNS 	=>  produce view code only for views with columns number <= MAX_VIEW_COLUMNS - 
							-1 is a system limit (database depend)
							false is no limit (the default)
		MAX_VIEW_JOINS 		=>  produce view code only for views with join number <= MAX_VIEW_JOINS - 
							-1 is a system limit (database depend)
							false is no limit (the default)


generate - generate a file

	PARAMS:
		the same of the constructor

	the method return a self to object



get_namespaces  - static method  
	
	the method return an array of namespace founded 




=head1 EXPORT

None by default.


=head1 EXPORT_OK

None

=head1 SEE ALSO


See blx::xsdsql::parser  for parse a xsd file (schema file) and blx::xsdsql::xml for read/write a xml file into/from a database

=head1 AUTHOR

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
 

