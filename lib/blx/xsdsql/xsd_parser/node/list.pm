package blx::xsdsql::xsd_parser::node::list;
use base qw(blx::xsdsql::xsd_parser::type_restriction);
use strict;  # use strict is for PBP
use Filter::Include;
include blx::xsdsql::include;
#line 7

sub trigger_at_start_node {
	my ($self,%params)=@_;
	$self->set_attrs_value(base => $self->get_attrs_value(qw(NAMESPACE)).':string');  #force the type in string
	return $self;
}



1;

__END__


=head1  NAME

blx::xsdsql::xsd_parser::node::list  - internal class for parsing schema

=cut


=head1 VERSION

0.10.0

=cut



=head1 BUGS

Please report any bugs or feature requests to https://rt.cpan.org/Public/Bug/Report.html?Queue=XSDSQL

=cut



=head1 AUTHOR

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>


=cut


=head1 COPYRIGHT

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
