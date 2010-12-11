package blx::xsdsql::xml::generic::sql_binding;

use strict;
use warnings;
use integer;
use Carp;
use blx::xsdsql::ut qw(nvl);
use Data::Dumper;

use base qw(Exporter); 


my  %t=( overload => [ qw (
	BINDING_TYPE_INSERT
	BINDING_TYPE_DELETE
	BINDING_TYPE_UPDATE
	BINDING_TYPE_QUERY_ROW
) ]);

our %EXPORT_TAGS=( all => [ map { @{$t{$_}} } keys %t ],%t); 
our @EXPORT_OK=( @{$EXPORT_TAGS{all}} );
our @EXPORT=qw( );

use constant {
		BINDING_TYPE_INSERT   =>  'i'
		,BINDING_TYPE_DELETE   =>  'd'
		,BINDING_TYPE_UPDATE  =>  'u'
		,BINDING_TYPE_QUERY_ROW   =>  'qr'
};


sub new {
	my ($class,%params)=@_;
	my %p=map {  ($_,$params{$_}) }  qw (DB_CONN SEQUENCE_NAME DEBUG); 
	croak "no DB_CONN " unless defined $p{DB_CONN};
	return bless \%p,$class;
}

sub get_connection {  return $_[0]->{DB_CONN}; }

sub get_sth { return $_[0]->{STH}; }

sub get_clone {
	my ($self,%params)=@_;
	croak "DB_CONN not def" unless defined $self->{DB_CONN};
	my $db_conn=delete $self->{DB_CONN};
	my $clone=Storable::dclone($self);
	$self->{DB_CONN}=$clone->{DB_CONN}=$db_conn;
	return $clone;
}

sub get_next_sequence {
	my ($self,$table,%params)=@_;
	croak "abstract method ";
}


sub _create_prepare {
	my ($self,$sql,%params)=@_;
	my $tag=delete $params{TAG};
	croak "$sql: already prepared" if defined $self->{STH};
	print STDERR "(D ",nvl($tag),") $sql: prepare\n" if $self->{DEBUG};
	$self->{STH}=$self->get_connection()->prepare($sql,%params);
	$self->{SQL}=$sql;
	return $self;
}

sub bind_column {
	my ($self,$col,$value,%params)=@_;
	croak 'param col not defined' unless defined $col;
	my $name=$col->get_sql_name;
	croak Dumper($value).'the bind value is not a scalar for column '.$name if ref($value) ne '';
	print STDERR "(D ",nvl($params{TAG}),") bind column '".$self->{BINDING_TABLE}->get_sql_name.".$name' with value '".nvl($value,'<undef>')."'\n" if $self->{DEBUG};
	$self->{STH}->bind_param(':'.$name,$value);
	my $pk_seq=$col->get_attrs_value qw(PK_SEQ);
#	$self->{BINDING_VALUES}->[$pk_seq]=$value if defined $pk_seq;
	my $col_seq=$col->get_attrs_value(qw(COLUMN_SEQUENCE));
	croak $col->get_attrs_value(qw(PATH)).": COLUMN_SEQUENCE attr non set\n" unless defined $col_seq;
	$self->{BINDING_VALUES}->[$col_seq]={ COL => $col,VALUE => $value };
	return $self;
}

sub _get_column_value_init {
	my ($self,$table,$col,%params)=@_;
	my $pk_seq=$col->get_attrs_value qw(PK_SEQ);
	return undef unless defined $pk_seq;
	return $params{PK_SEQ_VALUES}->[$pk_seq] 
		if ref($params{PK_SEQ_VALUES}) eq 'ARRAY' && $pk_seq < scalar(@{$params{PK_SEQ_VALUES}});
	return  $self->get_next_sequence($table,%params) if $pk_seq == 0;
	return  0 if $pk_seq == 1;
	croak "$pk_seq: invalid PK_SEQ";
}

sub _get_insert_sql {
	my ($self,$table,%params)=@_;
	return "insert into ".$table->get_sql_name
			." ( ".join(',',map { $_->get_sql_name } $table->get_columns)
			. ") values ( ".join(',',map { ':'.$_->get_sql_name } $table->get_columns)
			. ")"
}

sub insert_binding  {
	my ($self,$table,%params)=@_;
	unless (defined $self->{BINDING_TYPE}) {
		croak "table not defined " unless defined $table;
		my $sql=$self->_get_insert_sql($table,%params);
		$self->_create_prepare($sql,%params);
		$self->{BINDING_TYPE}=BINDING_TYPE_INSERT;
		$self->{BINDING_TABLE}=$table;
		$self->{BINDING_VALUES}=[];
	}
	else {
		$table=$self->{BINDING_TABLE} unless defined $table;
		croak $self->{BINDING_TABLE}.': binding already in active'
			if $self->{BINDING_TYPE} ne BINDING_TYPE_INSERT 
				|| $self->{BINDING_TABLE}->get_sql_name ne $table->get_sql_name;
		print STDERR "(W) execute method pending\n" if $self->{EXECUTE_PENDING};
	}
	unless ($self->{EXECUTE_PENDING}) {
		for my $col($table->get_columns) {
			my $value=$self->_get_column_value_init($table,$col,%params);
			$self->bind_column($col,$value,%params);
		}
		$self->{EXECUTE_PENDING}=1;
	}
	return $self;
}

sub _get_delete_sql {
	my ($self,$table,%params)=@_;
	my @cols=$table->find_columns(PK_SEQ => 0);
	return "delete from "
			.$table->get_sql_name
			." where "
			.join(' and ',map { $_->get_sql_name.'=:'.$_->get_sql_name } @cols);
}

sub delete_rows_for_id  {
	my ($self,$table,$id,%params)=@_;
	unless (defined $self->{BINDING_TYPE}) {
		croak "table not defined " unless defined $table;
		my $sql=$self->_get_delete_sql($table,%params);
		$self->_create_prepare($sql,%params);
		$self->{BINDING_TYPE}=BINDING_TYPE_DELETE;
		$self->{BINDING_TABLE}=$table;
		$self->{BINDING_VALUES}=[];
	}
	else {
		$table=$self->{BINDING_TABLE} unless defined $table;
		croak $self->{BINDING_TABLE}.': binding already in active'
			if $self->{BINDING_TYPE} ne BINDING_TYPE_DELETE 
				|| $self->{BINDING_TABLE}->get_sql_name ne $table->get_sql_name;
		croak "execute method pending" if $self->{EXECUTE_PENDING};
	}
	if (defined $id) {
		$self->bind_column($table->find_columns(PK_SEQ => 0),$id,%params);
		$self->{EXECUTE_PENDING}=1;
		my $n=$self->execute(%params);
		$n = 0 if $n eq '0E0';
		return $n;
	}
	else {
		return undef;
	}	
}

sub _get_query_row_sql {
	my ($self,$table,%params)=@_;
	my @cols=$table->find_columns(PK_SEQ => sub { my $col=shift; defined $col->get_attrs_value qw(PK_SEQ) });
	my $sql="select * from ".$table->get_sql_name." where ".$cols[0]->get_sql_name."=:".$cols[0]->get_sql_name." order by ".$cols[0]->get_sql_name;
	$sql.=",".$cols[1]->get_sql_name if scalar(@cols) > 1;
	return $sql;
}

sub query_rows {
	my ($self,$table,$id,%params)=@_;
	unless (defined $self->{BINDING_TYPE}) {
		croak "table not defined " unless defined $table;
		my $sql=$self->_get_query_row_sql($table);
		$self->_create_prepare($sql,%params);
		$self->{BINDING_TYPE}=BINDING_TYPE_QUERY_ROW;
		$self->{BINDING_TABLE}=$table;
		$self->{BINDING_VALUES}=[];
	}
	else {
		$table=$self->{BINDING_TABLE} unless defined $table;
		croak $self->{BINDING_TABLE}.': binding already in active'
			if $self->{BINDING_TYPE} ne BINDING_TYPE_QUERY_ROW 
				|| $self->{BINDING_TABLE}->get_sql_name ne $table->get_sql_name;
	}
	if (defined $id) {
		$self->bind_column($table->find_columns(PK_SEQ => 0),$id,%params);
		$self->{EXECUTE_PENDING}=1;
		$self->execute(%params);
		return $self->{STH};
	}
	else {
		return undef;
	}
}

sub get_binding_columns {
	my ($self,%params)=@_;
	if (!defined $self->{BINDING_VALUES}) {
		return wantarray ? () : [];
	}
	my @binding=grep (!$params{PK_ONLY} || defined $_->{COL}->get_attrs_value qw(PK_SEQ),@{$self->{BINDING_VALUES}});
	return wantarray ? @binding : \@binding;
}

sub get_binding_values {
	my ($self,%params)=@_;
	my @values= map { $_->{VALUE} } $self->get_binding_columns(%params);
	return wantarray ? @values : \@values;
}

sub execute {
	my ($self,%params)=@_;
	croak "not prepared for execute" unless $self->{EXECUTE_PENDING};
	my $tag=delete $params{TAG};
	$self->get_sth->execute(%params);
	print STDERR "(D ",nvl($tag),") EXECUTED:    '".$self->{SQL}."' with keys (".join(',',map { nvl($_,'<null>') } $self->get_binding_values).")\n"  if $self->{DEBUG}; 
	delete $self->{EXECUTE_PENDING};
	return $self;
}


sub is_execute_pending { return $_[0]->{EXECUTE_PENDING} ? 1 : 0; }

sub get_query_prepared { return $_[0]->{SQL}; }


sub finish {
	my ($self,%params)=@_;
	if (defined  $self->{STH}) {
		croak "execute pending (".$self->get_query_prepared.")" if $self->is_execute_pending;
		$self->{STH}->finish;
		delete $self->{STH};
		delete $self->{BINDING_TYPE};
		delete $self->{BINDING_VALUES};
		delete $self->{BINDING_TABLE};
		delete $self->{SQL};
	}
	return $self;
}

	
sub DESTROY { $_[0]->finish; }



1;


__END__

=head1  NAME

blx::xsdsql::sql_binding -  binding generator for blx::xsdsql::xml
 

=cut

=head1 SYNOPSIS

use blx::xsdsql::sql_binding

=cut


=head1 DESCRIPTION

this package is a class - instance it with the method new



=head1 FUNCTIONS

this module defined the followed functions

new - constructor 

	PARAMS: 
		SEQUENCE_NAME => sequence name for generate ID for insert  
		DB_CONN       => DBI instance


get_connection - return the value of DB_CONN param


get_sth  - return the handle of the prepared statement


get_clone - return the clone of the object

get_next_sequence - return the next value of SEQUENCE_NAME

	PARAMS: 
		SEQUENCE_NAME - sequence name for generate ID for insert (default the valiue of the same param in the constructor)
	this method is abstract because the algorithm  depend from database


bind_column - bind a value with a column

	the first argument is a column object generate from blx::xsdsql::parser::parse
	the second argument is a scalar


insert_binding - prepare a binding for a table

	the first argument is a table object generate from blx::xsdsql::parser::parse



delete_rows_for_id - delete a row  of a table 

	the first argument is a table object generate from blx::xsdsql::parser::parse
	the second argument is  a id value
	the method return  the number of rows deleted if id value exist else return undef



query_rows - return rows reading a table

	the first argument is a table object generate from blx::xsdsql::parser::parse
	the second argument is  a id value
	in scalar mode the method return a pointer of an array 
	in array mode  the method return an array



get_binding_columns - return the columns with a value binding

	in scalar mode the method return a pointer of an array
	in array mode  the method return an array


get_binding_values -  return the values binding

	in scalar mode the method return a pointer of an array
	in array mode  the method return an array


execute - execute the current statement prepared 
	
	the method return the self object


is_execute_pending - return true if exits a prepared statement with binds but not executed

 
get_query_prepared - return the current query prepared 


finish - close the prepared statements 

	this method return the self object


=head1 EXPORT


None by default.


=head1 EXPORT_OK

	BINDING_TYPE_INSERT
	BINDING_TYPE_DELETE
	BINDING_TYPE_UPDATE
	BINDING_TYPE_QUERY_ROW

	:all


=head1 SEE ALSO

	DBI  - Database independent interface for Perl

=head1 AUTHOR

lorenzo.bellotti, E<lt>bellzerozerouno@tiscali.itE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut

