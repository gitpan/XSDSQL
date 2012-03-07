package blx::xsdsql::xsd_parser::node::attributeGroup;
use base qw(blx::xsdsql::xsd_parser::node);
use strict;
use warnings;
use integer;
use Carp;
use blx::xsdsql::xsd_parser::type;

sub trigger_at_start_node {
	my ($self,%params)=@_;
	confess "internal error - attributeGroup not implemented\n";
	return $self;
}



1;

__END__


=head1  NAME

__PACKAGE__ - internal class for parsing schema 

=cut

