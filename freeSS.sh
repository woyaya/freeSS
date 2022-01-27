#!/bin/bash

#Functions
############################
USAGE(){
	echo "Usage: $1 [params]"
	echo "     -b BASE: base dir, where to find configs and functions. default: ./"
	echo "     -t TIMEOUT: timeout time of check resource. default: 5s"
	echo "     -c COUNT: parallel count when check resources. default: 50"
	echo "     -p PORT: local listen port when check resources. default: 20000"
	echo "     -f FILE: save valid resources to this file."
	echo "     -P script: script to be executed after success get resource"
	echo "     -s: do not delete temp files"
	echo "     -v: more verbose output"
	echo "     -D: debug mode"
	echo "     -h: print this"

	exit -1
}
function cleanup() {
	LOG "Cleanup $WORK_DIR: $DELETE"
	[ "$DELETE" != "0" ] && {
		[ -d $WORK_DIR ] && rm  -rf $WORK_DIR
	}
}
############################
while getopts ":b:t:c:P:p:f:svD" opt; do
	case $opt in
		b)
			BASE=$OPTARG
		;;
		t)
			TIMEOUT=$OPTARG
		;;
		c)
			COUNT=$OPTARG
		;;
		p)
			PORT=$OPTARG
		;;
		f)
			FILE=$OPTARG
		;;
		P)
			SCRIPT=$OPTARG
		;;
		s)
			DELETE=0
			shift 1
		;;
		v)
			LOG_LEVEL=$((LOG_LEVEL+1))
			shift 1
		;;
		D)
			DEBUG=1
			DELETE=0
			LOG_LEVEL=100
			shift 1
		;;
		*)
			USAGE $0
		;;
	esac
done

EXEC=`basename $0`
PORT=${PORT:-20000}
COUNT=${COUNT:-50}
TIMEOUT=${TIMEOUT:-5}

#1: ERR; 2:ERR+WRN; 3:ERR+WRN+LOG
LOG_LEVEL=${LOG_LEVEL:-2}
DEBUG=${DEBUG:-0}
DELETE=${DELETE:-1}

export DEBUG
export DELETE
export LOG_LEVEL

#Dir && files
BASE=${BASE:-./}
SRC_DIR=${BASE}/sources
FUN_DIR=${BASE}/functions
CMD_DIR=${BASE}/commands
CFG_DIR=${BASE}/configs
PROTO_DIR=${BASE}/protocols
export SRC_DIR FUN_DIR CMD_DIR CFG_DIR PROTO_DIR

[ ! -f $FUN_DIR/common.sh ] && {
	echo "Invalid setting! file \"$FUN_DIR/common.sh\" not exist"
	return 1
}
. $FUN_DIR/common.sh

check_dirs $SRC_DIR $CMD_DIR $PROTO_DIR || ERR "Incomplete dirs"
check_files $CMD_DIR/GetResource.sh $CMD_DIR/ProcResource.sh || ERR "Incomplete scripts"
check_execs curl logger sed awk uniq sort wc base64 || ERR "Incomplete executes"
[ -n "$FILE" ] && {
	mkdir -p `dirname $FILE` || ERR "Can not mkdir for dist file \"$FILE\""
	touch $FILE || ERR "Can not create dist file: $FILE"
}

WORK_DIR=/tmp/$EXEC
SRC_FILE=$WORK_DIR/$$-resource.lst
VALID_FILE=$WORK_DIR/$$-valid.lst
mkdir -p $WORK_DIR
rm -rf $VALID_FILE $SRC_FILE
trap cleanup EXIT

list=`ls $SRC_DIR/*.cfg 2>/dev/null`
[ -z "$list" ] && ERR "Can not find source file @ dir \"./$SRC_DIR\""
childs=()
for src in $list;do
	LOG "Processing $src"
	$CMD_DIR/GetResource.sh -c "$src"  -f "$SRC_FILE" &
	childs+=("$!")
done

LOG "Waiting for child(s): ${childs[@]}"
wait_childs ${childs[@]}
LOG "Check if any resource ready"
[ -s ${SRC_FILE} ] || ERR "Fail: no resource find"
LOG "Sort contexts: ${SRC_FILE}"
cat ${SRC_FILE} | sort | uniq > ${SRC_FILE}.tmp
mv ${SRC_FILE}.tmp ${SRC_FILE}

#Check if resource valid
INF "Check resource(${SRC_FILE}). It may take long time"
count=0
port=$PORT
while read line;do
	index=`expr $port "-" $PORT`
	LOG "$CMD_DIR/ProcResource.sh -c -i $index -l $port -t $TIMEOUT -f $VALID_FILE \"$line\""
	$CMD_DIR/ProcResource.sh -c -i $index -l $port -t $TIMEOUT -f $VALID_FILE "$line" &
	count=`expr $count "+" 1`
	[ "$count" -lt $COUNT ] && {
		port=`expr $port "+" 1`
		continue
	} || {
		wait -n
		port=$?
		port=`expr $PORT "+" $port`
	}
done <$SRC_FILE
LOG "wait all jobs finished"
wait
LOG "check valid resource size"
[ -s $VALID_FILE ] || ERR "Fail: no proxy works in ${TIMEOUT}S"

LOG "Sort valid server by responce time"
cat $VALID_FILE | sed 's/^[0-9]*\t//' | sort  >$VALID_FILE.tmp
mv $VALID_FILE.tmp $VALID_FILE
LOG "Result file: $VALID_FILE"
[ -n "$FILE" ] && {
	LOG "Save result to file: $FILE"
	cp -f $VALID_FILE $FILE
}
[ -n "$SCRIPT" ] && {
	LOG "Run post script: $SCRIPT"
	script=""
	[ -x $CMD_DIR/$SCRIPT ] && script=$CMD_DIR/$SCRIPT
	[ -x $BASE/$SCRIPT ] && script=$BASE/$SCRIPT
	[ -z "$script" ] && ERR "Can not find script: $script"
	$script -f $VALID_FILE
}
echo "Finished"
