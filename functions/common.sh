
LOG_LEVEL=${LOG_LEVEL:-2}
[ -z "$EXEC" ] && {
	EXEC=`basename $0`
	export EXEC
}

verbose(){
	LOG_LEVEL=$((LOG_LEVEL+1))
}
_LOG(){
	logger -s "${EXEC}: $@"
}

DBG(){
	[ $LOG_LEVEL -ge 6 ] && echo "${EXEC}: $@"
	return 0
}

LOG(){
	[ $LOG_LEVEL -ge 5 ] && echo "$@"
	return 0
}
INF(){
	[ $LOG_LEVEL -ge 4 ] && _LOG "$@"
	return 0
}
WRN(){
	[ $LOG_LEVEL -ge 2 ] && _LOG "$@"
	return 0
}

ERR(){
	[ $LOG_LEVEL -ge 1 ] && _LOG "$@"
	exit 1
}

base64_decode(){
	local len
	local str
	local atta
	local remainder
	[ -z "$1" ] && return 1
	str=`echo "$1" | sed 's/_/\//g;s/-/+/g'`
	len=${#str}
	remainder=$((len%4))
	[ "$remainder" = 3 ] && atta="="
	[ "$remainder" = 2 ] && atta="=="
	echo -n "${str}${atta}" | base64 -d 2>/dev/null
}

wait_childs(){
	local children="$@"
	local EXIT=0
	for job in ${children[@]}; do
		CODE=0;
		wait ${job} || CODE=$?
		LOG "PID ${job} exit code: $CODE"
		[ "${CODE}" != "0" ] && EXIT=1
	done
	return $EXIT
}

get_prefix(){
	echo "$1" | sed '/:\/\//!d;s/:\/\/.*//'
}
drop_prefix(){
	echo "$1" | sed '/:\/\//!d;s/.*:\/\///'
}

#json2variables json
json2variables(){
	local String
	local data
	String=`echo $1 | sed 's/":/=/g;s/,"/ /g;s/^{"//;s/}$//'`
	for data in $String;do
		eval "$data"
	done
}
variables2json(){
	local json=""
	for name in $@;do
		json="${json},\"$name\":\"${!name}\""
	done
	echo "{${json}}" | sed 's/^{,/{/'
	return 0
}
#json_get_value json key
json_get_value(){
	echo "$1" | jq ".$2" | sed 's/^null$//;s/^"//;s/"$//'
}

check_variables(){
	local val
	local chk
	[ "$#" -eq 0 ] && ERR "No params"
	for chk in $@;do
		eval val="\${$chk}"
		[ -z "$val" ] && {
			WRN "Key \"$chk\" not defined"
			return 1
		}
	done
	return 0
}
check_files(){
	local chk
	[ "$#" -eq 0 ] && ERR "No params"
	for chk in $@;do
		[ -f "$chk" ] || {
			WRN "File \"$chk\" not exist"
			return 1
		}
	done
	return 0
}
check_dirs(){
	local chk
	[ "$#" -eq 0 ] && ERR "No params"
	for chk in $@;do
		[ -d "$chk" ] || {
			WRN "Dir \"$chk\" not exist"
			return 1
		}
	done
	return 0
}
check_execs(){
	local file
	local chk
	[ "$#" -eq 0 ] && ERR "No params"
	for chk in $@;do
		file=`which $chk`
		[ -z "$file" ] && {
			WRN "Package \"$chk\" not installed"
			return 1
		}
	done
	return 0
}
