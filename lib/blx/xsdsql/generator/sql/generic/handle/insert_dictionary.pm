package blx::xsdsql::generator::sql::generic::handle::insert_dictionary;
use strict;
use warnings;
use Carp;
use base qw(blx::xsdsql::generator::sql::generic::handle);

sub _get_create_prefix {
	my ($self,%params)=@_;
	return "insert into ";
}


sub _get_columns_string_list {
	my ($self,$columns,%params)=@_;
	return '('.join(',',map { $_->get_sql_name } @$columns).')';
}


sub _get_begin_value_constant {
	my ($self,%params)=@_;
	return " values (";	
}

sub _get_value_data {
	my ($self,$columns,$data,%params)=@_;
	return join(',',map {
							my $name=uc($_->get_sql_name);
							confess "$name: column non defined in data " if !exists $data->{$name}; 
							my $d=$data->{$name};
							if (defined $d) {
								$d=~s/'/''/g;	#'
								$d="'".$d."'" unless $d=~/^\d+$/; 
							}
							else {
								$d="null";
							}
							$d;
						}  @$columns
	);
}

sub _get_end_value_constant {
	my ($self,%params)=@_;
	return ")";	
}


sub get_binding_objects  {
	my ($self,$schema,%params)=@_;
	my $root_table=$schema->get_root_table;
	return wantarray ? ( $root_table ) : [ $root_table ];
}


sub table_header {
	my ($self,$table,%params)=@_;
	my $schema=$params{SCHEMA};

	croak "param SCHEMA not defined " unless defined $schema;
	my $dic=$schema->get_dictionary_table qw(TABLE_DICTIONARY);
	my $data=$table->get_dictionary_data qw(TABLE_DICTIONARY);
	my $dic_columns=$dic->get_columns;
	$self->{STREAMER}->put_line(
			$self->_get_create_prefix
			,$dic->get_sql_name
			,$self->_get_columns_string_list($dic_columns)
			,$self->_get_begin_value_constant
			,$self->_get_value_data($dic_columns,$data)
			,$self->_get_end_value_constant
			,$table->command_terminator
	);

	$dic=$schema->get_dictionary_table qw(COLUMN_DICTIONARY);
	$dic_columns=$dic->get_columns;
	
	for my $data($table->get_dictionary_data qw(COLUMN_DICTIONARY)) {
		$self->{STREAMER}->put_line(
			$self->_get_create_prefix
			,$dic->get_sql_name
			,$self->_get_columns_string_list($dic_columns)
			,$self->_get_begin_value_constant
			,$self->_get_value_data($dic_columns,$data)
			,$self->_get_end_value_constant
			,$table->command_terminator
		);
	}

	$dic=$schema->get_dictionary_table qw(RELATION_DICTIONARY);
	$dic_columns=$dic->get_columns;
	for my $data($table->get_dictionary_data qw(RELATION_DICTIONARY)) {
		$self->{STREAMER}->put_line(
			$self->_get_create_prefix
			,$dic->get_sql_name
			,$self->_get_columns_string_list($dic_columns)
			,$self->_get_begin_value_constant
			,$self->_get_value_data($dic_columns,$data)
			,$self->_get_end_value_constant
			,$table->command_terminator
		);		
	}
	return $self;
}


1;

__END__

=head1 NAME

blx::xsdsql::generator::sql::generic::handle::insert_dictionary  - generic handle for insert dictionary


=head1 SYNOPSIS


use blx::xsdsql::generator::sql::generic::handle::insert_dictionary


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

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
 

