package blx::xsdsql::dbconn::generic;
use strict;
use warnings;
use integer;
use Carp;

sub _split {
	my ($self,$s,%params)=@_;
	return undef unless defined $s;
	my ($user,$pwd,$dbname,$host,$port)=$s=~/^(\w+)\/(\w+)@(\w+):([^:]+):(\d*)$/;
	($user,$pwd,$dbname,$host)=$s=~/^(\w+)\/(\w+)@(\w+):([^:]+)$/ unless defined $user;
	($user,$pwd,$dbname)=$s=~/^(\w+)\/(\w+)@(\w+)$/ unless defined $user;
	return undef unless defined $user;
	
	my %p=(
				 USER	=> $user
				,PWD	=> $pwd
				,DBNAME	=> $dbname
				,HOST	=> $host
				,PORT	=> $port
	);
	$params{$_}=$p{$_} for (keys %p);
	return \%params;
}

sub _get_as {
	my ($self,$connstr,%params)=@_;
	croak "abstract method"; 
}

sub get_application_string {
	my ($self,$connstr,%params)=@_;
	my $h=$self->_split($connstr,%params);
	return wantarray ? () : undef unless defined $h;
	my @a=$self->_get_as($h,%params);
	return @a if wantarray;
	return scalar(@a)==0 ? undef : \@a;
}

sub new {
	my ($class,%params)=@_;
	return bless \%params,$class;
}


1;

__END__




	