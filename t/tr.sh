#!/bin/sh
# substitute the stdin 1^ line with the 1^ line of orig_file
export orig_file="$1"
perl -Mstrict -Mwarnings -e '
	open(my $fd,"<",$ENV{orig_file}) || exit 1;
	my $l=<$fd>;
	close $fd;
	exit 1 unless defined $l; 
	my $c=0;
	while(<STDIN>) {
		print STDOUT ($c++ == 0 ? $l : $_);
	}  
	exit 0;
'


