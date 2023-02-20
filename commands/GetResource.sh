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
	echo "     -s: do NOT delete temp files"
	echo "     -u URL: resource URL"
	echo "     -k KEY: KEY of resource"
	echo "     -t TAG: html TAG of resouce"
	echo "     -d DECODE: decode mathod"
	echo "     -f DIST_FILE: save resources to this file"
	echo "     -c config_file: read params from config file(Highest priority)"
	exit 1
}

#Functions
cleanup(){
	[ "$DELETE" != "0" ] && {
		[ -f "$SRC" ] && rm -rf $SRC
		[ -f "$DEC" ] && rm -rf $DEC
	}
	return 0
}

#Usage: SRC_GET [CURL PARAM]
SRC_GET(){
	local PARAM="$@"
	local TYPE=`get_prefix "$URL"`
	DBG "Download resource from $URL"
	[ "$TYPE" = "file" ] && {
		URL=`echo "$URL" | sed "s/.*:\/\///"`
		[ ! -f $URL ] && ERR "Can not find source file: $URL"
		DBG "cp -u $URL $SRC"
		cp -u $URL $SRC
		return 0
	}
	[ -z "$KEY$TAG" ] && {
		DBG "curl --max-filesize 2M -s $PARAM $URL >$SRC"
		curl --max-filesize 2M -s $PARAM $URL >$SRC
	} || {
		[ -z "$KEY" -o -z "$TAG" ] && ERR "Both \"KEY\" and \"TAG\" should define"
		#eg:
		#  sed -e '/SS节点/,/<\/pre>/!d;/<pre>/,/<\/pre>/!d;s/.*<pre>//;s/<\/pre>.*//'
		SED_CMD="/$KEY/,/<\/$TAG>/!d;/<$TAG>/,/<\/$TAG>/!d;s/.*<$TAG>//;s/<\/$TAG>.*//"
		DBG "curl --max-filesize 2M -s $PARAM $URL | sed -e \"${SED_CMD}\" >$SRC"
		curl --max-filesize 2M -s $PARAM $URL | sed -e "${SED_CMD}" >$SRC
	}
	#check file size
	[ ! -s $SRC ] && return 1
	return 0
}
#Usage: SRC_DECODE source_file_name dist_file_name
SRC_DECODE(){
	DBG "Try decode $SRC with decoder \"$DECODE\""
	if [ -z "$DECODE" -o "$DECODE" = "none" ];then
		cp $SRC $DEC
	else
		#DBG "cat $SRC | $DECODE >$DEC"
		cat $SRC | $DECODE >$DEC
	fi
}
############################
#Chekc params
[ $# = 0 ] && {
	USAGE $0
}

CFG=""
DELETE=${DELETE:-1}
while getopts ":f:k:t:u:d:c:svD" opt; do
	case $opt in
		c)
			CFG=$OPTARG
			[ -f "$CFG" ] && . $CFG
		;;
		f)
			DIST=$OPTARG
		;;
		k)
			KEY=$OPTARG
		;;
		t)
			TAG=$OPTARG
		;;
		u)
			URL=$OPTARG
		;;
		d)
			DECODE=$OPTARG
		;;
		s)
			DELETE=0
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
#KEY_LIST="KEY TAG URL DECODE"
check_variables URL || ERR "Not all key varables defined"

DIST=${DIST:-$$-$EXEC.dst}
SRC=$DIST-$$.src
DEC=$DIST-$$.dec
mkdir -p `dirname $DIST`

trap cleanup EXIT

LOG "Try get resource from $URL, with key \"$KEY\" and tag \"$TAG\""
SRC_GET || ERR "Get resource fail: $URL"
SRC_DECODE || ERR "Decode resource from $URL fail: $SRC"
cat $DEC >>${DIST}

