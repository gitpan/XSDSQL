package blx::xsdsql::ut;
use 5.008000;
use strict;
use warnings;
use base qw(Exporter);
use Carp;

our %EXPORT_TAGS = ( 'all' => [ qw( nvl ev ) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw( );

our $VERSION = '0.009000';

sub  nvl {
	return '' if scalar(@_) == 0;
	return defined $_[0] ? $_[0] : '' if scalar(@_) == 1;
	return defined $_[0] ? $_[0] : $_[1] if scalar(@_) == 2;
	return defined $_[0] ? $_[1] : $_[2] if scalar(@_) == 3;
	my $a=[nvl(@_[0..2]),@_[3..scalar(@_) -1]];
	return wantarray  ? @$a : $a;
}

sub ev {
	my $r=eval join(' ',@_);
	croak $@ if $@;
	return $r;
}

1;

__END__


=head1 NAME

blx::xsdsql::ut - Perl  version  and ut for blx::xsdsql


=head1 SYNOPSIS

use blx::xsdsql::ut;


=head1 DESCRIPTION

this package contain generic utilities

=head1 GLOBALS

VERSION - version number


=head1 FUNCTIONS

this module defined the followed functions

nvl(arg1)  -  equivalent to:  defined arg1 ? arg1 : ''   

nlv(arg1,arg2) - equivalent to:  defined arg1 ? arg1 : arg2

nvl(arg1,arg2,arg3) - equivalent to: defined arg1 ? arg2 : arg3

nvl(arg1,arg2,arg3,argn..) - equivalent to:  (nvl(arg1,arg2,arg3),argn..)

ev(args) -  eval the join of args and return the result or throw $@ on error



=head1 EXPORT

None by default.


=head1 EXPORT_OK

nvl ev get_attrs_value set_attrs_value :all 

=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

=head1 AUTHOR

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html


=cut


