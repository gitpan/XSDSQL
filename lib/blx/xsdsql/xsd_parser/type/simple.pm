package blx::xsdsql::xsd_parser::type::simple;
use strict;
use warnings FATAL => 'all';
use integer;
use Carp;
use blx::xsdsql::ut(qw(nvl));

use base(qw(blx::xsdsql::xsd_parser::type));


sub _new {
	my ($class,%params)=@_;
	for my $k(keys %params) { delete $params{$k} if $k ne 'SQL_T_' && $k=~/^SQL_/; } 
	my $self=bless \%params,$class;
	return $self;
}


sub get_sql_type  {
	my ($self,%params)=@_;
	return $self->{SQL_T_} if defined $self->{SQL_T_};
	if (defined  (my $name=$self->{NAME})) {
		my $r=ref($name);
		if ($r eq '') {
			$self->{SQL_T_}={ SQL_TYPE  => $name  } ;
		}
		elsif ($r eq 'HASH') {
			my $base=$name->{base};
			confess "base not set\n" unless defined $base;
			if (grep($base eq $_,qw(string normalizedString token base64Binary hexBinary))) {
				if (defined (my $l=$name->{length})) { 
					$self->{SQL_T_}={ SQL_TYPE  => 'char',SQL_SIZE => $l  };
				}					
				elsif (defined (my $l1=$name->{maxLength})) {
					$self->{SQL_T_}={ SQL_TYPE  => $base,SQL_SIZE => $l1  };
				}
				else {
					$self->{SQL_T_}={ SQL_TYPE  => $base };
				}
				if (defined (my $e=$name->{enumeration})) {
					confess "internal error\n" unless ref($e) eq 'ARRAY';
					my $l=nvl($self->{SQL_T_}->{SQL_SIZE},0);
					for my $v(@$e) {
						my $lv=length($v);
						$l=$lv if $lv > $l;
					}
					$self->{SQL_T_}->{SQL_SIZE}=$l;
				}
			}
			elsif (grep($base eq $_,qw(   decimal  integer  int  nonPositiveInteger  nonNegativeInteger  negativeInteger  long  short  byte  unsignedLong  unsignedInt  unsignedShort  unsignedByte  positiveInteger		   ))) {
				if (defined (my $l=$name->{totalDigits})) { 
					$self->{SQL_T_}={ SQL_TYPE  => $base,SQL_SIZE => $l };
				}					
				else {
					$self->{SQL_T_}={ SQL_TYPE  => $base };
				}
			}
			else {
				$self->_debug(__LINE__,"(W)  $base - type not manip");
				$self->{SQL_T_}={ SQL_TYPE  => $base };
			}
		}
		else {
			confess ref($r).": internal error\n";
		}
	}
	else {
		$self->_debug(__LINE__,keys %params);
		confess "internal error - attribute NAME not set\n".join(' ',keys %{$self})."\n";
	}

	return $self->{SQL_T_};
}

sub resolve_type {  return $_[0]; }

sub link_to_column {
	my ($self,$c,%params)=@_;
	if ($c->get_max_occurs > 1) {
		return $self if defined $c->get_table_reference;
		my $parent_table=$params{TABLE};
		my $schema=$params{SCHEMA};
		my $table = $schema->get_attrs_value(qw(TABLE_CLASS))->new(
			PATH		    	=> $c->get_path
			,INTERNAL_REFERENCE => 1
		);
		$schema->set_table_names($table);
		my $value_col=$schema->get_attrs_value(qw(ANONYMOUS_COLUMN))->_factory_column(qw(VALUE));
		$value_col->set_attrs_value(TYPE => $self,PATH => $c->get_path);

		$table->_add_columns(
			$schema->get_attrs_value(qw(ANONYMOUS_COLUMN))->_factory_column(qw(ID))
			,$schema->get_attrs_value(qw(ANONYMOUS_COLUMN))->_factory_column(qw(SEQ))
			,$schema->get_attrs_value(qw(ANONYMOUS_COLUMN))->_factory_column(qw(VALUE))->set_attrs_value(TYPE => $self,PATH => $c->get_path)
		);
		$c->set_attrs_value(
			PATH_REFERENCE 			=> $table->get_path
			,INTERNAL_REFERENCE 	=> 1
			,TYPE 					=> $schema->get_attrs_value(qw(ID_SQL_TYPE))
			,TABLE_REFERENCE 		=> $table
		);
		$parent_table->_add_child_tables($table);
	}
	else {
		$c->set_attrs_value(TYPE => $self);
	}
	return $self;
}	

1;


__END__


=head1  NAME

blx::xsdsql::xsd_parser::type::simple - internal class for parsing schema 

=cut
