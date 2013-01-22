package blx::xsdsql::dbconn::oracle::dbi;
use strict;
use warnings;
use integer;

use base qw(blx::xsdsql::dbconn::generic);

use constant {
		CODE  => 'dbi:Oracle'
};

sub _get_as {
	my ($self,$h,%params)=@_;
	my @args=();
	my $s=CODE.':';
	$s.="host=".$h->{HOST}.';' if defined $h->{HOST};
	$s.="sid=".$h->{DBNAME}.';' if defined $h->{DBNAME};
	$s.="port=".$h->{PORT}.';' if defined $h->{PORT};
	push @args,$s;
	push @args,$h->{USER};
	push @args,$h->{PWD};
	return @args;
}

sub get_code { return CODE; }


1;

__END__


=head1 NAME

blx::xsdsql::dbconn::oracle::dbi - convert database connection string into dbi for oracle


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
