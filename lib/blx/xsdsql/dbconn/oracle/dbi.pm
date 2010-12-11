package blx::xsdsql::dbconn::oracle::dbi;
use strict;
use warnings;
use integer;

use base qw(blx::xsdsql::dbconn::generic);

use constant {
		DBI_TYPE  => 'dbi:Oracle'
};

sub _get_as {
	my ($self,$h,%params)=@_;
	my @args=();
	push @args,DBI_TYPE.':'.$h->{DBNAME};
	push @args,$h->{USER};
	push @args,$h->{PWD};
	return @args;
}

1;

__END__
