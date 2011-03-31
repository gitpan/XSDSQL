package blx::xsdsql::generator::sql::generic::handle::create_view;


use strict;
use warnings;
use Carp;
use base qw(blx::xsdsql::generator::sql::generic::handle);

sub _get_create_prefix {
	my ($self,%params)=@_;
	return "create or replace view";
}

sub get_binding_objects  {
	my ($self,$schema,%params)=@_;
	my $table=$schema->get_root_table;
	return wantarray ? ( $table ) : [ $table ];
}

sub _alias_table {
	my ($self,%params)=@_;
	return " as ";
}


{
	my $filter=undef;
	$filter=sub { #recursive function
		my ($col,$table,%params)=@_;
		my $newcol=$col->shallow_clone;  #clone the column for add ALIAS_NAME attr
=pod		
		my $path_ref=$newcol->get_path_reference;
		
		my $o=$params{SCHEMA}->resolve_table_from_path($path_ref);
			use Data::Dumper;
			print STDERR Dumper($o),"\n";
		}
=cut

		my $table_ref=$newcol->get_table_reference;
		if ($newcol->get_path_reference && !$table_ref) {  #confess the error 
			my $path_reference=$newcol->get_path_reference;
			if (ref($path_reference) =~/::table$/) {
				my $t=$path_reference;
				$path_reference=$t->get_attrs_value qw(PATH);
				$path_reference=$t->get_sql_name unless $path_reference;
			}
			confess $path_reference.": not a table ref\n";
		}
		my $viewable= $newcol->get_path_reference && $table_ref->get_max_occurs <= 1   || $newcol->is_pk && !$params{START_TABLE} ? 0 : 1;
		my $join_table=defined $table_ref && $table_ref->get_max_occurs <= 1 ? $table_ref->shallow_clone : undef; #clone the table for add ALIAS_NAME attr
		$newcol->set_attrs_value(
			VIEWABLE 		=> $viewable
			,TABLE			=> $table
		);
		if ($viewable) { #set the alias for view
			my $sql_name=delete $newcol->{SQL_NAME};
			my $alias_name=$newcol->get_sql_name(%params); #create a unique alias name
			$newcol->set_attrs_value(SQL_NAME	=> $sql_name,ALIAS_NAME	=> $alias_name);
		}		
		my @ret=($newcol);
		if (defined $join_table) {
			++${$params{ALIAS_COUNT}};
			$join_table->set_attrs_value(ALIAS_COUNT => ${$params{ALIAS_COUNT}});
			$newcol->set_attrs_value(JOIN_TABLE => $join_table);
			push @ret,map { $filter->($_,$join_table,%params,START_TABLE => 0) } $join_table->get_columns;
		}
		return @ret;
	};
	sub _get_columns {
		my ($self,$table,%params)=@_;
		my $t=$table->shallow_clone;
		my $alias_count=0;
		$t->set_attrs_value(ALIAS_COUNT => $alias_count);
		my $colname_list={};
		my @cols=map { $filter->($_,$t,COLUMNNAME_LIST => $colname_list,ALIAS_COUNT => \$alias_count,START_TABLE => 1,SCHEMA => $params{SCHEMA})} $t->get_columns;
		return @cols;
	}

}


sub table_header {
	my ($self,$table,%params)=@_;
	my $path=$table->get_attrs_value qw(PATH);
	my $comm=defined  $path ? $table->comment('PATH: '.$path) : '';
	$self->{STREAMER}->put_line($self->_get_create_prefix,' ',$table->get_view_sql_name," as select  $comm");
	my @cols=$self->_get_columns($table,%params);
	my $colseq=0;
	for my $col(@cols) {
		next unless $col->get_attrs_value qw(VIEWABLE);
		my $t=$col->get_attrs_value qw(TABLE);
		my $sqlcomm=sub {
			my $path=$col->get_attrs_value qw(PATH);
			my $comm=defined $path ? 'PATH: '.$path : '';
			my $ref=$col->get_attrs_value qw(PATH_REFERENCE);
			$comm.=defined $ref ? ' REF: '.$ref : '';
			$comm=~s/^(\s+|\s+)$//;
			return length($comm) ?  $col->comment($comm) : '';
		}->();
		my $table_alias=sprintf("A_%0".length(scalar(@cols))."d",$t->get_attrs_value(qw(ALIAS_COUNT)));
		my $column_alias=$col->get_attrs_value qw(ALIAS_NAME);
		$self->{STREAMER}->put_line("\t".($colseq == 0 ? '' : ',').$table_alias,'.',$col->get_sql_name,' as ',$column_alias,' ',$sqlcomm);
		++$colseq;
	}
	$self->{STREAMER}->put_line(' from ');
	for my $col(@cols) {
		my $t=$col->get_attrs_value qw(TABLE);
		my $alias=sprintf("A_%0".length(scalar(@cols))."d",$col->get_attrs_value(qw(TABLE))->get_attrs_value(qw(ALIAS_COUNT)));

		if ($t->get_sql_name eq $table->get_sql_name) { #the start table
			$self->{STREAMER}->put_line("\t",$t->get_sql_name,$self->_alias_table,$alias) if $col->is_pk && $col->get_pk_seq == 0;
		}
		my $table_ref=$col->get_attrs_value qw(JOIN_TABLE);
		next unless defined $table_ref;
		my $alias_ref=sprintf("A_%0".length(scalar(@cols))."d",$table_ref->get_attrs_value(qw(ALIAS_COUNT)));
		$self->{STREAMER}->put_chars("\t","left join ",$table_ref->get_sql_name,$self->_alias_table,$alias_ref,' on ');
		my @pk=$table_ref->get_pk_columns;
		$self->{STREAMER}->put_chars("\t",$alias,'.',$col->get_sql_name,'=',$alias_ref,'.',$pk[0]->get_sql_name);
		$self->{STREAMER}->put_chars("\t\tand ",$alias_ref,'.',$pk[1]->get_sql_name,'=0') if scalar(@pk) > 1;
		$self->{STREAMER}->put_line;
	}
	$self->{STREAMER}->put_line($table->command_terminator);
	return $self;
}

sub table_footer {
	my ($self,$table,%params)=@_;
	return $self;
}


1;


__END__

=head1 NAME

blx::xsdsql::generator::sql::generic::handle::create_view  - generic handle for create view


=head1 SYNOPSIS


use blx::xsdsql::generator::sql::generic::handle::create_view


=head1 DESCRIPTION

this package is a class - instance it with the method new

=cut


=head1 FUNCTIONS

see the methods of blx::xsdsql::generator::sql::generic::handle 

=head1 EXPORT

None by default.


=head1 EXPORT_OK

None

=head1 SEE ALSO


See  blx::xsdsql::generator::sql::generic::handle - this class inherit from this 


=head1 AUTHOR

lorenzo.bellotti, E<lt>pauseblx@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by lorenzo.bellotti

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
 

