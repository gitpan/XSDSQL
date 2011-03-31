package blx::xsdsql::xml::generic::catalog;

use strict;
use warnings;
use Carp;

use blx::xsdsql::ut;

use constant {
				 DICTIONARY_NAME_MAXSIZE	=> 2048
				,DICTIONARY_COMMENT_MAXSIZE	=> 2048
				,BEGIN_COMMENT				=> '/*'
				,END_COMMENT				=> '*/'
				,COMMAND_TERMINATOR			=> ';'
};


our %_ATTRS_R=();
our %_ATTRS_W=();


sub new {
	my $classname=shift;
	my %params=@_;
	return bless(\%params,$classname);
}

sub get_name_maxsize { return DICTIONARY_NAME_MAXSIZE; }

sub get_comment_maxsize { return DICTIONARY_COMMENT_MAXSIZE; }

sub get_begin_comment { return 	BEGIN_COMMENT; }

sub get_end_comment {	return END_COMMENT; }

sub command_terminator { return COMMAND_TERMINATOR; }

sub comment {
	my $self=shift;
	my $c=join('',@_);
	return $c if $c eq '';
	return $self->get_begin_comment().' '.substr($c,0,$self->get_comment_maxsize).' '.$self->get_end_comment();
}

sub get_comment {
	my ($self,%params)=@_;
	my $c=$self->get_attrs_value qw(COMMENT);
	return '' unless $c;
	return $self->comment($c)
}

sub set_attrs_value {
	my $self=shift;
	blx::xsdsql::ut::set_attrs_value($self,\%_ATTRS_W,@_);
	return $self;
}

sub get_attrs_value {
	my $self=shift;
	return blx::xsdsql::ut::get_attrs_value($self,\%_ATTRS_R,@_);
}


sub shallow_clone {
	my ($self,%params)=@_;
	my %newtable=%$self;	
	return bless \%newtable,ref($self);
}


1;

__END__


=head1  NAME

blx::xsdsql::xml::generic::catalog -  a catalog is a class with include the common methods from table class  and column class (for example the   max length of  a dictionary database name)

=cut

=head1 SYNOPSIS

use blx::xsdsql::xml::generic::catalog

=cut


=head1 DESCRIPTION

this package is a class - instance it with the method new


=head1 FUNCTIONS

this module defined the followed functions

new - constructor   

	PARAMS:
		COMMENT - an associated comment
			

get_name_maxsize  - return the max_size of a database dictionary name 


get_comment_maxsize  - return the max_size of a comment


get_begin_comment  - return the characters that it's interpreted as  a begin comment


get_end_comment - return the characters that it's interpreted as  a end comment


command_terminator  - return the characters that it's interpreted as a command terminator


comment  - return a text enclosed by  comment symbols

	the arguments are a text 


get_comment - return a text value of the COMMENT attribute enclosed by comment characters

 
set_attrs_value   - set a value of attributes

	the arguments are a pairs NAME => VALUE	
	the method return a self object


get_attrs_value  - return a list  of attributes values

	the arguments are a list of attributes name


shallow_clone  - return a shallow copy of the object	
	

=head1 EXPORT

None by default.


=head1 EXPORT_OK
	
none 

=head1 SEE ALSO

See blx:.xsdsql::generator for generate the schema of the database and blx::xsdsql::parser 
for parse a xsd file (schema file)


=head1 AUTHOR

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIG 

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut


