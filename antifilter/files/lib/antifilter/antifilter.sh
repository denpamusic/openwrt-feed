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

has_ip4_address() {
	local case="$1"

	echo "$case" | grep -Eq "$IPV4_PATTERN"
}

if_ipset_exists() {
	local name="$1"

	$IPSETQ list "$name" >/dev/null 2>&1
}

count_ipset_entries() {
	local count

	count=$($IPSETQ -t list "$1" | tail -1 | cut -f2 -d":" | xargs)
	[ -z $count ] && count=0

	echo $count
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
	echo "${prefix}_${config}"
}

resolve_hostname() {
	local hostname="$1"
	local ips

	ips=$(nslookup "$hostname" 2>/dev/null | grep -E "Address [0-9]+: $IPV4_PATTERN" | cut -f2 -d":" | xargs)
	[ -z "$ips" ] && {
		log error "$hostname not found"
		return 1
	}

	echo "$ips"
}

handle_ipset() {
	local config="$1"
	local enabled

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

add_ipset_entries() {
	local name="$1"
	local entries="$2"
	local entry

	if_ipset_exists "$name" || {
		log error "ipset DOES NOT exist [ipset: $name]"
		return 1
	}

	for entry in $entries; do
		$IPSETQ add "$name" "$entry"
	done
}

create_ipset() {
	local name="$1"
	local type="$2"

	echo "create ${name}_new $type"
	sed -e "s/^/add ${name}_new /"
}

load_ipset() {
	local name="$1"
	local type="$2"
	local ipset

	ipset=$(create_ipset "$name" "$type")

	has_ip4_address "$ipset" || {
		log error "Could not create ipset or ipset is empty [ipset: $name]"
		return 1
	}

	echo "$ipset" | $IPSETQ restore
	$IPSETQ create "$name" "$type"
	$IPSETQ swap "${name}_new" "$name"
	$IPSETQ destroy "${name}_new"
	unset ipset
}

handle_source_file() {
	local config="$1"
	local file="$2"
	local sources type name source

	config_get sources "antifilter" source
	config_get type "$config" type "hash:net"

	name=$(get_ipset_name "$config")

	for source in $sources; do
		$UCLIENT "$source/$file" | load_ipset "$name" "$type" && return
	done

	log error "No alive sources for $file [ipset: $name]"
	return 1
}

handle_source_entries() {
	local config="$1"
	local entries="$2"
	local type ipset entry name

	config_get type "$config" type "hash:net"

	ipset=
	for entry in $entries; do
		has_ip4_address "$entry" || entry=$(resolve_hostname "$entry")
		[ ! -z "$entry" ] && ipset="$ipset $entry"
	done

	name=$(get_ipset_name "$config")
	ipset=$(echo ${ipset:1} | tr "" "\n")

	if_ipset_exists "$name" && add_ipset_entries "$name" "$ipset" || {
		echo -e "$ipset" | load_ipset "$name" "$type"
	}

	unset ipset
}

handle_source() {
	local config="$1"
	local enabled file entries name before after

	config_get_bool enabled "$config" enabled 0
	[ $enabled -eq 0 ] && return

	config_get file "$config" file
	config_get entries "$config" entry

	log info "Loading $config..."

	[ -z "$file" ] && [ -z "$entries" ] && {
		log error "No source file or entries defined [ipset: $config]"
		return 1
	}

	name=$(get_ipset_name "$config")
	before=$(count_ipset_entries "$name")
	[ ! -z "$file" ]    && handle_source_file    "$config" "$file"
	[ ! -z "$entries" ] && handle_source_entries "$config" "$entries"
	after=$(count_ipset_entries "$name")

	log info "$name: $(get_ipset_diff_message $before $after)"
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

		has_ip4_address "$ip" || {
			echo "Checking for $ip:"
			antifilter_lookup $(resolve_hostname "$ip")
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
