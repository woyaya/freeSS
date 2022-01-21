#!/bin/sh

FUN_DIR=${FUN_DIR:-./functions}
CFG_DIR=${CFG_DIR:-./configs}
CMD_DIR=${CMD_DIR:-./commands}
PROTO_DIR=${PROTO_DIR:-./protocols}
. $FUN_DIR/common.sh

USAGE(){
	echo "Usage: $1 [params] resource"
	echo "     -D: debug"
	echo "     -v: more verbose output"
	echo "     -c: check resource"
	echo "     -r: run command with resource"
	echo "     -i index: parallel job index. default: 0"
	echo "     -l listen: listen this local port. default: 20001"
	echo "     -t timeout: timeout time. default: 2S"
	echo "     -f DIST: saved result to this file if success"
	echo "     resource: check this resource"
	cleanup
}

#Functions
############################
cleanup(){
	[ "$DEBUG" != "1" ] && {
		[ -f "$CFG" ] && rm -rf $CFG
		#[ -f "$DIST" ] && rm -rf $DIST
	}
	exit $index
}
trap cleanup EXIT
############################
#Chekc params
[ $# = 0 ] && {
	USAGE $0
}

CHECK=""
RUN=""
while getopts ":l:t:f:i:rcDv" opt; do
	case $opt in
		f)
			DIST=$OPTARG
			shift 2
		;;
		l)
			LISTEN=$OPTARG
			shift 2
		;;
		t)
			TIMEOUT=$OPTARG
			shift 2
		;;
		i)
			index=$OPTARG
			shift 2
		;;
		c)
			CHECK=1
			RUN=""
			shift 1
		;;
		r)
			RUN=1
			CHECK=""
			shift 1
		;;
		v)
			verbose
			shift 1
		;;
		D)
			DEBUG=1
			LOG_LEVEL=100
			shift 1
		;;
		*)
			USAGE $0
		;;
	esac
done

resource="$@"
index=${index:-0}
LISTEN=${LISTEN:-20001}
TIMEOUT=${TIMEOUT:-2}
DIST=${DIST:-$$-$EXEC.dst}
URL="http://www.youtube.com/generate_204"
[ -z "$RUN$CHECK" ] && CHECK=1
CFG=$DIST-$LISTEN.cfg

#Check varables
check_variables resource || ERR "Not all key varables defined"

PREFIX=`get_prefix "$resource"`
[ ! -f "$PROTO_DIR/decode-$PREFIX" ] && ERR "Unsupport protocal: $resource"

. $PROTO_DIR/decode-$PREFIX

LOG "Try to parse resource: \"$resource\""
CONTENT=`drop_prefix $resource`
[ -z "$CONTENT" ] && cleanup "Invalid resource: $resource"
resource_decode "$CONTENT" || ERR "Decode resource fail: $resource"
resource_parse "$CONTENT" || ERR "Parse resource fail: $resource"
[ -n "$CHECK_LIST" ] && {
	for name in $CHECK_LIST;do
		#[ -z "${!name}" ] && ERR "Check variable fail: $name"
		[ -z "$(eval echo \"\$$name\")" ] && ERR "Check variable fail: $name"
	done
}
config_generate $LISTEN $CFG || ERR "Generate config fail: $resource"

#Start command
[ "$CHECK" = "1" ] && {
	command_start $CFG
	PID=$?

	TIMES=0
	RETRY=3
	RESULT=0
	TIME_THRESHOLD=`expr $TIMEOUT "*" $RETRY`
	TIME_THRESHOLD=`expr $TIME_THRESHOLD "*" 1000`

	for i in `seq 1 $RETRY`;do
		BEGIN=`date +"%s%3N"`
		curl --max-time $TIMEOUT -s -x socks5h://127.0.0.1:$LISTEN $URL >/dev/null
		[ $? != 0 ] && RESULT=$((RESULT+1))
		END=`date +"%s%3N"`
		COST=`expr $END "-" $BEGIN`
		TIMES=`expr $TIMES "+" $COST`
		sleep 1
	done
	command_stop $PID
	#[ "$RESULT" = "$RETRY" ] && cleanup
	[ "$RESULT" = "$RETRY" ] && ERR "Resource fail: $resource"
	#take more then 3S, ignore it
	[ $TIMES -gt $TIME_THRESHOLD ] && ERR "Resource timeout: $resource"
	#TIMES=${TIMES:0-4}
	TIMES=`echo -n "00000$TIMES" | tail -c 5`
	LOG "$TIMES\t$resource"
	echo "$TIMES\t$resource" >>$DIST
}
[ "$RUN" = "1" ] && {
	command_run $CFG
}

cleanup
