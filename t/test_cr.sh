#!/bin/sh

##
#generate drop_tables,create tables and primary keys files for postgresql database
#use psql -f <filename> for generate the tables and add the primary keys if the database if postgresql (default) 
#

t=$(getopt -o 'd:n:' -- "$@" ) || exit 99
eval set -- "$t"
unset t
DIRS=$(echo xml_*)
NAMESPACE="sql::pg"

set -e 

while true
do
	case "$1" in 
		-d)
			shift
			DIRS="$1"
			;;
		-n)
			shift
			NAMESPACE="$1"
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


for op in drop_table create_table addpk 
do
	for xml in $DIRS
	do
		cd $xml || continue
		perl ../xsd2sql.pl -n "$NAMESPACE" -r "ROOT_$xml" "$op"  schema.xsd  > "$op.sql"
		cd - > /dev/null
	done
done

