package blx::xsdsql::generator::sql::generic::handle::drop_table;
use strict;
use warnings;
use Carp;
use base qw(blx::xsdsql::generator::sql::generic::handle);

sub _get_drop_prefix {
	my $self=shift;
	my %params=@_;
	return "drop table";
}
sub table_header {
	my $self=shift;
	my $table=shift;
	my %params=@_;
	$self->{STREAMER}->put_line($self->_get_drop_prefix.' '.$table->get_sql_name.$table->command_terminator);
	return $self;
}

1;

__END__

=head1 NAME

blx::xsdsql::generator::sql::generic::handle::drop_table  - generic handle for drop tables


=head1 SYNOPSIS


use blx::xsdsql::generator::sql::generic::handle::drop_table


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
 

