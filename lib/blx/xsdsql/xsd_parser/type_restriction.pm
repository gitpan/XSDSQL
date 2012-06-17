package blx::xsdsql::xsd_parser::type_restriction;
use base(qw(blx::xsdsql::xsd_parser::node));
use strict;
use warnings;
use integer;
use Carp;

sub _hook_to_parent {
	my ($self,%params)=@_;
	my $parent=$self->get_attrs_value(qw(STACK))->[-2];  # -1 is it' self
	my $ch=$parent->get_attrs_value(qw(CHILD));
	$ch=[] unless defined $ch;
	push @$ch,$self;
	$parent->set_attrs_value(CHILD => $ch);
	return $self;
}

sub trigger_at_end_node {
	my ($self,%params)=@_;
	return $self->_hook_to_parent(%params);
}

1;

