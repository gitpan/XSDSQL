package blx::xsdsql::common_interfaces;
use strict;
use warnings;
use blx::xsdsql::ut;
use Carp;

sub _fusion_params {
	my ($self,%params)=@_;
	my %p=%$self;
	for my $p(keys %params) {
		$p{$p}=$params{$p};
	}
	return \%p;
}

sub _get_attrs_w {
	croak "set the method _get_attrs_w for use set_attrs_value\n";
	return $_[0];
}

sub _get_attrs_r {
	croak "set the metod _get_attrs_r for use get_attrs_value\n";
	return $_[0];
}

sub _am {
	croak "abstract method called\n";
	return $_[0];
}

sub get_attrs_value {
	my $self=shift;
	my $h=$self->_get_attrs_r;
	my @out=();
	for my $attr(@_) {
		my $f=$h->{$attr};
		if (!defined $f) {
			push @out,$self->{$attr};
		}
		elsif (ref($f) eq 'CODE') {
			push @out,$f->($self,$attr);
		}
		else {
			push @out,$f;
		}
	}
	return @out if wantarray;
	return \@out if scalar(@out) > 1;
	return $out[0] if scalar(@out) == 1;
	return undef;
}

sub set_attrs_value {
	my $self=shift;
	my $h=$self->_get_attrs_w;
	croak "Odd elements\n" unless scalar(@_) % 2 == 0;
	for (my $i=0; $i < scalar(@_); $i+=2) {
		my ($attr,$v)=($_[$i],$_[$i + 1]);
		my $f=$h->{$attr};
		if (!defined $f) {
			$self->{$attr}=$v;
		}
		else {
			my $r = ref($f) eq 'CODE' ?  $f->($self,$v) : $f;
			if (ref($r) eq '') {
				$self->{$attr}=$r;
			}
			elsif (ref($r) eq 'HASH') {
				for my $k(keys %$r) {
					$self->{$k}=$r->{$k};
				}
			}
			elsif (ref($r) eq 'ARRAY') {
				for my $k(keys %$r) {
					$self->{$k}=$r->{$k};
				}
			}
			elsif (ref($r) =~/::/) { #assume object
				$r->set_attr_value($attr => $v);
			}
			else {
				$self->{$attr}=$r;
			}
		}
	}
	return $self;
}

sub shallow_clone {
	my ($self,%params)=@_;
	my %newtable=%$self;	
	return bless \%newtable,ref($self);
}


1;

__END__

=head1  NAME

blx::xsdsql::common_interfaces - class for common methods  

get_attrs_value    -  generic method for  return value of  attribute

	the params is a list of attributes name
	the method return a list of values or a value if the params is one

set_attrs_value  - generic method for set a value of attribute
	the params are a pair of NAME => VALUE
	the method return a self object


shallow_clone - return a shallow clone of the self object


=cut


