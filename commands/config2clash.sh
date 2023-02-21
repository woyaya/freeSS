#!/bin/bash

DEFAULT_FILE=/var/www/html/share/clash_proxy.conf

EXEC=`basename $0`
FUN_DIR=${FUN_DIR:-./functions}
CFG_DIR=${CFG_DIR:-./configs}
CMD_DIR=${CMD_DIR:-./commands}
PROTO_DIR=${PROTO_DIR:-./protocols}
. $FUN_DIR/common.sh

USAGE(){
	echo "Usage: $1 [params]"
	echo "     -D: debug"
	echo "     -v: more verbose output"
	echo "     -f SRC_FILE: resources file"
	echo "     -d DST_FILE: dist clash config file"
	exit 1
}
cleanup() {
	[ -f "$TMP" ] && {
		LOG "Cleanup $TMP"
		[ -f $TMP ] && rm  -rf $TMP
	}
}

#Functions
############################
#Chekc params
[ $# = 0 ] && USAGE $0

while getopts ":f:d:vD" opt; do
	case $opt in
		f)
			SRC=$OPTARG
		;;
		d)
			DST=$OPTARG
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

[ -z "$DST" ] && DST=${DEFAULT_FILE}
#Check varables
check_variables SRC || ERR "Not all key varables defined"
check_files $SRC || ERR "Can not find all needed files"
TMP=$DST.tmp
mkdir -p `dirname $TMP`
rm -rf $TMP
trap cleanup EXIT

INDEX=1
LOG "Read config from $SRC and convert to clash"
while read resource;do
	PREFIX=`get_prefix "$resource"`
	[ ! -f "$PROTO_DIR/decode-$PREFIX" ] && ERR "Unsupport protocal: $resource"

	. $PROTO_DIR/decode-$PREFIX

	LOG "Try to parse resource: \"$resource\""
	CONTENT=`drop_prefix $resource`
	[ -z "$CONTENT" ] && cleanup "Invalid resource: $resource"
	DBG "Context: $CONTENT"
	JSON=`resource_decode "$CONTENT"` || ERR "Decode resource fail: $resource"
	resource="${PREFIX}://$JSON"
	LOG "Decode result: $JSON"
	resource_parse "$JSON" || ERR "Parse resource fail: $JSON"
	DBG "Parse succ: $JSON"
	clash=`config4clash $INDEX`
	echo "$clash" >>$TMP
	INDEX=$((INDEX+1))
done <$SRC
LOG "Check file size"
[ ! -s $TMP ] && ERR "No resource found"
mv $TMP  $DST

echo "Config for clash ready: $DST"
