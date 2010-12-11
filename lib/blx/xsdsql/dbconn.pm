package blx::xsdsql::dbconn;
use strict;
use warnings;
use integer;
use Carp;
use File::Spec;
use blx::xsdsql::ut qw(ev);

sub new {
	my ($class,%params)=@_;
	return bless \%params,$class;
}

sub get_application_string {
	my ($self,$s,%params)=@_;
	unless (defined $s) {
		return wantarray ? () : undef;
	}
	for my $p qw(APPLICATION DBTYPE) {
		$params{$p} = $self->{$p} unless defined $params{$p};
	}
	croak "APPLICATION param not set" unless defined $params{APPLICATION};
	my $dbtype=$params{DBTYPE};
	unless (defined $dbtype) {
		($dbtype,my $newstr)=$s=~/^(\w+):(.*)$/;
		unless (defined $dbtype) {
			return wantarray ? () : undef;
		}		
		$s=$newstr;
	}
	my $use="blx::xsdsql::dbconn::${dbtype}::".$params{APPLICATION};
	ev("use $use");
	my $appl=$use->new;
	for my $p qw(APPLICATION DBTYPE) {
		delete $params{$p};
	}
	
	my @r=$appl->get_application_string($s,%params);
	return @r if wantarray;
	return undef unless scalar(@r);
	return \@r;
}
	
	

sub get_applications_classname {
	my @n=();
	for my $i(@INC) {
		my $dirgen=File::Spec->catdir($i,'blx','xsdsql','dbconn');
		next unless  -d "$dirgen";
		next if $dirgen=~/^\./;
		next unless opendir(my $fd,$dirgen);
		while(my $d=readdir($fd)) {
			my $dirout=File::Spec->catdir($dirgen,$d);
			next unless -d $dirout;
			next if $d=~/^\./;
			next unless opendir(my $fd1,$dirout);
			while(my $d1=readdir($fd1)) {
				my $f=File::Spec->catdir($dirgen,$d,$d1);
				next unless -r $f;
				next if $d1=~/^\./;
				next unless $d1=~/\.pm$/;
				$d1=~s/\.pm$//;
				push @n,'blx::xsdsql::dbconn::'.$d.'::'.$d1;
			}
			closedir $fd1;
		}
		closedir($fd);
	}
	return wantarray ? @n : \@n;
}

sub get_database_availables {
	my %db=();
	for my $n(get_applications_classname) {
		if ($n=~/::(\w+)::\w+$/) {
			$db{$1}=undef;
		}
	}
	return keys %db;		
}

sub get_application_valiables {
	my %appl=();
	for my $n(get_applications_classname) {
		if ($n=~/::(\w+)$/) {
			$appl{$1}=undef;
		}
	}
	return keys %appl;			
}

1;

__END__




	