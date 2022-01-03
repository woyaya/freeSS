#!/bin/bash

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
#Prepare default params
LISTEN_IP=${LISTEN_IP:-127.0.0.1}

#Check varables
check_variables SRC || ERR "Not all key varables defined"
check_files $SRC $CMD_DIR/ProcResource.sh || ERR "Can not find all needed files"

LOG "Get server count and port list from haproxy config file"
set +H
PORT_LIST=`cat /etc/haproxy/haproxy.cfg | sed "s/^[ \t]*//g;/$LISTEN_IP/!d;s/.*$LISTEN_IP://;s/ .*//"`
[ -z "$PORT_LIST" ] && ERR "Can not find valid haproxy server info"
PORT_COUNT=`echo $PORT_LIST | wc -w`

LOG "Find and kill old proxy process"
FILTER_PARAM=`echo $PORT_LIST | sed 's/ /\\\\|/g'`
KILL_LIST=`ps axw | grep -v grep | grep $FILTER_PARAM | awk '{print $1}' | sed 's/\/.*//'`
LOG "Old proxy process: $KILL_LIST"
[ -n "$KILL_LIST" ] && kill $KILL_LIST
LOG "Create new proxy process from new configs"
index=0
PORT_ARRAY=($PORT_LIST)
while read line;do
	PORT=${PORT_ARRAY[$index]}
	[ -z "$PORT" ] && break
	$CMD_DIR/ProcResource.sh -r -l $PORT "$line"
	index=`expr $index "+" 1`
	[ $index -ge $PORT_COUNT ] && break
done <$SRC

echo "Perpare proxy for haproxy end"
