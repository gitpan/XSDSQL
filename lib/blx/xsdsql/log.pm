package blx::xsdsql::log;
use strict;
use warnings;
use Data::Dumper;

use blx::xsdsql::ut qw(nvl);

sub _debug {
	return $_[0] unless $_[0]->{DEBUG};
	my ($self,$n,@l)=@_;
	$n='<undef>' unless defined $n;
	unless (defined $self->{DEBUG_NAME}) {
		my $r=ref($self);
		$r=~s/^blx::xsdsql:://;
		$self->{DEBUG_NAME}=$r;
	}
	print STDERR $self-> {DEBUG_NAME},' (D ',$n,'): ',join(' ',map { ref($_) eq "" ? nvl($_) : Dumper($_); } @l),"\n"; 
	return $self;
}


1;

__END__

=head1  NAME

blx::xsdsql::log - class for logging  - this class is used internally 

=cut


