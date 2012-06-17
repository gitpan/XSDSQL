package blx::xsdsql::xsd_parser::node;

use strict;
use warnings FATAL => 'all';
use integer;
use Carp;
use POSIX;
use Data::Dumper;

use blx::xsdsql::ut qw(ev nvl);
use base qw(blx::xsdsql::log blx::xsdsql::common_interfaces);

our %_ATTRS_W=();
our %_ATTRS_R=();

sub _get_attrs_w { return \%_ATTRS_W; }
sub _get_attrs_r { return \%_ATTRS_R; }


use constant {
	UNBOUNDED	=> INT_MAX
};


sub  _resolve_maxOccurs {
	my ($self,%params)=@_;
	my $n=exists $params{VALUE} ? $params{VALUE} : $self->get_attrs_value(qw(maxOccurs)); 
	$n=nvl($n,1);
	$n=UNBOUNDED if $n eq 'unbounded';
	return $n;
}

sub _resolve_minOccurs {
	my ($self,%params)=@_;
	return 0 if $params{CHOICE};
	my $n=exists $params{VALUE} ? $params{VALUE} : $self->get_attrs_value(qw(minOccurs)); 
	return nvl($n,1);
}

sub _resolve_form {
	my ($self,%params)=@_;
	my $form=$self->get_attrs_value(qw(form));
	$form=$self->get_attrs_value(qw(STACK))->[1]->get_attrs_value(qw(elementFormDefault)) 	unless defined $form;
	$form='U' unless defined $form;
	$form='Q' if $form eq 'qualified';
	$form='U' if $form eq 'unqualified';
	return $form;
}

sub _split_tag_name  {  # split tag into namespace/name
	my ($name,%params)=@_;
	my @a=$name=~/^([^:]+):([^:]+)$/;
	@a=('',$name) unless scalar(@a);  # name without namespace prefix 
	return {
			FULLNAME		=> $name
			,NAMESPACE		=> $a[0]
			,NAME 			=> $a[1]
	};	
}

sub _new {
	my ($class,%params)=@_;
	return bless \%params,$class;
}

sub _construct_path {
	my ($self,$name,%params)=@_;
	my $parent=nvl($params{PARENT},$self->get_attrs_value(qw(STACK))->[-1]);
	my $path=$parent->get_attrs_value(qw(PATH));
	return $path unless defined $path;
	if (defined $name) {
		$path.='/' unless $path eq '/';
		$path.=$name;
	}
	return $path;
}

sub _get_parent_table {
	my ($self,%params)=@_;
	my $i=-1;
	while(1) {
		my $parent=$self->get_attrs_value(qw(STACK))->[$i];
		last unless defined $parent;
		if (defined (my $parent_table=$parent->get_attrs_value(qw(TABLE)))) {
			return $parent_table; 
		}
		$i--;
	}
	confess "internal error\n";
}

sub _get_parent_path {
	my ($self,%params)=@_;
	my $i=-1;
	my $stack=$self->get_attrs_value(qw(STACK));
	while(1) {
		my $parent=$stack->[$i];
		last unless defined $parent;
		if (defined(my $path=$parent->get_attrs_value(qw(PATH)))) {
			return $path;
		}
		$i--;
	}
	confess "internal error\n";
}


sub _resolve_simple_type {
	my ($self,$t,$types,$out,%params)=@_;
	if (ref($t)=~/::union/) {
		$out->{base}='string';
		return $self;
	}
	if (defined (my $base=$t->get_attrs_value(qw(base)))) {
		my $t=blx::xsdsql::xsd_parser::type::factory($base,%params);
		if (ref($t)=~/::type::simple/) { 
			$out->{base}=$t->get_attrs_value(qw(NAME));
		}
		elsif (defined $types) {
			my $t=$types->{$base};
			confess "$base: type not found\n" unless defined $t;
			$self->_resolve_simple_type($t,$types,$out,%params);
		}
		else {
			$out->{base}=$t;
		}
	}
	if (defined (my $v=$t->get_attrs_value(qw(value)))) {
		my $r=ref($t);
		my ($b)=$r=~/::([^:]+)$/;
		confess "internal error\n" unless defined $b;
		if ($b eq 'enumeration') {
			$out->{$b}=[] unless defined $out->{$b};
			$self->_debug(__LINE__,$v);
			push @{$out->{$b}},$v;
		}
		else {
			$out->{$b}=$v;
		}
	}

	if (defined (my $child=$t->get_attrs_value(qw(CHILD)))) {
		confess "internal error\n" unless ref($child) eq 'ARRAY';
		for my $c(@$child) {
			$self->_resolve_simple_type($c,$types,$out,%params);
		}
	}
	return $self;
}

sub _dynamic_create {
	my ($tag,%params)=@_;
	my $split=_split_tag_name($tag,%params);
	if (defined (my $name=$split->{NAME})) {
		my $class='blx::xsdsql::xsd_parser::node::'.$name;
		ev("use $class");
		my $attrs=delete $params{ATTRIBUTES};
		my $obj=$class->_new(
					%params
					,%$attrs
					,%$split
		);
		unless ($name eq 'schema') {
			if (defined (my $path=$obj->_get_parent_path(%params)))  {
				if (defined (my $name=$attrs->{name})) {
					$path.='/'  if $path ne '/';
					$path.=$name;
				}
				$obj->set_attrs_value(PATH => $path);
			}
			else {
				confess "internal error - PATH not set\n";
			}
		}
		return $obj;
	}
	else {
		confess "$tag: internal error - NAME not set\n";
	}
}

sub factory_object {
	my ($tag,%params)=@_;
	croak "STACK param not set\n" unless defined $params{STACK};
	croak "ATTRIBUTES param not set\n" unless defined $params{ATTRIBUTES};
	my $obj=_dynamic_create($tag,%params);
	return $obj;
}

sub trigger_at_start_node {
	my ($self,%params)=@_;
	return undef;
}

sub trigger_at_end_node {
	my ($self,%params)=@_;
	return undef;
}


1;

__END__

=head1  NAME

blx::xsdsql::xsd_parser::node - internal class for parsing schema 

=cut
