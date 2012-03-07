package blx::xsdsql::xsd_parser::type::other;
use strict;
use warnings;
use integer;
use Carp;

use base qw(blx::xsdsql::xsd_parser::type);


sub _new {
	my ($class,%params)=@_;
	for my $k(keys %params) { delete $params{$k} if $k=~/^SQL_/; } 
	my $self=bless \%params,$class;
	return $self;
}


sub resolve_type {
	my ($self,$types,%params)=@_;
	if (defined (my $name=$self->{FULLNAME})) {
		return undef if length($self->{NAMESPACE}); # if $self is a type with namespace the resolution is posted    
		my $t=$types->{$name};
		confess "$name: name not found into custom types\n" unless defined $t;
		$self->_debug(__LINE__,'factory type from object type ',ref($t));
		return $t->factory_type($t,$types,%params);
	}
	confess "name attr not set\n";
	return undef;
}

sub resolve_external_type {
	my ($self,$schema,%params)=@_;
	my ($ns,$name)=($self->{NAMESPACE},$self->{NAME});
	if (defined (my $s=$schema->find_schema_by_namespace_abbr($ns))) {
		my $types=$s->get_attrs_value qw(TYPES);
		my %type_node_names=map  {  ($_->get_attrs_value qw(name),$_); } @$types;
		if (defined (my $t=$type_node_names{$name})) {
			$self->_debug(__LINE__,'factory type from object type ',ref($t));
			return $t->factory_type($t,\%type_node_names,%params);
		}
		else {
			confess "$name: name not found into custom types\n" unless defined $t;
		}
	}
	else {
		confess "$ns: not find schema from this namespace abbr\n" unless defined $s;
	}
	return undef;
}


1;


__END__


=head1  NAME

blx::xsdsql::xsd_parser::type::other - internal class for parsing schema 

=cut
