#!/bin/sh

FUN_DIR=${FUN_DIR:-./functions}
CFG_DIR=${CFG_DIR:-./configs}
CMD_DIR=${CMD_DIR:-./commands}
PROTO_DIR=${PROTO_DIR:-./protocols}
HTTP_FILE=/var/www/html/share/result.lst

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

[ -f $HTTP_FILE  ] && MD5_HTTP=`md5sum $HTTP_FILE`
MD5_SRC=`md5sum $SRC`
LOG "MD5: $MD5_SRC, $MD5_HTTP"
[ "$MD5_SRC" = "$MD5_HTTP" ] && {
	WRN "File $SRC unchanged, do nothing"
	return 0
}
cp $SRC $HTTP_FILE.tmp
cat $SRC | base64 >${HTTP_FILE}.src.tmp
mv $HTTP_FILE.tmp $HTTP_FILE
mv $HTTP_FILE.src.tmp $HTTP_FILE.src

check_files $CFG_DIR/mqtt.cfg || ERR "Can not find mqtt setting"
. $CFG_DIR/mqtt.cfg

check_variables HOST TOPIC MESSAGE || ERR "Invalid mqtt config file: $CFG_DIR/mqtt.cfg"
LOG "Public file changes"
[ -n "$USER" ] && USER="-u $USER"
[ -n "$PASSWD" ] && PASSWD="-P $PASSWD"
[ -n "$PORT" ] && PORT="-p $PORT"
[ -n "$QOS" ] && QOS="-q $QOS"
LOG "mosquitto_pub -h $HOST $PORT $USER $PASSWD $QOS -t $TOPIC -m \"$MESSAGE\""
mosquitto_pub -h $HOST $PORT $USER $PASSWD $QOS -t $TOPIC -m "$MESSAGE"
