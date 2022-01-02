#!/bin/sh

FUN_DIR=${FUN_DIR:-./functions}
. $FUN_DIR/common.sh

USAGE(){
	echo "Usage: $1 [params]"
	echo "     -D: debug"
	echo "     -v: more verbose output"
	echo "     -f SRC_FILE: resources file"
	exit 1
}

#Functions
############################
#Chekc params
[ $# = 0 ] && USAGE $0

while getopts ":f:vD" opt; do
	case $opt in
		f)
			SRC=$OPTARG
		;;
		v)
			verbose
			shift 1
		;;
		D)
			DEBUG=1
			LOG_LEVEL=100
		;;
		*)
			USAGE $0
		;;
	esac
done

#Check varables
check_variables SRC || ERR "Not all key varables defined"
check_files $SRC || ERR "Can not find src file: $SRC"

LOG "Try get resource from $URL, with key \"$KEY\" and tag \"$TAG\""

