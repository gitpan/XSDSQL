package blx::xsdsql::generator::sql::generic::handle::create_view;


use strict;
use warnings;
use Carp;
use base qw(blx::xsdsql::generator::sql::generic::handle);

sub _get_create_prefix {
	my ($self,%params)=@_;
	return "create view";
}

#sub _generate_column {
#	my ($self,$table,%params)=@_;
#	my %h=();
#	for my $col($table->get_columns) {
#		my $path=$col->get_attrs_value qw(PATH_REFERENCE);
#		next unless defined $path;
#		$h{$path}=[$table,$col];  
#	}
#	return %h;
#}
#
#sub _get_ref_columns_path { #return an hash path => [ table,column ]
#	my ($self,$table,%params)=@_;
#	$params{COLUMNS_LIST}={ PATH_REFERENCE => {} }  if nvl($table->{PATH}) eq '/';
#	my %h=$self->_generate_column($table,%params);
#	for my $t($table->get_child_tables) {
#		my %h1=$self->_get_ref_columns_path($t,%params);
#		$h{$_}=$h1{$_} foreach keys %h1;
#	}
#	if (nvl($table->{PATH}) eq '/') {
#		for my $t(@{$table->{TYPES}}) {
#			$self->_get_columns_($t,%params);
#		}
#	}
#	return nvl($table->{PATH}) eq '/' ? delete $params{COLUMNS_LIST} : undef; 
#}
#

sub _get_view_columns {
	my ($self,$table,%params)=@_;
	my @cols=map { $_  
#		my $col=$_;
#		if ($col->get_attrs_value(qw(PATH_REFERENCE)) 
	
	
	
	} $table->get_columns;
	for my $t($table->get_child_tables) {
		push @cols,map { $_  } $self->_get_view_columns($t,%params);
	}
	return @cols;
}

sub table_header {
	my ($self,$table,%params)=@_;
	my $path=$table->get_attrs_value qw(PATH);
	my $comm=defined  $path ? $table->comment('PATH: '.$path) : '';
	$self->{STREAMER}->put_line($self->_get_create_prefix,' ',$table->get_sql_name," as select  $comm");

	my @cols=$self->_get_view_columns($table,%params);
	for my $col(@cols) {
		my $first_column=$col->get_attrs_value qw(COLUMN_SEQUENCE) == 0 ? 1 : 0;
		my ($col_name,$col_type,$path)=($col->get_sql_name(%params),$col->get_sql_type(%params),$col->get_attrs_value qw(PATH));
		my $comm=defined $path ? 'PATH: '.$path : '';
		my $ref=$col->get_attrs_value qw(PATH_REFERENCE);
		$comm.=defined $ref ? ' REF: '.$ref : '';
		$comm=~s/^(\s+|\s+)$//;
		my $sqlcomm=length($comm) ?  $col->comment($comm) : '';
		$self->{STREAMER}->put_line("\t".($first_column ? '' : ',').$col_name."\t".$col_type."\t".$sqlcomm);
	}
	return $self;
}

sub table_footer {
	my ($self,$table,%params)=@_;
	$self->{STREAMER}->put_line(' from ',$table->get_sql_name,$table->command_terminator);
	$self->{STREAMER}->put_line;
	return $self;
}

#sub column {
#	my ($self,$col,%params)=@_;
#=pod
#	my $first_column=$col->get_attrs_value qw(COLUMN_SEQUENCE) == 0 ? 1 : 0;
#
#	my ($col_name,$col_type,$path)=($col->get_sql_name(%params),$col->get_sql_type(%params),$col->get_attrs_value qw(PATH));
#	my $comm=defined $path ? 'PATH: '.$path : '';
#	my $ref=$col->get_attrs_value qw(PATH_REFERENCE);
#	$comm.=defined $ref ? ' REF: '.$ref : '';
#	$comm=~s/^(\s+|\s+)$//;
#	my $sqlcomm=length($comm) ?  $col->comment($comm) : '';
#	$self->{STREAMER}->put_line("\t".($first_column ? '' : ',').$col_name."\t".$col_type."\t".$sqlcomm);
#=cut
#	return $self;
#}


1;


__END__

=head1 NAME

blx::xsdsql::generator::sql::generic::handle::create_view  - generic handle for create view


=head1 SYNOPSIS


use blx::xsdsql::generator::sql::generic::handle::create_view


=head1 DESCRIPTION

this package is a class - instance it with the method new

=cut


=head1 FUNCTIONS

see the methods of blx::xsdsql::generator::sql::generic::handle 

=head1 EXPORT

None by default.


=head1 EXPORT_OK

None

=head1 SEE ALSO


See  blx::xsdsql::generator::sql::generic::handle - this class inherit from this 


=head1 AUTHOR

lorenzo.bellotti, E<lt>bellzerozerouno@tiscali.itE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
 

