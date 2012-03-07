package blx::xsdsql::xml::generic::name_generator;

use strict;
use warnings;
use integer;
use Carp;


sub _adjdup_sql_name {
	my ($self,$name,$maxsize,%params)=@_;
	my ($d,$l)=map { 
		my $v=$params{$_};
		confess "param $_ not set\n" unless defined $v;
		$v
	} qw(DIGITS LIST);

	my $origname=$name;

	if (length($name) + $d > $maxsize) {
		$name=substr($name,0,$maxsize - $d);
	}

	my ($count,$max)=($d == 1 ? 0 : 10**($d - 1),10**$d - 1);
	while(1) {
		my $v=$name.sprintf("%0${d}d",$count++);
		return $v unless exists $l->{uc($v)};
		last if $count > $max;
	}
	return $self->_adjdup_sql_name($origname,$maxsize,%params,DIGITS => ++$d);
}

sub _translate_path  {
	my ($self,%params)=@_;
	confess "abstract method\n";
}


sub _resolve_invalid_name {
	my ($self,$name,%params)=@_;
	confess "abstract method\n";
	return $name;
}

sub _reduce_sql_name {
	my ($self,$name,$maxsize,%params)=@_;
	confess "abstract method\n";
	return $name;
}

sub _gen_name {
	my ($self,%params)=@_;
	my ($ty,$l)=map {
			my $v=$params{$_};
			confess "param $_ not set\n" unless defined $v;
			$v;
	} qw(TY LIST); 

	confess "param NAME or PATH not set\n" unless defined $params{NAME} || defined $params{PATH};
	my $name= $self->_translate_path(%params);
	my $maxsize=defined $params{MAXSIZE} ? $params{MAXSIZE} : $self->get_name_maxsize();
	$name=$self->_reduce_sql_name($name,$maxsize,%params) if length($name) > $maxsize;
	$name=$self->_resolve_invalid_name($name,MAXSIZE => $maxsize);

	confess "$name: check failed\n" if length($name) >  $maxsize;

	if (exists $l->{uc($name)}) {
		my $v=$self->_adjdup_sql_name($name,$maxsize,%params,DIGITS => 1);
		confess "$name: not generate name from this string\n" unless defined $v;

		unless (defined $v) {
			$v=$ty.'0'x($maxsize - length($ty));
			$name=$self->_adjdup_sql_name($v,$maxsize,%params,DIGITS => 1);
			confess "$v: not generate name from this string\n" unless defined $name;
		}
		else {
			$name=$v;
		}
	}
	confess "postcondition failed - duplicate  name" if exists $l->{uc($name)}; 
	confess "$name: postcondition failed - name excedid  name database limit\n" if length($name) > $maxsize;
	$l->{uc($name)}=1;
	return $name;
}


1;


__END__


=head1  NAME

blx::xsdsql::xml::generic::name_generator -  a name generator class 

=cut

=head1 AUTHOR

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIG 

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
