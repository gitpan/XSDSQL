package blx::xsdsql::generator::sql::generic::handle::create_sequence;
use strict;
use warnings;
use Carp;
use base qw(blx::xsdsql::generator::sql::generic::handle);
use blx::xsdsql::ut qw(nvl);

sub table_header {
	my ($self,$table,%params)=@_;
	return $self if nvl($table->get_attrs_value qw(PATH)) ne '/';  #bypass if is not the root table
	my $name=$table->get_sequence_name(%params);
	$self->{STREAMER}->put_line("create sequence $name ",$table->command_terminator);
	return $self;
}

1;

__END__

=head1 NAME

blx::xsdsql::generator::sql::generic::handle::create_sequence - generic handle for create sequence


=head1 SYNOPSIS

use blx::xsdsql::generator::sql::generic::handle::create_sequence


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
 

