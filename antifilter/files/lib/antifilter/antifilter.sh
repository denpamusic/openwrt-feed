#!/bin/sh

. /lib/functions.sh

UCLIENT="uclient-fetch -qT 5 -O -"
IPSET="ipset -!"
IPSETQ="ipset -! -q"
IPV4_PATTERN="[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"
PIDFILE=/var/run/antifilter.pid
DAEMON=0
LOADED=

__true() {
	return 0
}

__false() {
	return 1
}

__ipsets() {
	if_empty "$LOADED" && config_foreach handle_loaded ipset

	echo "$LOADED"
}

log() {
	local level="$1"
	local message="$2"

	if_empty "$message" && message="$level" && level="info"

	case "$level" in
		warning|info|notice|debug)
			if_daemon &&
				logger -t "antifilter[$$]" -p "daemon.$level" "$message" ||
				echo "$message"

			return $(__true)
			;;
		error)
			if_daemon &&
				logger -t "antifilter[$$]" -p "daemon.error" "$message" ||
				>&2 echo "error: $message"

			return $(__false)
			;;
	esac
}

error() {
	log error "$1"
}

if_daemon() {
	[ "$DAEMON" -eq 1 ]
}

if_has_ip4_address() {
	local case="$1"

	echo "$case" | grep -Eq "$IPV4_PATTERN"
}

if_ipset_exists() {
	local name="$1"

	$IPSETQ list "$name" >/dev/null 2>&1
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

handle_loaded() {
	local config="$1"

	if_enabled "$config" && if_ipset_exists "$config" && LOADED="$LOADED $config"
}

get_ipset_diff_message() {
	local before="$1"
	local after="$2"
	local diff

	if_empty "$before" && before=0
	if_empty "$after" && after=0

	diff=$(( before - after ))

	[ $diff -lt 0 ] && echo added ${diff#-} entries
	[ $diff -gt 0 ] && echo removed $diff entries
	[ $diff -eq 0 ] && echo same entries count
}

count_ipset_entries() {
	local ipset="$1"
	local count=0

	if_ipset_exists "$ipset" && count=$($IPSETQ -t list "$ipset" | tail -1 | cut -f2 -d":" | xargs)
	echo $count
}

resolve_hostname() {
	local hostname="$1"
	local ips=$(/usr/bin/nslookup "$hostname" 2>/dev/null | grep -E "Address [0-9]+: $IPV4_PATTERN" | cut -f2 -d":" | xargs)

	if_empty "$ips" && return $(error "$hostname not found")
	echo "$ips"
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
	local items="$3"
	local ipset="$(echo -e "$items" | create_ipset "$name" "$type")"

	if_has_ip4_address "$ipset" || return $(error "Could not create ipset or ipset is empty [ipset: $name]")

	echo "$ipset" | $IPSETQ restore
	$IPSETQ create "$name" "$type"
	$IPSETQ swap "${name}_new" "$name"
	$IPSETQ destroy "${name}_new"
	unset ipset
}

append_entries() {
	local name="$1"
	local entries="$2"
	local entry

	if_ipset_exists "$name" || return $(error "ipset does not exist [ipset: $name]")

	for entry in $entries; do
		$IPSETQ add "$name" "$entry"
	done
}

handle_url() {
	local url="$1"
	local config="$2"
	local type="$3"
	local ttl="$4"
	local datadir md5sum file

	config_get datadir "antifilter" datadir "/tmp/antifilter"

	mkdir -p "$datadir"
	md5sum=$(echo "$url" | md5sum | cut -d" " -f1)
	file="$datadir/$md5sum.lst.gz"

	if_file_older_than "$file" "$ttl" && {
		log info "Fetching ${url##*/} from remote..."
		$UCLIENT "$url" | gzip > "$file"
	} || log info "Loading ${url##*/} from cached copy: ${file##*/}..."

	load_ipset "$config" "$type" "$(gzip -dkc "$file")" && break
}

handle_source() {
	local config="$1"
	local source="$2"
	local type ttl

	config_get type "$config" type "hash:net"
	config_get ttl  "$source" ttl 360
	config_list_foreach "$source" url handle_url "$config" "$type" "$ttl"

	if_ipset_exists "$config" || return $(error "No alive sources for $source [ipset: $config]")
}

handle_entries() {
	local config="$1"
	local entries="$2"
	local items=
	local type entry source

	config_get type "$config" type "hash:net"
	config_get source "$config" source

	for entry in $entries; do
		log info "Resolving and adding $entry..."
		if_has_ip4_address "$entry" || entry="$(resolve_hostname "$entry")"
		if_empty "$entry" || items="$items $entry"
	done

	items=$(echo ${items:1} | tr " " "\n")

	if_empty "$source" && load_ipset "$config" "$type" "$items" || append_entries "$config" "$items"

	unset items
}


handle_ipset() {
	local config="$1"
	local source entries before after

	if_enabled "$config" || return $(__true)

	config_get source "$config" source
	config_get entries "$config" entry

	log info "Loading $config..."
	if_empty "$source" "$entries" && return $(error "No source or entries defined [ipset: $config]")
	before=$(count_ipset_entries "$config")
	if_empty "$source"  || handle_source  "$config" "$source"
	if_empty "$entries" || handle_entries "$config" "$entries"
	after=$(count_ipset_entries "$config")
	log info "$config: $(get_ipset_diff_message $before $after)"
}

antifilter_update() {
	local config="$1"

	if_empty "$config" && config_foreach handle_ipset ipset || handle_ipset "$config"
}

antifilter_add() {
	local config="$1"
	shift
	local entries="$*"
	local entry

	if_enabled "$config" || return $(__true)

	for entry in $entries; do
		uci_remove_list antifilter "$config" entry "$entry"
		uci_add_list antifilter "$config" entry "$entry"
	done

	uci_commit antifilter && config_load antifilter && antifilter_update "$config"
}

antifilter_delete() {
	local config="$1"
	shift
	local entries="$*"
	local entry

	for entry in $entries; do
		uci_remove_list antifilter "$config" entry "$entry"
	done

	uci_commit antifilter && config_load antifilter && antifilter_update "$config"
}

antifilter_lookup() {
	local entries="$*"
	local matches=0
	local ipsets entry

	if_empty "$entries" && return $(error "no hosts or ips to check")

	for entry in $entries; do

		ipsets=

		if_has_ip4_address "$entry" || {
			echo "Checking for $entry:"
			antifilter_lookup "$(resolve_hostname "$entry")"
			continue
		}

		for ipset in $(__ipsets); do
			$IPSETQ test "$ipset" "$entry" && matches=$(( matches + 1 )) && ipsets="$ipsets, $ipset"
		done

		[ $matches -gt 0 ] &&
			echo "$entry is listed in following blocklists: ${ipsets:2}." ||
			echo "$entry is not listed in any blocklists."

	done
}

antifilter_unload() {
	local config="$1"
	local ipsets="$(__ipsets)"
	local ipset

	if_empty "$config" || {
		if_ipset_exists "$config" || return $(error "ipset $config does not exists")
		ipsets="$config"
	}

	for ipset in $ipsets; do $IPSETQ destroy "$ipset"; done
}

antifilter_dump() {
	local config="$1"
	local ipsets="$(__ipsets)"
	local ipset

	if_empty "$config" || {
		if_ipset_exists "$config" || return $(error "ipset $config does not exists")
		ipsets="$config"
	}

	for ipset in $ipsets; do $IPSETQ save "$ipset"; done
}

antifilter_status() {
	[ -f $PIDFILE ] &&
		echo "Update service is running with pid $(cat $PIDFILE)" ||
		echo "Update service is not running"
	echo

	echo Loaded ipsets:
	for ipset in $(__ipsets); do echo "$ipset ($(count_ipset_entries "$ipset") entries)"; done
}

antifilter_daemon() {
	local minutes

	DAEMON=1

	config_get minutes antifilter interval 360

	log info "Using update interval of $minutes minutes..."

	while true; do
		antifilter_update || exit $?
		sleep $(( minutes * 60 ))
	done
}

config_load antifilter
