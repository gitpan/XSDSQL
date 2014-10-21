package blx::xsdsql::generator::sql::generic::handle::addpk;
use strict;
use warnings;
use Carp;
use base qw(blx::xsdsql::generator::sql::generic::handle);

sub table_header {
	my ($self,$table,%params)=@_;
	my $table_name=$table->get_sql_name(%params);
	my $pk_name=$table->get_constraint_name('pk');
	my @cols=map { $_->get_sql_name } $table->get_pk_columns;
	$self->{STREAMER}->put_line("alter table $table_name add constraint $pk_name primary key (".join(',',@cols).')',$table->command_terminator);
	return $self;
}

1;

__END__

=head1 NAME

blx::xsdsql::generator::sql::generic::handle::addpk - generic handle for add primary key


=head1 SYNOPSIS

use blx::xsdsql::generator::sql::generic::handle::addpk


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
 

