#!/bin/sh

. /lib/functions.sh

UCLIENT="uclient-fetch -qT 5 -O -"
IPSET="ipset -!"
IPSETQ="ipset -! -q"
IPV4_PATTERN="[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"

log() {
	local level="$1"
	local message="$2"

	[ "$level" = "error" ] && >&2 echo "$message" || echo "$message"
	logger -t "antifilter[$$]" -p "daemon.$1" "$2"
}

get_ipsets() {
    local ipsets

    ipsets=$(uci show antifilter | grep ipset | cut -f2 -d'.' | cut -f1 -d'=')
	for ipset in $ipsets; do
		echo "$(uci get antifilter."$ipset".prefix)_$ipset"
	done
}

count_ipset_entries() {
	$IPSETQ -t list "$1" | tail -1 | cut -f2 -d':' | xargs
}

get_ipset_diff_message() {
	local before="$1"
	local after="$2"
	
	[ -z "$before" ] && before=0
	[ -z "$after" ] && after=0

	diff=$(( $before - $after ))

	if [ "$diff" -lt 0 ]; then
		echo added "${diff#-}" entries
	elif [ "$diff" -gt 0 ]; then
		echo removed "$diff" entries
	else
		echo same entries count
	fi
}

get_ipset_name() {
	local prefix
	config_get prefix "$1" prefix
	echo "${prefix}_$1"
}

resolve_hostname() {
	nslookup "$1" 2>/dev/null | grep -E "Address [0-9]+: $IPV4_PATTERN" | cut -f2 -d':' | xargs
}

create_ipset() {
	local config="$1"
	local ipset type

	config_get type "$config" type "hash:net"

	ipset=$(get_ipset_name "$config")
	echo "create ${ipset}_new $type"
	sed -e "s/^/add ${ipset}_new /"
}

load_ipset() {
	local config="$1"
	local ipset type state before after

	config_get type "$config" type "hash:net"

	state=$(create_ipset "$config")
	echo "$state" | grep -q "add " || return 1

	ipset=$(get_ipset_name "$config")
	log info "Loading $ipset..."
	before=$(count_ipset_entries "$ipset")
	echo "$state" | $IPSETQ restore
	$IPSETQ create "$ipset" "$type"
	$IPSETQ swap "${ipset}_new" "$ipset"
	$IPSETQ destroy "${ipset}_new"
	after=$(count_ipset_entries "$ipset")

	log info "$ipset: $(get_ipset_diff_message "$before" "$after")"
	unset state
}

handle_ipset() {
	local config="$1"
	local file sources enabled

	config_get_bool enabled "$config" "enabled" 0
	[ "$enabled" -eq 0 ] && return

	config_get file "$config" file
	config_get sources "antifilter" source

	for source in $sources; do
		$UCLIENT "$source/$file" | load_ipset "$config" && return
	done

	log error "No alive sources for $file"
}

antifilter_update() {
	config_load antifilter
	config_foreach handle_ipset ipset
}

antifilter_remove() {
	for ipset in $(get_ipsets); do
		$IPSETQ destroy "$ipset"
	done
}

antifilter_status_ipsets() {
	local entries

	echo "Loaded ipsets:"
	for ipset in $(get_ipsets); do
		entries="$(count_ipset_entries "$ipset")"
		[ -n "$entries" ] && echo "$ipset ($entries entries)"
	done
}

antifilter_status() {
	[ -f /var/run/antifilter.pid ] && {
		echo "Update service is running with pid $(cat /var/run/antifilter.pid)"
	} || echo "Update service is NOT running"

	echo

	antifilter_status_ipsets
}

antifilter_dump() {
	for ipset in $(get_ipsets); do
		$IPSETQ save "$ipset"
	done
}

antifilter_lookup() {
	local needle="$*"
	local resolved=0
	local found=0
	local hostname

	echo "$needle" | grep -Eqv "^($IPV4_PATTERN ?){0,}$" && {
		hostname="$1"
		needle=$(resolve_hostname "$hostname") && resolved=1
	}

	for ipset in $(get_ipsets); do
		for ip in $needle; do
			$IPSET test "$ipset" "$ip" && found=$(( found + 1 ))
		done
	done

	[ "$found" -gt 0 ] && {
		echo "$hostname" is LISTED in "$found" blocklists.
	} || echo "$hostname" is NOT LISTED in any blocklists.
	
	return "$found"
}

antifilter_daemon() {
	local minutes

	config_load antifilter
	config_get minutes "antifilter" interval 360

	log notice "Using update interval of $minutes minutes..."
	while true; do
		antifilter_update || exit $?
		sleep $(( minutes * 60 ))
	done
}
