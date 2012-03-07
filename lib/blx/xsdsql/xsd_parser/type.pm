package blx::xsdsql::xsd_parser::type;
use strict;
use warnings;
use integer;
use Carp;
use Data::Dumper;

use blx::xsdsql::ut qw(nvl);
use blx::xsdsql::xsd_parser::type::simple;
use blx::xsdsql::xsd_parser::type::other;
use base qw(blx::xsdsql::log blx::xsdsql::common_interfaces);

our %_ATTRS_W=();
our %_ATTRS_R=();

sub _get_attrs_w { return \%_ATTRS_W; }
sub _get_attrs_r { return \%_ATTRS_R; }

sub _new {
	my ($class,%params)=@_;
	return bless \%params,$class;
}


sub factory {
	my ($type,%params)=@_;
	my $schema=$params{SCHEMA};
	croak "param SCHEMA not set\n" unless defined $schema;
	my $split=blx::xsdsql::xsd_parser::node::_split_tag_name($type);
	return blx::xsdsql::xsd_parser::type::simple->_new(%params,%$split) if $split->{NAMESPACE}  eq $schema->get_std_namespace_attr;
	return blx::xsdsql::xsd_parser::type::other->_new(%params,%$split);
}

1


__END__

=head1  NAME

blx::xsdsql::xsd_parser::type - internal class for parsing schema 

=cut
