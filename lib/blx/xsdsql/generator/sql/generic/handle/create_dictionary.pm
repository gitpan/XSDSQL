package blx::xsdsql::generator::sql::generic::handle::create_dictionary;
use strict;
use warnings;
use Carp;
use base qw(blx::xsdsql::generator::sql::generic::handle);

sub _get_create_prefix {
	my ($self,%params)=@_;
	return "create table";
}

sub get_binding_objects  {
	my ($self,$schema,%params)=@_;
	my @t=map { $schema->get_dictionary_table($_,%params); } qw (TABLE_DICTIONARY COLUMN_DICTIONARY RELATION_DICTIONARY);
	return wantarray ? @t : \@t;
}

sub table_header {
	my ($self,$dic,%params)=@_;
	$self->{STREAMER}->put_line($self->_get_create_prefix,' ',$dic->get_sql_name,"( ",$dic->get_comment);
	for my $col($dic->get_columns) {
		$self->_column($col);
	}
	$self->{STREAMER}->put_line(')',$dic->command_terminator);
	$self->{STREAMER}->put_line;
	my $pk_name=$dic->get_constraint_name('pk');
	my @cols=map { $_->get_sql_name } $dic->get_pk_columns;
	$self->{STREAMER}->put_line("alter table ",$dic->get_sql_name," add constraint $pk_name primary key (".join(',',@cols).')',$dic->command_terminator);
	$self->{STREAMER}->put_line;
	return undef;
}


sub _column {
	my ($self,$col,%params)=@_;
	my $first_column=$col->get_attrs_value qw(COLUMN_SEQUENCE) == 0 ? 1 : 0;
	$self->{STREAMER}->put_line("\t".($first_column ? '' : ',').$col->get_sql_name."\t".$col->get_sql_type."\t".$col->get_comment);
	return $self;
}

1;

__END__

=head1 NAME

blx::xsdsql::generator::sql::generic::handle::create_dictionary  - generic handle for create dictionary


=head1 SYNOPSIS


use blx::xsdsql::generator::sql::generic::handle::create_dictionary


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

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
 

