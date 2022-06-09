#!/bin/sh

__true() {
	return 0
}

__false() {
	return 1
}

log() {
	local level="$1"
	local message="$2"

	if_empty "$message" && message="$level" && level="info"

	case "$level" in
		warning|info|notice|debug)
			if_daemon &&
				logger -t "antifilter[$$]" -p "daemon.$level" "$message" ||
				echo -e "$message"

			return $(__true)
			;;
		error)
			if_daemon &&
				logger -t "antifilter[$$]" -p "daemon.error" "$message" ||
				>&2 echo -e "error: $message"

			return $(__false)
			;;
	esac
}

error() {
	log error "$1"
}

if_ipset_exists() {
	local name="$1"

	$IPSETQ list "$name" >/dev/null 2>&1
}

if_has_ip4_address() {
	local case="$1"

	echo "$case" | grep -Eq "$IPV4_PATTERN"
}

if_file_older_than() {
	local file="$1"
	local age="$2"
	local mtime

	[ ! -f "$file" ] && return $(__true)

	mtime=$(date -r "$file" "+%s")
	now=$(date "+%s")

	[ $(( (now - mtime) / 60 )) -ge $age ]
}

if_empty() {
	local vars="$*"
	local var result

	for var in $vars; do
		[ -z "$var" ] && return $(false)
	done
}

if_enabled() {
	local config="$1"
	local enabled

	config_get_bool enabled "$config" enabled 0
	[ $enabled -eq 1 ]
}

if_list_has() {
	local needle="$1"
	shift
	local list="$*"

	for item in $list; do
		[ "$item" == "$needle" ] && return 0
	done

	return 1
}

resolve_hostname() {
	local hostname="$1"
	local ips=$($NSLOOKUP -type=A "$hostname" 2>/dev/null | grep -E "Address: $IPV4_PATTERN" | cut -f2 -d":" | xargs)

	if_empty "$ips" && return $(error "$hostname not found")
	echo "$ips"
}

join_with() {
	local IFS="$1";
	shift;
	echo "$*";
}
