package blx::xsdsql::dbconn::pg::dbi;
use strict;
use warnings;
use integer;

use base qw(blx::xsdsql::dbconn::generic);

use constant {
		DBI_TYPE  => 'dbi:Pg'
};

sub _get_as {
	my ($self,$h,%params)=@_;
	my @args=();
	push @args,DBI_TYPE.':'.join(';',map { lc($_).'='.$h->{$_} } grep(defined $h->{$_},qw(HOST DBNAME PORT)));
	push @args,$h->{USER};
	push @args,$h->{PWD};
	return @args;
}

1;

__END__
