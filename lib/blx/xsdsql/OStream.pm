package blx::xsdsql::OStream;
use strict;
use warnings;
use Carp;

use base qw(Exporter);
use subs qw(print say);

my  %t=( overload => [ qw ( print  say ) ]);
our %EXPORT_TAGS=( all => [ map { @{$t{$_}} } keys %t ],%t); 
our @EXPORT_OK=( @{$EXPORT_TAGS{all}} );
our @EXPORT=qw( );

sub _init_output_stream {
	my ($self,%params)=@_;
	return $self unless defined $self->{OUTPUT_STREAM}; 
	my $r=ref($self->{OUTPUT_STREAM});
	if ($r eq  'ARRAY') {
		$self->{O}->{I}=0;  
	}
	return $self;
}


sub new {
	my ($class,%params)=@_;
	my $s=bless(\%params,$class);
	return $s->_init_output_stream;
}

sub set_output_descriptor {
	my ($self,$fd,%params)=@_;
	$self->{OUTPUT_STREAM}=$fd;
	return $self->_init_output_stream;
}

sub put_chars {
	my $self=shift;
	my $stream = $self->{OUTPUT_STREAM};
	croak "OUTPUT_STREAM non definito" unless defined $stream;

	if ($stream eq *STDOUT || $stream eq *STDERR || ref($stream) eq 'GLOB') {
		my $r=print $stream @_;
		croak  "error: $!" unless defined $r;
	}
	elsif (ref($stream) eq '') { #string
		$self->{OUTPUT_STREAM} .= join('',@_);
	}
	elsif (ref($stream) eq 'ARRAY') {
		for my $i(0..scalar(@_) - 1) {
			my $s=$_[$i];
			unless (defined $s) {
				warn "element $i is not defined";
				next;
			}
			my $n=index($s,"\n");
			while($n >= 0) {
				my $p=substr($s,0,$n);
				$stream->[$self->{O}->{I}]='' 
					unless defined  $self->{OUTPUT_STREAM}->[$self->{O}->{I}];
				$stream->[$self->{O}->{I}].=$p;
				$s=substr($s,$n + 1);
				$n=index($s,"\n");
				$stream->[++$self->{O}->{I}]='';
			}
			$stream->[$self->{O}->{I}].=$s;
		}					
	}
	elsif (ref($stream) eq 'CODE') {
		$stream->($self,@_);
	}
	elsif (ref($stream) eq 'SCALAR') { #reference to scalar
		$$stream .= join('',@_);
	}
	else {
		croak ref($stream).': type non implemented';
	}
	return $self;
}


sub print($@) { 
	my $self=shift;
	return CORE::print($self,@_) unless ref($self) =~/::/; #if $self is not a class use CORE::print
	return $self->put_chars(@_);
}



sub put_line { my $self=shift; return $self->put_chars(@_,"\n"); }

sub say {  
			my $self=shift;
			return $self->put_line(@_) if ref($self) =~/::/;  	  #if $self is not a class use CORE::say if is implemented
			local $@;
			my $r=eval("CORE::say($self,@_)");
			return print STDOUT $self,@_,"\n" if $@;
			return $r;
}


if (__FILE__ eq $0 || $ENV{REGRESSION_TEST}) {

	use constant {
		STR => 'this is a string'
		,K   => 'this is a key'
	};

	my $out=*STDOUT;
	my $streamer=blx::xsdsql::OStream->new(OUTPUT_STREAM => \$out);
	$streamer->put_line(STR);

	$out='';
	$streamer=blx::xsdsql::OStream->new(OUTPUT_STREAM => \$out);
	$streamer->put_line(STR);
	croak "check failed " if $out ne STR."\n";

	my @arr=();
	$streamer=blx::xsdsql::OStream->new(OUTPUT_STREAM => \@arr);
	$streamer->put_line(STR);
	croak "check failed " if scalar(@arr) != 2;
	croak "check failed " if join('',@arr) ne STR;
	$streamer->put_chars(STR,STR,"\n",STR);
	croak "check failed " if scalar(@arr) != 3;
	croak "check failed " if join("\n",@arr) ne STR."\n".STR.STR."\n".STR;

	
	@arr=();
	$streamer=blx::xsdsql::OStream->new(OUTPUT_STREAM => sub { shift; push @arr,@_;}  );
	$streamer->put_line(STR);
	croak "check failed " if join('',@arr) ne STR."\n";



	$streamer=blx::xsdsql::OStream->new(OUTPUT_STREAM => '');
	$streamer->put_line(STR);
	croak "check failed " if $streamer->{OUTPUT_STREAM} ne STR."\n";

}

1;

__END__

=head1  NAME

blx::xsdsql::OStream -  generic  output streamer into a  string,array,file descriptor or subroutine 


=cut

=head1 SYNOPSIS

use blx::xsdsql::OStream

=cut


=head1 DESCRIPTION

this package is a class - instance it with the method new



=head1 FUNCTIONS

this module defined the followed functions

new - constructor 

	PARAMS:
		OUTPUT_STREAMER -  an array,string,soubroutine or a file descriptor (default not set) 



set_output_descriptor - the first param  is a value same as OUTPUT_STREAMER

	the method return the self object



put_chars -   emit @_ on the streamer 

	the method return the self object
	on error throw an exception
 

put_line  - equivalent to put_chars(@_,"\n");


print - equivalent to put_chars


say - equivalent to put_line


=head1 EXPORT

None by default.


=head1 EXPORT_OK

print 

say 

:all  export all 

=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

=head1 AUTHOR

lorenzo.bellotti, E<lt>bellzerozerouno@tiscali.itE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
