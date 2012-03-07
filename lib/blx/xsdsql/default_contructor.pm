package blx::xsdsql::default_contructor;
use strict;
use warnings;

sub new {
	my ($classname,%params)=@_;
	return bless(\%params,$classname);
}

1;

__END__

=head1  NAME

blx::xsdsql::default_contructor - class for default contructor 

=cut




