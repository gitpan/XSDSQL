#!/bin/sh

#
#  read the xmlfiles, write and compare
#


t=$(getopt -o 'd:' -- "$@" ) || exit 99
eval set -- "$t"
unset t
DIRS=$(echo xml_*)
DB_CONNECT_STRING="" #specify the connect string to the db
DB_USER="" #specify the user for the db connection
DB_PWD="" #specificy the pwd for the db connection

SCHEMA="schema.xsd"
XMLLINT="$(which xmllint)" || { echo "xmllint not found - please install the package libxml2-utils"> 2; exit 1; }
DIFF="$(which diff)" || { echo "diff not found - plase install the package diffutils">&2; exit 1;}

set -e 

while true
do
	case "$1" in 
		-d)
			shift
			DIRS="$1"
			;;
		--)
			shift
			break;
			;;
		*)
			echo "$1: internal error">&2
			exit 99
	esac
	shift
done




#test for compare with delete

perl ./xml.pl -c "$DB_CONNECT_STRING" -U "$DB_USER" -P "$DB_PWD" C || { echo "error to connect to the database" >&2; exit 1; }

for d in $DIRS
do 
	cd $d || continue
	[ -r "$SCHEMA" ] || { echo "$SCHEMA: file is not readable">&2; exit 1;}
	for xml in *.xml 
	do
		[ -r "$xml" ] || { echo "$xml: file is not readable" >&2; exit 1;}
		$XMLLINT --schema "$SCHEMA" --noout "$xml"
		perl ../xml.pl -c "$DB_CONNECT_STRING" -U "$DB_USER" -P "$DB_PWD" -t r  -r "ROOT_$d" cd   "$SCHEMA" "$xml" > /tmp/$$.xml
		$XMLLINT --schema "$SCHEMA" --noout /tmp/$$.xml
		$DIFF -E -b -a "$xml" /tmp/$$.xml || { echo "$xml: not read/write corretted into/from the database">&2; exit 1; }
	done
	cd - > /dev/null
done
exit 0
