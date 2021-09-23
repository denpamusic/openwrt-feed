#!/bin/sh

. /lib/functions.sh

UCLIENT="uclient-fetch -qT 5 -O -"
IPSET="ipset -!"
IPSETQ="ipset -! -q"
IPV4_PATTERN="[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"
LOADED=

log() {
	local level="$1"
	local message="$2"

	case $level in
		warning | error | debug)
			>&2 echo "$message"
			;;
		*)
			echo "$message"
			;;
	esac

	logger -t "antifilter[$$]" -p "daemon.$1" "$2"
}

count_ipset_entries() {
	$IPSETQ -t list "$1" | tail -1 | cut -f2 -d":" | xargs
}

get_ipset_diff_message() {
	local before="$1"
	local after="$2"

	[ -z $before ] && before=0
	[ -z $after  ] && after=0

	diff=$(( before - after ))

	[ $diff -lt 0 ] && echo added ${diff#-} entries
	[ $diff -gt 0 ] && echo removed $diff entries
	[ $diff -eq 0 ] && echo same entries count
}

get_ipset_name() {
	local config="$1"
	local prefix
	config_get prefix "$config" prefix
	echo "$prefix"_"$config"
}

resolve_hostname() {
	local hostname="$1"
	local ips
	ips=$(nslookup "$hostname" 2>/dev/null | grep -E "Address [0-9]+: $IPV4_PATTERN" | cut -f2 -d":" | xargs)
	[ -z "$ips" ] && return 1
	echo "$ips"
}

create_ipset() {
	local name="$1"
	local type="$2"

	echo "create ${name}_new $type"
	sed -e "s/^/add ${name}_new /"
}

load_ipset() {
	local config="$1"
	local ipset name type before after

	config_get type "$config" type "hash:net"

	name=$(get_ipset_name "$config")
	ipset=$(create_ipset "$name" "$type")
	echo "$ipset" | grep -q "add " || return 1

	before=$(count_ipset_entries "$name")

	log info "Loading $name [type: $type]..."
	echo "$ipset" | $IPSETQ restore
	$IPSETQ create "$name" "$type"
	$IPSETQ swap "${name}_new" "$name"
	$IPSETQ destroy "${name}_new"

	after=$(count_ipset_entries "$name")

	log info "$name: $(get_ipset_diff_message $before $after)"
	unset ipset
}

handle_ipset() {
	local config="$1"
	local prefix enabled

	config_get_bool enabled "$config" enabled 0
	[ $enabled -eq 0 ] && return

	LOADED="$LOADED $(get_ipset_name "$config")"
}

get_ipsets() {
	[ -z "$LOADED" ] && {
		config_load antifilter
		config_foreach handle_ipset ipset
	}

	echo "$LOADED"
}

handle_source() {
	local config="$1"
	local file source sources enabled

	config_get_bool enabled "$config" enabled 0
	[ $enabled -eq 0 ] && return

	config_get file "$config" file
	config_get sources "antifilter" source

	for source in $sources; do
		$UCLIENT "$source/$file" | load_ipset "$config" && return
	done

	log error "No alive sources for $file"
}

antifilter_update() {
	config_load antifilter
	config_foreach handle_source ipset
}

antifilter_remove() {
	local ipset
	for ipset in $(get_ipsets); do
		$IPSETQ destroy "$ipset"
	done
}

antifilter_status_ipsets() {
	local ipset
	echo Loaded ipsets:
	for ipset in $(get_ipsets); do
		echo "$ipset ($(count_ipset_entries "$ipset") entries)"
	done
}

antifilter_status() {
	[ -f /var/run/antifilter.pid ] &&
		echo "Update service is running with pid $(cat /var/run/antifilter.pid)" ||
		echo "Update service is NOT running"
	echo

	antifilter_status_ipsets
}

antifilter_dump() {
	local ipset
	for ipset in $(get_ipsets); do
		$IPSETQ save "$ipset"
	done
}

antifilter_lookup() {
	local ips="$*"
	local matches=0
	local ip ipsets

	[ -z "$ips" ] && return 1

	for ip in $ips; do

		ipsets=

		echo "$ip" | grep -Eqv "$IPV4_PATTERN" && {
			echo "Checking for $ip:"
			antifilter_lookup $(resolve_hostname "$ip") || echo "error: $ip not found"
			continue
		}

		for ipset in $(get_ipsets); do
			$IPSETQ test "$ipset" "$ip" && matches=$(( matches + 1 )) && ipsets="$ipsets, $ipset"
		done

		[ $matches -gt 0 ] &&
			echo "$ip is LISTED in following blocklists: ${ipsets:2}." ||
			echo "$ip is NOT LISTED in any blocklists."

	done
}

antifilter_daemon() {
	local minutes

	config_load antifilter
	config_get minutes antifilter interval 360

	log notice "Using update interval of $minutes minutes..."
	while true; do
		antifilter_update || exit $?
		sleep $(( minutes * 60 ))
	done
}
