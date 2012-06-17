package blx::xsdsql::xsd_parser::node::import;
use base qw(blx::xsdsql::xsd_parser::node);
use strict;
use warnings;
use integer;
use Carp;


sub trigger_at_start_node {
	my ($self,%params)=@_;
	if (defined (my $sl=$self->{schemaLocation})) {
		my $parser=$params{PARSER};
		croak "parser param not set\n" unless defined $params{PARSER};
		my %p=map { ($_,$self->{$_}); } grep($_ eq uc($_) && ref($self->{$_}) eq '' && defined $self->{$_},keys %$self);
		my $current_schema=$self->get_attrs_value(qw(STACK))->[1];
		my $ns=$self->{namespace};
		$self->_debug(__LINE__,"import: location '$sl' namespace '$ns'");
		my $cs=$parser->get_attrs_value(qw(CHILDS_SCHEMA));
		push @$cs,[$current_schema,$sl,$ns,\%p];
		$parser->set_attrs_value(CHILDS_SCHEMA => $cs);
	}
	else {
		confess "schemaLocation attr not found into import tag\n";
	}
	return $self;
}

1;


__END__


=head1  NAME

blx::xsdsql::xsd_parser::node::import - internal class for parsing schema 

=cut
