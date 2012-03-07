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
use blx::xsdsql::ut qw(nvl);

use constant {
	DIR_PREFIX				=> 'xml_'
	,STRCONN_FILE			=> '.strconn'
	,APPLICATION			=> 'dbi'
	,STEP_FILE				=> '.step'
	,CUST_PARAMS_FILE		=> 'custom_params'
};

sub debug {
	my ($n,@l)=@_;
	$n='<undef>' unless defined $n; 
	print STDERR 'test (D ',$n,'): ',join(' ',grep(defined $_,@l)),"\n"; 
	return  undef;
}

sub xsd2sql { 
	my %params=@_;
	$params{DB_CONNECTION_STRING}=~/^(\w+):/;
	croak $params{DB_CONNECTION_STRING}.": internal error" unless defined $1;
	my ($typefile,$typedb)=('sql',$1);
	my %ret=(
		NAMESPACE 		=>  $typefile.'::'.$typedb
		,DB_TYPE		=>	$typedb
	); 
	my $pcmd="perl -MCarp=verbose ../xsd2sql.pl "
		.($params{DEBUG} ? " -d " : "") 
		." -n '".$ret{NAMESPACE}."'"
		." -p '".$params{PREFIX_TABLES}."'"
		." -w '".$params{PREFIX_VIEWS}."'"
		." -s '".$params{PREFIX_SEQUENCE}."'"
		.($params{EXTRA_PARAMS} ? " -o '".$params{EXTRA_PARAMS}."'" : "")
		."" 
		." '".$params{SCHEMA_FILE}."'";
	my @args=qw(drop_table create_table addpk drop_sequence create_sequence drop_view create_view drop_dictionary create_dictionary insert_dictionary);
	unless ($params{XSD2SQL_ONE_PASS}) {
		for my $c (@args) {
			$ret{$c}="${c}.sql";
			my $cmd=$pcmd." '${c}'  > ".$ret{$c};
			debug(__LINE__,$cmd) if $params{DEBUG};
			system($cmd);
			return (%ret,ERR_MSG => "$cmd: execution error") if $?;
		}				
	}
	else {
		my $rinchi="";
		my $cmd=$pcmd.' '.join(' ',map { "'".$_."'" } grep(/^drop/,@args)).' > all_drops'.$rinchi.'.sql';
		debug(__LINE__,$cmd) if $params{DEBUG};
		system($cmd);
		return (%ret,ERR_MSG => "$cmd: execution error") if $?;
		$cmd=$pcmd.' '.join(' ',map { "'".$_."'" } grep($_!~/^drop/,@args)).' > all_creates'.$rinchi.'.sql';
		debug(__LINE__,$cmd) if $params{DEBUG};
		system($cmd);
		return (%ret,ERR_MSG => "$cmd: execution error") if $?;

	}
	return %ret;
}

sub isql {
	my %params=@_;
	my $x=$params{DROP} ? ' -I -R ' : '';
	my $file=nvl($params{FILE});
	$file=~s/^\s*//;
	$file=~s/\s*$//;
	confess "internal error: param FILE not set" unless $file;
	my $cmd="perl ../isql.pl -c '".$params{DB_CONNECTION_STRING}."' -t c $x '$file'";
	debug(__LINE__,$cmd) if $params{DEBUG};
	system($cmd);
	my $rc=$?;
	return (ERR_MSG => "$cmd: execution error (rc==$rc)") if $rc == -1 || ($rc & 127);											
	$rc>>=8;
	return  $rc  == 0 || $rc == 1 && $params{DROP} 
		? () 
		: (ERR_MSG => "$cmd: execution error (rc==$rc)");
}

sub xml_load { #xml load & write & compare
	my %params=@_;
	my ($typedb,$conn)=$params{DB_CONNECTION_STRING}=~/^(\w+):(.*)$/;
	croak $params{DB_CONNECTION_STRING}.": internal error" unless defined $typedb;
	my $db_command="c";
	my $pcmd="perl -MCarp=verbose ../xml.pl -c '$conn' "
							." -p '".$params{PREFIX_TABLES}."' "
							." -w '".$params{PREFIX_VIEWS}."' "
							." -q '".$params{PREFIX_SEQUENCE}."' "
							." -n '$typedb' "
							." -t '".$params{TRANSACTION_MODE}."' "
							.($params{ROOT_TAG_PARAMS} ? " -x ".$params{ROOT_TAG_PARAMS} : "")
							.($params{DEBUG} ? " -d " : "")
							.($params{WRITER_UTF8} ? " -u " : "")
							.($params{EXECUTE_OBJECTS_PREFIX} ? " -b '".$params{EXECUTE_OBJECTS_PREFIX}."'" : '')
							.($params{EXECUTE_OBJECTS_SUFFIX} ? " -a '".$params{EXECUTE_OBJECTS_SUFFIX}."'" : '')
							.""
							." $db_command  '".$params{SCHEMA_FILE}."' "
							;
	my @files=();
	my $validator=$params{XML_VALIDATOR};
	$validator=~s/\%s/$params{SCHEMA_FILE}/g;
		
	my @onlyfiles=defined $params{ONLY_FILES} ? split(',',$params{ONLY_FILES}) : ();
	if (opendir(my $dd,".")) {
		while(my $f=readdir($dd)) {
			next if  $f=~/^\./;
			next unless $f=~/\.xml$/i;
			next unless -f $f;
			next unless -r $f;
			if (scalar(@onlyfiles)) {
				next unless grep($f eq $_,@onlyfiles);
			}
			push @files,$f
		}
		closedir($dd);
	}
	else {
		return (ERR_MSG => 'cannot open current directory: $!');
	}
	for my $f(sort @files) {
		my $cmd=$validator;
		$cmd=~s/\%f/$f/;
		debug(__LINE__,$cmd) if $params{DEBUG};
		system($cmd);
		if ($?) {
			return (ERR_MSG => "$f: is not a valid xml file") unless $params{EXCLUDE_NOT_VALID_XML_FILES};
			next;
		}
		my $tmp=$f.'.tmp';
		my $cmd=$pcmd."'$f' | ../tr.sh '$f' > '$tmp'";
		debug(__LINE__,$cmd) if $params{DEBUG};
		system($cmd);
		return (ERR_MSG => "$cmd: execution error") if $?;
		$cmd=$validator;
		$cmd=~s/\%f/$tmp/;
		debug(__LINE__,$cmd) if $params{DEBUG};
		system($cmd);
		return (ERR_MSG => "$tmp: is not a valid xml file") if $?;
		my $diff=$f.'.diff';
		my $xmldiff=0;
		if ($params{XMLDIFF}) {
			system("which xmldiff > /dev/null 2>&1");
			my $rc=$?;
			$xmldiff=1 if $rc == 0;
		}
		$cmd=$xmldiff ? "xmldiff -c '$f' '$tmp' > '$diff'" : "diff -E -b -a '$f' '$tmp' > '$diff'";
		debug(__LINE__,$cmd) if $params{DEBUG};
		system($cmd);
		my $rc=$?;
		return (ERR_MSG => "$cmd: execution error (rc==$rc)") if $rc == -1 || ($rc & 127);
		$rc>>=8;
		debug(__LINE__,' return code ',$rc) if $params{DEBUG};
		$rc=1 if $xmldiff && $rc > 1; 
		my $fd=xopen('<',$diff);
		while(<$fd>) { xprint(*STDOUT,$_); }
		close $fd;
		my $testrc=$params{OK_FOR_DIFF} ? 0 : 1;
		if ($rc == $testrc) {
			my $msg=$params{OK_FOR_DIFF} ? "the files equal" : "the files diff";
			return (ERR_MSG => $msg) unless $params{IGNORE_DIFF};
			print STDERR "(W) $msg\n"; 
		}
		elsif ($rc < 0 || $rc > 1) {
			return (ERR_MSG => "$cmd: execution error (rc==$rc)");# if $rc != 0;
		}
	}
	return ();
}

my @STEPS=(
	{	#0
		NAME => 'CREATE_SQL_FILES',SH_NAME => 'SQ',D => 'create sql files'
		,F => sub {  
			my %params=@_;
			my %ret=xsd2sql(%params);
			return %ret unless $params{XSD2SQL_ONE_PASS};
			return %ret if $ret{ERR_MSG};
			my $rinchi="";
			%ret=isql(%params,FILE => 'all_drops'.$rinchi.'.sql',DROP => 1);
			return %ret if scalar(keys %ret);
			return isql(%params,FILE => 'all_creates'.$rinchi.'.sql');
		}
	}
	,{	#1
		NAME => 'DROP_VIEW_OBJECTS',SH_NAME => 'DV',D => 'drop view objects',INCLUDE => [ 0 ]
		,F	=> sub {
				my %params=@_;
				return () if $params{XSD2SQL_ONE_PASS};
				return isql(%params,FILE => $params{drop_view},DROP => 1);				
		}
	}
	,{	#2
		NAME => 'DROP_TABLE_OBJECTS',SH_NAME => 'DT',D => 'drop table objects',INCLUDE => [ 1 ] 
		,F	=> sub {
				my %params=@_;
				return () if $params{XSD2SQL_ONE_PASS};
				return isql(%params,FILE => $params{drop_table},DROP => 1);				
		}		
	}
	,{	#3
		NAME => 'CREATE_TABLE_OBJECTS',SH_NAME => 'CT',D => 'create table objects',INCLUDE => [ 1,2 ]
		,F => sub {
				my %params=@_;
				return () if $params{XSD2SQL_ONE_PASS};
				my @errs=isql(%params,FILE => $params{create_table});
				return @errs if scalar(@errs);
				return isql(%params,FILE => $params{addpk});				
		}
	}
	,{	#4
		NAME => 'DROP_SEQUENCE_OBJECTS',SH_NAME => 'DS',D => 'drop sequence objects',INCLUDE => [ 0 ]
		,F	=> 	sub {
				my %params=@_;
				return () if $params{XSD2SQL_ONE_PASS};
				return isql(%params,FILE => $params{drop_sequence},DROP => 1);
		}
	}
	,{	#5
		NAME => 'CREATE_SEQUENCE_OBJECTS',SH_NAME => 'CS',D => 'create sequence objects',INCLUDE => [ 4 ]  
		,F	=> 	sub {
				my %params=@_;
				return () if $params{XSD2SQL_ONE_PASS};
				return isql(%params,FILE => $params{create_sequence});
		}
	
	}
	,{	#6
		NAME => 'CREATE_VIEW_OBJECTS',SH_NAME => 'CV',D => 'create view objects',INCLUDE => [ 3 ]  
		,F	=> 	sub {
				my %params=@_;
				return () if $params{XSD2SQL_ONE_PASS};
				return isql(%params,FILE => $params{create_view});
		}
	
	}
	,{	#7
		NAME => 'DROP_DICTIONARY_OBJECTS',SH_NAME => 'DD',D => 'drop dictionary objects',INCLUDE => [ 0 ]  
		,F	=> 	sub {
				my %params=@_;
				return () if $params{XSD2SQL_ONE_PASS};
				return isql(%params,FILE => $params{drop_dictionary},DROP => 1);
		}
	
	}
	,{	#8
		NAME => 'CREATE_DICTIONARY_OBJECTS',SH_NAME => 'CD',D => 'create dictionary objects',INCLUDE => [ 7 ]  
		,F	=> 	sub {
				my %params=@_;
				return () if $params{XSD2SQL_ONE_PASS};
				return isql(%params,FILE => $params{create_dictionary});
		}
	
	}
	,{	#9
		NAME => 'INSERT_DICTIONARY_OBJECTS',SH_NAME => 'ID',D => 'insert dictionary objects',INCLUDE => [ 8 ]  
		,F	=> 	sub {
				my %params=@_;
				return () if $params{XSD2SQL_ONE_PASS};
				return isql(%params,FILE => $params{insert_dictionary});
		}
	
	}
	,{ #10
		NAME => 'LOAD_UNLOAD_COMPARE',SH_NAME => 'L',D => 'load & unload & compare ',INCLUDE => [ 3,5 ]
		,F => sub { return xml_load(@_); }
	}
);	
	
my %OPERATIONS=map {
		my $p=$STEPS[$_];
		($p->{NAME},$_,$p->{SH_NAME},$_);
} (0..scalar(@STEPS) - 1);


sub get_operations {
	my %index=map { ($_,undef)  } @_;
	for my $i(@_) {
		my $p=$STEPS[$i];
		if ($p->{INCLUDE}) {
			my @i=get_operations(@{$p->{INCLUDE}});
			for (@i) { $index{$_}=undef};
		}
	}
	return sort keys %index;
}

my %Opt=();
unless (getopts ('hdrRcCTeiuo:f:t:b:a:p:v:XSx:K',\%Opt)) {
	 print STDERR "invalid option or option not set\n";
	 exit 1;
}

if ($Opt{h}) {
	print STDOUT "
$0  [<options>] [<args>].. 
    exec battery test 
<options>: 
    -h  - this help
    -d  - debug mode
    -r  - reset steps and execute the tests
    -R  - reset steps and not execute the tests
    -c  - reset connection string and execute the tests
    -C  - reset connection string and not execute the tests
    -T  - clean temporary files in test + step file  and not execute the test
    -e  - exclude not valid xml files
    -i  - continue after xml difference
    -u  - set encondig utf8 to xmlwriter
    -f   <filename>[,<filename>...] - include in test only file match <filename>
    -t  <c|r> - transaction database mode ((c)ommit or (r)ollback) - default r
    -b  - set the execute prefix for db objects (Ex.   'scott.' in oracle)
    -a  - set the execute suffix for db objects (Ex: '\@dblink' in oracle)
    -v  <command> - use <command> for xml validation
            use \%f for xml file tag and \%s for schema (xsd) file tag
            the default is 'xmllint -schema \%s \%f'
    -X  - do not use xmldiff for difference - use the normal diff command
    -S  - do not execute xsd2sql in one pass 
    -x  - force the root_tag params in form name=value,... for xml.pl
    -K  - ok for difference
    -p <name>=<value>[,<name>=<value>...]
        set extra params for xsd2sql.pl - valid names are:
                MAX_VIEW_COLUMNS     =>  produce view code only for views with columns number <= MAX_VIEW_COLUMNS - 
                    -1 is a system limit (database depend)
                    false is no limit (the default)
                MAX_VIEW_JOINS         =>  produce view code only for views with join number <= MAX_VIEW_JOINS - 
                    -1 is a system limit (database depend)
                    false is no limit (the default)
    -o  - execute only the target operation
        <op> must be ".join("|",map { ($_->{NAME},$_->{SH_NAME}) } @STEPS)." 
arguments>:
    <testnumber>|<testnumber>-<testnumber>...
    if <testnumber> is not spec all tests can be executed

"; 
    exit 0;
}


$Opt{t}='r' unless $Opt{t};
unless ($Opt{t}=~/^(c|r)$/) {
	print STDERR $Opt{t},": bad value for option t\n";
	exit 1;
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
		xprint($fd,$k,' ',$params{$k},"\n") if defined $params{$k} && ref($params{$k}) eq '';
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
				if ($f=~/\.(diff|tmp|sql)$/i || $f eq STEP_FILE) {
					debug(__LINE__,"remove file $f") if $not_store_params->{DEBUG};
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
	my @operations=split(',',nvl($p{OPERATIONS},''));
	for my $i(0..scalar(@operations) - 1) {
		my $step=$operations[$i];
		if ($step < $params{LAST_STEP}) {
			print STDERR " bypassed step $step\n";
			next;
		}
		my $sub=$STEPS[$step]->{F};
		croak "internal error" unless ref($sub) eq 'CODE';
		print STDERR $STEPS[$step]->{D},' ... ';
		my %ret=$sub->(%params,%$not_store_params,CURRENT_STEP => $step);
		if ($ret{WARN_MSG}) {
			print STDERR "(W) ",$ret{WARN_MSG},"\n";
		}
		if ($ret{ERR_MSG}) {
			print STDERR "test failed: ",$ret{ERR_MSG},"\n";
			store_step(%params,LAST_STEP => $step) if $step > $params{LAST_STEP};
			exit 1;
		}
		for my $k (keys %ret) {
			next if $k eq 'ERR_MSG';
			next if $k eq 'WARN_MSG';
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

sub get_message {
	my @f=();
	if (open(my $fd,'<message.txt')) {
		@f=<$fd>;		
		close $fd;
	} 
	else {
		my $name=readlink 'schema.xsd';
		if ($name) {
			$name=~s/_/ /g;
			$name=~s/\.xsd$//i;
			push @f,$name."\n";	
		}
	}
	push @f,"\n"  unless scalar(@f);
	return wantarray ? @f : \@f;
}

### main ####

my @onlytests=sub {
	my @ot=();
	for my $a(@_) {
		if ($a=~/^\d+$/) {
			push @ot,$a;
		}
		elsif ($a=~/^(\d+)-(\d+)$/) {
			push @ot,($1..$2);
		}
		else {
			print STDERR "(W) $a: invalid test number - ignored\n";
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
				next unless -r $d.'/schema.xsd';
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

my @operations=sub {
	return  (0..scalar(@STEPS) - 1) unless scalar(@_);
	my @op=();
	for my $d(@_) {
		my $index=$OPERATIONS{uc($d)};
		unless (defined $index) {
			print STDERR "$d: operation unknow\n";
			return ();
		}
		push @op,$index;
	}
	return get_operations(@op);
}->(defined $Opt{o} ? split(',',$Opt{o}) : ());
exit 1 unless scalar(@operations);

my $only_files=sub {
	return join(',',map {  my $f=$_; $f.='.xml' unless $f=~/\.xml$/i; $f; } @_);
}->(defined $Opt{f} ? split(',',$Opt{f}) : ());

$Opt{v}='xmllint --schema \'%s\' --noout \'%f\'' unless defined $Opt{v};

my %not_store_params=(
						DEBUG 							=> $Opt{d}
						,RESET							=> $Opt{r} || $Opt{R}
						,CLEAN							=> $Opt{T}
						,NOT_EXECUTE					=> $Opt{NOT_EXECUTE}
						,EXCLUDE_NOT_VALID_XML_FILES 	=> $Opt{e}
						,IGNORE_DIFF 					=> $Opt{i}
						,WRITER_UTF8					=> $Opt{u}
						,TRANSACTION_MODE				=> $Opt{t} 
						,EXECUTE_OBJECTS_PREFIX			=> $Opt{b}
						,EXECUTE_OBJECTS_SUFFIX 		=> $Opt{a}
						,ONLY_FILES						=> $only_files
						,EXTRA_PARAMS					=> $Opt{p}
						,XML_VALIDATOR  				=> $Opt{v}
						,XMLDIFF						=> $Opt{X} ? 0 : 1
						,XSD2SQL_ONE_PASS				=> $Opt{S} ? 0 : 1
						,OK_FOR_DIFF					=> $Opt{K}
);
	
for my $n(@testdirs) { 
	my $testdir=DIR_PREFIX.$n;
	print STDERR "test number $n - ";
	unless (chdir $testdir) {
		print STDERR "(W) $testdir: $!\n";
		next;
	}

	print STDERR get_message;
	my %test_params=(
		SCHEMA_FILE					=> 'schema.xsd'
		,TEST_NUMBER 				=> $n
		,DB_CONNECTION_STRING 		=> $strconn[0]
		,PREFIX_VIEWS 				=> 'V'.$n.'_'
		,PREFIX_TABLES 				=> 'T'.$n.'_'
		,PREFIX_SEQUENCE			=> 'S'.$n.'_'
		,NOT_STORE_PARAMS			=> { %not_store_params }
		,OPERATIONS					=> join(',',@operations)
		,ROOT_TAG_PARAMS			=> $Opt{x}
	);

	if (-r CUST_PARAMS_FILE) {
		if (open(my $fd,'<',CUST_PARAMS_FILE)) {
			while(<$fd>) {
				next if /^\s*#/;
				next if /^\s*$/;
				if (/^\s*(\w+)\s+(.*)$/) {
					my $fl=1;
					my ($k,$v)=($1,$2);
					if (grep($_ eq $k,keys %test_params)) {
						if ($k eq 'NOT_STORE_PARAMS') {
							$fl=0;
						}
						else {
							$test_params{$k}=$v;
						}
					}
					elsif (grep($_ eq $k,keys %not_store_params)) { 
						$test_params{NOT_STORE_PARAMS}->{$k}=$v;
					}
					else {
						$fl=0;
					}
					print STDERR CUST_PARAMS_FILE,": (W) unknow  key $k in line $NR\n" unless $fl;
				}
				else {
					print STDERR CUST_PARAMS_FILE,": (W) wrong  line $NR\n";
				}
			}
			close $fd;
		}
		else {
			print STDERR CUST_PARAMS_FILE,": (W) $!\n";
		}
	}
	
	do_test(%test_params);

	unless (chdir $startdir) {
		print STDERR "(W) $startdir: $!\n";
		exit 1
	}
}

exit 0;
