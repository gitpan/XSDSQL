package blx::xsdsql::generator::sql::generic::handle;
use strict;
use warnings;
use Carp;

use blx::xsdsql::ut qw(nvl ev);

use constant {
	STREAM_CLASS  => 'blx::xsdsql::OStream'
};


sub header {
	my ($self,$table,%params)=@_;
	$self->{STREAMER}->put_line;
	$self->{STREAMER}->put_line($table->comment('generated by blx::xsd2sql'));
	$self->{STREAMER}->put_line; 
	return $self;
}

sub table_header {
	my ($self,$table,%params)=@_;
	return $self;
}

sub table_footer {
	my ($self,$table,%params)=@_;
	return $self;
}

sub column {
	my ($self,$table,%params)=@_;
	return $self;
}

sub footer {
	my ($self,$table,%params)=@_;
	$self->{STREAMER}->put_line;
	$self->{STREAMER}->put_line($table->comment('end of  blx::xsd2sql'));
	$self->{STREAMER}->put_line; 
	return $self;
}

sub new {
	my ($class,%params)=@_;
	my $fd=nvl(delete $params{FD},*STDOUT);
	my $self=bless \%params,$class;

	if (ref($fd) ne STREAM_CLASS) {
		if (ref($self->{STREAMER}) eq STREAM_CLASS) {
			$self->{STREAMER}->set_output_descriptor($fd);
		}
		else {
			ev('use ',STREAM_CLASS);
			$self->{STREAMER}=STREAM_CLASS->new(OUTPUT_STREAM => $fd);
		}
	}
	else {
		$self->{STREAMER}=$fd;
	}
	return $self;
}


1;



__END__



=head1  NAME

blx::xsdsql::generator::sql::generic::handle -  generic handles for generator

=cut

=head1 SYNOPSIS

use blx::xsdsql::generator::sql::generic::handle

=cut


=head1 DESCRIPTION

this package is a class - instance it with the method new


=head1 FUNCTIONS

this module defined the followed functions

new - constructor

	PARAMS:
		FD  => streamer class, file descriptor  , array or string  (default *STDOUT)


header - emit on FD the header lines 

	the first argument is a table object generate from blx::xsdsql::parser::parse


footer - emit on FD the footer lines 

	the first argument is a table object generate from blx::xsdsql::parser::parse


table_header - emit on FD the table header (for example the 'create table' ) 

	the first argument is a table object generate from blx::xsdsql::parser::parse


table_footer- emit on FD the table footer (for example the ')'  in create table) 

	the first argument is a table object generate from blx::xsdsql::parser::parse


column - emit on FD the column line (for example  the line column_name column_type in create table)

	the first argument is a column object generate from blx::xsdsql::parser::parse
 
  
=head1 EXPORT

None by default.


=head1 EXPORT_OK
	
None

=head1 SEE ALSO

See blx:.xsdsql::generator for generate the schema of the database  

=head1 AUTHOR

lorenzo.bellotti, E<lt>bellzerozerouno@tiscali.itE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut


