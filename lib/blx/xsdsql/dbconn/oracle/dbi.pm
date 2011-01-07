package blx::xsdsql::dbconn::oracle::dbi;
use strict;
use warnings;
use integer;

use base qw(blx::xsdsql::dbconn::generic);

use constant {
		DBI_TYPE  => 'dbi:Oracle'
};

sub _get_as {
	my ($self,$h,%params)=@_;
	my @args=();
	push @args,DBI_TYPE.':'.$h->{DBNAME};
	push @args,$h->{USER};
	push @args,$h->{PWD};
	return @args;
}

1;

__END__


=head1 NAME

blx::xsdsql::dbconn::oracle::dbi - convert database connection string into dbi for postgresql


=head1 SYNOPSIS


use blx::xsdsql::dbconn::oracle::dbi


=head1 DESCRIPTION

this package is a class - instance it with the method new

=cut


=head1 FUNCTIONS


new - constructor

	PARAMS - none



=head1 EXPORT

None by default.


=head1 EXPORT_OK

None

=head1 SEE ALSO


See  blx::xsdsql::dbconn::generic   - this class  implement the generic method get_application_string 


=head1 AUTHOR

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
