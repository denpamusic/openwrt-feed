#!/bin/sh

. /lib/functions.sh

UCLIENT="uclient-fetch -qT 5 -O -"
IPSET="ipset -!"
IPSETQ="ipset -! -q"
NSLOOKUP=/usr/bin/nslookup
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

	[ $diff -lt 0 ] && echo "($before -> $after, +${diff#-} entries)"
	[ $diff -gt 0 ] && echo "($before -> $after, -${diff} entries)"
	[ $diff -eq 0 ] && echo "($after entries)"
}

count_ipset_entries() {
	local ipset="$1"
	local count=0

	if_ipset_exists "$ipset" && count=$($IPSETQ -t list "$ipset" | tail -1 | cut -f2 -d":" | xargs)
	echo $count
}

resolve_hostname() {
	local hostname="$1"
	local ips=$($NSLOOKUP "$hostname" 2>/dev/null | grep -E "Address [0-9]+: $IPV4_PATTERN" | cut -f2 -d":" | xargs)

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

	if_has_ip4_address "$ipset" || return $(error "${PALETTE_BOLD}${name}:${PALETTE_RESET} could not create ipset or ipset is empty")

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

	if_ipset_exists "$name" || return $(error "${PALETTE_BOLD}${name}:${PALETTE_RESET} ipset does not exist")

	for entry in $entries; do
		$IPSETQ add "$name" "$entry"
	done
}

handle_url() {
	local url="$1"
	local config="$2"
	local source="$3"
	local type="$4"
	local ttl="$5"
	local datadir md5sum file

	config_get datadir "antifilter" datadir "/tmp/antifilter"

	mkdir -p "$datadir"
	md5sum=$(echo "$url" | md5sum | cut -d" " -f1)
	file="$datadir/$md5sum.lst.gz"

	if_file_older_than "$file" "$ttl" && {
		log info "${PALETTE_BOLD}${config}:${PALETTE_RESET} fetching ${PALETTE_GREEN}${source}${PALETTE_RESET} from ${PALETTE_GREEN}${url}${PALETTE_RESET}..."
		$UCLIENT "$url" | gzip > "$file"
	} || log info "${PALETTE_BOLD}${config}:${PALETTE_RESET} loading ${PALETTE_GREEN}${source}${PALETTE_RESET} from cached copy ${PALETTE_GREEN}${file##*/}${PALETTE_RESET}..."

	load_ipset "$config" "$type" "$(gzip -dkc "$file")" && break || rm -f "$file"
}

handle_source() {
	local config="$1"
	local source="$2"
	local type ttl

	config_get type "$config" type "hash:net"
	config_get ttl  "$source" ttl 360
	config_list_foreach "$source" url handle_url "$config" "$source" "$type" "$ttl"

	if_ipset_exists "$config" || return $(error "${config}: found no alive sources for $source")
}

handle_entries() {
	local config="$1"
	local entries="$2"
	local items=
	local type entry source

	config_get type "$config" type "hash:net"
	config_get source "$config" source

	for entry in $entries; do
		log info "${PALETTE_BOLD}${config}:${PALETTE_RESET} resolving and adding ${PALETTE_CYAN}$entry${PALETTE_RESET}..."
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

	log notice "${PALETTE_BOLD}${config}:${PALETTE_RESET} loading ipset..."
	if_empty "$source" "$entries" && return $(error "${PALETTE_BOLD}${config}:${PALETTE_RESET} no source or entries defined")
	before=$(count_ipset_entries "$config")
	if_empty "$source"  || handle_source  "$config" "$source"
	if_empty "$entries" || handle_entries "$config" "$entries"
	after=$(count_ipset_entries "$config")
	log notice "${PALETTE_BOLD}${config}:${PALETTE_RESET} ${PALETTE_REVERSE}ipset loaded $(get_ipset_diff_message $before $after)${PALETTE_RESET}"
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

	echo -e "${PALETTE_BOLD}${config}:${PALETTE_RESET} ${PALETTE_REVERSE}adding ${entries}${PALETTE_RESET}"

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

	echo -e "${PALETTE_BOLD}${config}:${PALETTE_RESET} ${PALETTE_REVERSE}removing ${entries}${PALETTE_RESET}"

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
		matches=0

		if_has_ip4_address "$entry" || {
			echo -e "${PALETTE_REVERSE}${entry}: resolving...${PALETTE_RESET}"
			antifilter_lookup "$(resolve_hostname "$entry")"
			continue
		}

		for ipset in $(__ipsets); do
			$IPSETQ test "$ipset" "$entry" && matches=$(( matches + 1 )) && ipsets="$ipsets, ${PALETTE_BOLD}$ipset${PALETTE_RESET}"
		done

		[ $matches -gt 0 ] &&
			echo -e "${PALETTE_BOLD}${entry}${PALETTE_RESET}: ${PALETTE_RED}listed in following IP sets: ${PALETTE_RESET}${ipsets:2}" ||
			echo -e "${PALETTE_BOLD}${entry}${PALETTE_RESET}: ${PALETTE_GREEN}not listed in any IP sets${PALETTE_RESET}"

	done
}

antifilter_unload() {
	local config="$1"
	local ipsets="$(__ipsets)"
	local ipset

	if_empty "$config" || {
		if_ipset_exists "$config" || return $(error "${PALETTE_BOLD}${config}:${PALETTE_RESET} ipset  does not exists")
		ipsets="$config"
	}

	for ipset in $ipsets; do $IPSETQ destroy "$ipset"; done
}

antifilter_dump() {
	local config="$1"
	local ipsets="$(__ipsets)"
	local ipset

	if_empty "$config" || {
		if_ipset_exists "$config" || return $(error "${PALETTE_BOLD}${config}:${PALETTE_RESET} ipset does not exists")
		ipsets="$config"
	}

	for ipset in $ipsets; do $IPSETQ save "$ipset"; done
}

antifilter_status() {
	[ -f $PIDFILE ] &&
		echo -e "${PALETTE_BOLD}Service:${PALETTE_RESET}\n${PALETTE_GREEN}running (pid $(cat $PIDFILE))${PALETTE_RESET}\n" ||
		echo -e "${PALETTE_BOLD}Service:${PALETTE_RESET}\n${PALETTE_RED}not running${PALETTE_RESET}\n"

	echo -e "${PALETTE_BOLD}IP sets:${PALETTE_RESET}"
	for ipset in $(__ipsets); do
		echo -e " - ${PALETTE_REVERSE}$ipset${PALETTE_RESET} ($(count_ipset_entries "$ipset") entries)"
	done
}

antifilter_daemon() {
	local minutes

	DAEMON=1

	config_get minutes antifilter interval 360

	log notice "update every $minutes minutes..."

	while true; do
		antifilter_update || exit $?
		sleep $(( minutes * 60 ))
	done
}

config_load antifilter
