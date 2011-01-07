eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
use strict;
use warnings qw(FATAL);
use integer;
use English '-no_match_vars';
use Carp;
use Getopt::Std;
use File::Spec;
use Data::Dumper;
use DBI;

use blx::xsdsql::dbconn;

use constant {
	DIR_PREFIX		=> 'xml_'
	,STRCONN_FILE	=> '.strconn'
	,APPLICATION	=> 'dbi'
	,STEP_FILE		=> '.step'
};

my @STEPS_DESCRIPTION=(
	"create sql files ..."
	,"drop view objects ..."
	,"drop table objects ..."
	,"create table objects ..."
	,"create table constraints  ..."
	,"drop sequence objects ..."
	,"create sequence objects ..."
	,"load & unload & compare  ..."
	,"create view objects ..."
	,"test  OK"
);

sub isql {
	my %params=@_;
	my $x=$params{DROP} ? ' -I -R ' : '';
	my $cmd="perl ../isql.pl -c '".$params{DB_CONNECTION_STRING}."' -t c $x ".$params{FILE};
	print STDERR "(D) ",$cmd,"\n" if $params{DEBUG};
	system($cmd);
	my $rc=$?;
	return (ERR_MSG => "$cmd: execution error") if $rc == -1 || ($rc & 127);											
	$rc>>=8;
	return  $rc  == 0 || $rc == 1 && $params{DROP} 
		? () 
		: (ERR_MSG => "$cmd: execution error");
}

my @STEPS=(
			sub {  #xsd2sql
				my %params=@_;
				$params{DB_CONNECTION_STRING}=~/^(\w+):/;
				croak $params{DB_CONNECTION_STRING}.": internal error" unless defined $1;
				my ($typefile,$typedb)=('sql',$1);
				my %ret=(
					NAMESPACE 		=>  $typefile.'::'.$typedb
					,DB_TYPE		=>	$typedb
				); 
				my $pcmd="perl ../xsd2sql.pl "
					." -n '".$ret{NAMESPACE}."'"
					." -p '".$params{PREFIX_TABLES}."'"
					." -w '".$params{PREFIX_VIEWS}."'"
					." -s '".$params{PREFIX_SEQUENCE}."'"; 
				for my $c qw(drop_table create_table addpk drop_sequence create_sequence drop_view create_view) {
					$ret{$c}="${c}.sql";
					my $cmd=$pcmd." '${c}' '".$params{SCHEMA_FILE}."' > ".$ret{$c};
					print STDERR "(D) ",$cmd,"\n" if $params{DEBUG};
					system($cmd);
					return (%ret,ERR_MSG => "$cmd: execution error") if $?;
				}				
				return %ret;
			}
			,sub { #drop views
				my %params=@_;
				return isql(%params,FILE => $params{drop_view},DROP => 1);				
			}
			,sub { #drop tables
				my %params=@_;
				return isql(%params,FILE => $params{drop_table},DROP => 1);
			}
			,sub { #create tables
				my %params=@_;
				return isql(%params,FILE => $params{create_table});
			}
			,sub { #create constraints
				my %params=@_;
				return isql(%params,FILE => $params{addpk});
			}
			,sub { #drop sequence
				my %params=@_;
				return isql(%params,FILE => $params{drop_sequence},DROP => 1);
			}
			,sub { #create sequence
				my %params=@_;
				return isql(%params,FILE => $params{create_sequence});
			}
			,sub { #xml load & write & compare
				my %params=@_;
				my ($typedb,$conn)=$params{DB_CONNECTION_STRING}=~/^(\w+):(.*)$/;
				croak $params{DB_CONNECTION_STRING}.": internal error" unless defined $typedb;
				my $pcmd="perl ../xml.pl -c '$conn' "
										." -p '".$params{PREFIX_TABLES}."' "
										." -w '".$params{PREFIX_VIEWS}."' "
										." -q '".$params{PREFIX_SEQUENCE}."' "
										." -n '$typedb' "
										." -t r "
										." c  '".$params{SCHEMA_FILE}."' "
										;
				my @files=();
				my $validator="xmllint --schema '".$params{SCHEMA_FILE}."' --noout '\%f'";
				if (opendir(my $dd,".")) {
					while(my $f=readdir($dd)) {
						next unless $f=~/\.xml$/;
						next unless -r $f;
						next unless -f $f;
						next if  $f=~/^\./;
						my $cmd=$validator;
						$cmd=~s/\%f/$f/;
						print STDERR "(D) ",$cmd,"\n" if $params{DEBUG};
						system($cmd);
						if ($?) {
							print STDERR "$f: is not a valid xml file\n";
							next;
						}
						push @files,$f;
					}
					closedir($dd);
				}
				else {
					return (ERR_MSG => 'cannot open current directory: $!');
				}
				for my $f(sort @files) {
					my $tmp=$f.'.tmp';
					my $cmd=$pcmd."'$f' > '$tmp'";
					print STDERR "(D) ",$cmd,"\n" if $params{DEBUG};
					system($cmd);
					return (ERR_MSG => "$cmd: execution error") if $?;
					$cmd=$validator;
					$cmd=~s/\%f/$tmp/;
					print STDERR "(D) ",$cmd,"\n" if $params{DEBUG};
					system($cmd);
					return (ERR_MSG => "$f: is not a valid xml file") if $?;
					my $diff=$f.'.diff';
					$cmd="diff -E -b -a '$f' '$tmp' > '$diff'";
					print STDERR "(D) ",$cmd,"\n" if $params{DEBUG};
					system($cmd);
					my $rc=$?;
					return (ERR_MSG => "$cmd: execution error") if $rc == -1 || ($rc & 127);											
					my $fd=xopen('<',$diff);
					while(<$fd>) { xprint(*STDOUT,$_); }
					close $fd;
					$rc>>=8;
					return (ERR_MSG => "the files diff") if $rc == 1;
					return (ERR_MSG => "$cmd: execution error") if $rc != 0;
				}
				return ();
			}
			,sub { #create views
				my %params=@_;
				return isql(%params,FILE => $params{create_view});							
			}
			,sub { #final step
				my %params=@_;
				return ();							
			}	
);

my %Opt=();
unless (getopts ('hdrRcCT',\%Opt)) {
	 print STDERR "invalid option or option not set\n";
	 exit 1;
}

if ($Opt{h}) {
	print STDOUT "
		$0  [-hdrRcCT] [<testnumber>...]
			exec battery test - if <testnumber> is not spec all tests must be executed
		<options>: 
			-h  - this help
			-d  - debug mode
			-r  - reset steps and execute the tests
			-R  - reset steps and not execute the tests
			-c  - reset connection string and execute the tests
			-C  - reset connection string and not execute the tests
			-T  - clean temporary files in test + step file  and not execute the test
	"; 
    exit 0;
}

sub xopen {
	my ($opentype,$filename)=@_;
	if (open(my $fd,$opentype,$filename)) {
		return $fd;
	}
	print STDERR $opentype,$filename,": $!\n";
	exit 1;				
}

sub xclose {
	unless(close $_[0]) {
		print STDERR "close: $!\n";
		exit 1;			
	}
	return 1;
}

sub xprint {
	my $fd=shift;
	unless (print $fd @_) {
		print STDERR "print: $!\n";
		close $fd;
		exit 1;
	}
	return 1;
}

sub store_step {
	my %params=@_;
	my $fd=xopen('>',STEP_FILE);
	for my $k(keys %params) {
		xprint($fd,$k,' ',$params{$k},"\n") if defined $params{$k};
	}
	xclose($fd);
	return 1;		
}

sub get_last_step {
	unless (-e STEP_FILE) {
		my %params=@_;
		$params{LAST_STEP}=0;
		store_step(%params);
	}
	my %params=();
	my $fd=xopen('<',STEP_FILE);
	while(<$fd>) {
		chop;
		/^(\w+)\s+(.*)$/;
		$params{$1}=$2;
	}
	xclose $fd;		
	return %params;
}

sub do_test {
	my %p=@_;
	my $not_store_params=delete $p{NOT_STORE_PARAMS};
	if ($not_store_params->{CLEAN}) {
		if (opendir(my $d,'.')) {
			while(my $f=readdir($d)) {
				next if -d $f;
				if ($f=~/\.(diff|tmp|sql)$/ || $f eq STEP_FILE) {
					print STDERR "remove file $f\n" if $not_store_params->{DEBUG};
					unless (unlink $f) {
						print STDERR "$f: cannot remove: $!\n";
					}
				}
			}
			closedir($d);
		}
		else {
			print STDERR "test failed: cannot open current directory: $! \n";
			exit 1;	
		}
	}	
	unlink(STEP_FILE) if $not_store_params->{RESET};
	return 1 if $not_store_params->{NOT_EXECUTE};
	my %params=get_last_step(%p);
	for my $step(0..scalar(@STEPS) - 1) {
		if ($step < $params{LAST_STEP}) {
			print STDERR " bypassed step $step\n";
			next;
		}
		my $sub=$STEPS[$step];
		croak "internal error" unless ref($sub) eq 'CODE';
		print STDERR $STEPS_DESCRIPTION[$step];
		my %ret=$sub->(%params,%$not_store_params,CURRENT_STEP => $step);
		if ($ret{ERR_MSG}) {
			print STDERR "test failed: ",$ret{ERR_MSG},"\n";
			store_step(%params,LAST_STEP => $step) if $step > $params{LAST_STEP};
			exit 1;
		}
		for my $k (keys %ret) {
			next if $k eq 'ERR_MSG';
			next if $k eq 'CURRENT_STEP';
			$params{$k}=$ret{$k};
		}
		print STDERR " passed\n";
	}
	my $step=scalar(@STEPS);
	store_step(%params,LAST_STEP => $step) if $step > $params{LAST_STEP};
	return 1;
}

sub test_db_connection {
	my $strconn=shift;
	my $conn=eval {  DBI->connect(@_) };
	if ($@ || !defined $conn) {
		print STDERR $@;
		print STDERR "$strconn: wrong connect string\n";
		return 0;
	}
	$conn->disconnect;
	return 1;
}

### main ####

my @onlytests=sub {
	my @ot=();
	for my $a(@_) {
		unless ($a=~/^\d+$/) {
			print STDERR "(W) $a: invalid test number - ignored\n";
		}
		else {
			push @ot,$a;
		}
	}
	return @ot;
}->(@ARGV);
			

my @testdirs=grep (defined $_,map  {  
		my $testnumber=$_;
		if (scalar(@ARGV)) {
			$testnumber=undef unless grep($_ == $testnumber,@onlytests);
		}
		$testnumber;
	}  sub {
		my ($dp,$dir)=@_;
		my @testdirs=();
		if  (opendir(my $fd,$dir)) {
			while(my $d=readdir($fd)) {
				next unless $d=~/^$dp(\d+)$/;
				next unless -d $d;
				push @testdirs,$1;
			}
			closedir($fd);
		}
		else {
			my $absdir=File::Spec->rel2abs($dir);
			print STDERR $absdir,": $!\n";
			exit 1;
		}
		return sort @testdirs;
	}->(DIR_PREFIX,File::Spec->curdir)
);

unless (scalar(@testdirs)) {
	print STDERR "(W) no test required\n";
	exit 0;
}

$Opt{NOT_EXECUTE}=1 if $Opt{C} || $Opt{R} || $Opt{T};

my @strconn=sub {
	my $connstr=$ENV{DB_CONNECT_STRING};
	return ($connstr)  if $connstr;
	unlink(STRCONN_FILE) if $Opt{c} || $Opt{C};
	return () if $Opt{NOT_EXECUTED};
	my $dbconn=blx::xsdsql::dbconn->new;
	while (! -e STRCONN_FILE) {
		my @db_aval=blx::xsdsql::dbconn::get_database_availables();
		print STDERR "database availables: ",join(' ',@db_aval),"\n";
		print STDERR "enter database connect string in form dbtype:<user>/<password>\@<dbname>[:<host>[:<port>]]\n";
		my $connstr=<STDIN>;
		chomp $connstr;
		next unless $connstr;
		my @a=$dbconn->get_application_string($connstr,APPLICATION => APPLICATION);
		@a=() unless test_db_connection($connstr,@a); #if failure connection print errmsg
		if (scalar(@a)) {
			if (open(my $fd,'>',STRCONN_FILE)) {
				unshift @a,$connstr;
				for my $a(@a) {				
					unless (print $fd $a,"\n") {
						print STDERR STRCONN_FILE,": $!\n";
						close $fd;
						unlink STRCONN_FILE;
						exit 1;
					}
				}
				unless (close $fd) {
					print STDERR STRCONN_FILE,": $!\n";
					unlink STRCONN_FILE;
					exit 1;
				}
			}
			else {
				print STDERR STRCONN_FILE,": $!\n";
				exit 1;				
			}
		}
		else {
			print STDERR "$connstr: invalid connection  string\n";
			print STDERR "the connection string must be in the form dbtype:<user>/<password>\@<dbname>[:<host>[:<port>]]\n";
		}	
	}
	if (open(my $fd,'<',STRCONN_FILE)) {
		my @l=map { chop($_); $_; } <$fd>;
		close $fd; 
		return @l;
	}
	else {
		print STDERR STRCONN_FILE,": $!\n";
		exit 1;				
	}
	croak "internal error";
}->();

unless ($Opt{NOT_EXECUTE}) {
	test_db_connection(@strconn)  || exit 1;
}

my $startdir=File::Spec->rel2abs(File::Spec->curdir);

for my $n(@testdirs) { 
	my $testdir=DIR_PREFIX.$n;
	print STDERR "test number $n\n";
	unless (chdir $testdir) {
		print STDERR "(W) $testdir: $!\n";
		next;
	}
	do_test(
		SCHEMA_FILE					=> 'schema.xsd'
		,TEST_NUMBER 				=> $n
		,DB_CONNECTION_STRING 		=> $strconn[0]
		,PREFIX_VIEWS 				=> 'V'.$n.'_'
		,PREFIX_TABLES 				=> 'T'.$n.'_'
		,PREFIX_SEQUENCE			=> 'S'.$n.'_'
		,NOT_STORE_PARAMS			=> {
											DEBUG 	=> $Opt{d}
											,RESET	=> $Opt{r} || $Opt{R}
											,CLEAN	=> $Opt{T}
											,NOT_EXECUTE	=> $Opt{NOT_EXECUTE} 
										}
	);
	unless (chdir $startdir) {
		print STDERR "(W) $startdir: $!\n";
		exit 1
	}
}

exit 0;
