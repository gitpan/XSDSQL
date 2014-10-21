package blx::xsdsql::generator::sql::generic::handle::drop_dictionary;
use strict;
use warnings;
use Carp;
use base qw(blx::xsdsql::generator::sql::generic::handle);

sub _get_drop_prefix {
	my ($self,%params)=@_;
	return "drop table";
}

sub _get_drop_suffix {
	my ($self,%params)=@_;
	return "";
}

sub get_binding_objects  {
	my ($self,$schema,%params)=@_;
	my @t=map { $schema->get_dictionary_table($_,%params); } qw (TABLE_DICTIONARY COLUMN_DICTIONARY RELATION_DICTIONARY);
	return wantarray ? @t : \@t;
}

sub table_header {
	my ($self,$table,%params)=@_;
	$self->{STREAMER}->put_line($self->_get_drop_prefix,' ',$table->get_sql_name,' ',$self->_get_drop_suffix,' ',$table->get_comment,$table->command_terminator);
	return undef;
}


1;

__END__

=head1 NAME

blx::xsdsql::generator::sql::generic::handle::drop_dictionary - generic handle for drop dictionary


=head1 SYNOPSIS


use blx::xsdsql::generator::sql::generic::handle::drop_view


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
 

