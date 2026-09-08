#!/bin/bash

#STARTPWD="$(pwd)"
#cd -- "$(dirname "$0")/.." || exit 1
#BASEDIR="$(pwd)"
#cd -- "$STARTPWD" || exit 1

# build dynamically something like agepass_cmds='init list exists get set unset'
agepass_cmds=''
agepass_cmds2=''


## (internal) ##

agepass_reqargs() {
	local cmd="$1";shift
	local nreq="$1";shift
	local ngot="$1";shift
	if [ $nreq -gt $ngot ]; then
		echo >&2 "ERROR: Missing argument"
		agepass_cmd_help "$cmd"
		return 2
	fi
}

## dir ##
agepass_cmds2="${agepass_cmds2:+$agepass_cmds2 }dir"
agepass_cmd_help_dir() {
	echo >&2 "Usage: agepass.sh dir"
}
agepass_dir() {
	#agepass_reqargs dir 0 $# || return $?
	printf %s\\n "${AGEPASS_DIR:-$HOME/.agepass}"
}

## init ##
agepass_cmds="${agepass_cmds:+$agepass_cmds }init"
agepass_cmd_help_init() {
	echo >&2 "Usage: agepass.sh init"
}
agepass_init() {
	#agepass_reqargs dir 0 $# || return $?
	local agepass_dir="$(agepass_dir)"
	[ -d "$agepass_dir" ] || mkdir -p -- "$agepass_dir"
	chmod 700 "$agepass_dir"
	[ -d "$agepass_dir/secrets" ] || mkdir "$agepass_dir/secrets"
	chmod 700 "$agepass_dir/secrets"
	[ -d "$agepass_dir/pass" ] || mkdir "$agepass_dir/pass"
	chmod 700 "$agepass_dir/pass"

	[ -f "$agepass_dir/secrets/age.key" ] || age-keygen    -o "$agepass_dir/secrets/age.key" 2>/dev/null
	if [ ! -f "$agepass_dir/secrets/age.pub" ]; then
		echo "# $(whoami)@$(uname -n)/$(date +%Y-%m-%d)" > "$agepass_dir/secrets/age.pub"
		age-keygen -y  "$agepass_dir/secrets/age.key" >> "$agepass_dir/secrets/age.pub"
	fi
	[ -f "$agepass_dir/secrets/recipients.pub" ] || cat "$agepass_dir/secrets/age.pub" >> "$agepass_dir/secrets/recipients.pub"
}

## list ##
agepass_cmds="${agepass_cmds:+$agepass_cmds }list"
agepass_cmd_help_list() {
	echo >&2 "Usage: agepass.sh list"
}
agepass_list() {
	#agepass_reqargs list 0 $# || return $?
	local agepass_dir="$(agepass_dir)"
	[ -d "$agepass_dir/pass" ] &&
	cd "$agepass_dir/pass" && find -type f -name '*.age' -printf %P\\n|
	while read -r line; do
		printf %s\\n "${line%.age}"
	done
}

## exists ##
agepass_cmds="${agepass_cmds:+$agepass_cmds }exists"
agepass_cmd_help_exists() {
	echo >&2 'Usage: agepass.sh exists <entry/path>'
}
agepass_exists() {
	agepass_reqargs exists 1 $# || return $?
	local agepass_dir="$(agepass_dir)"
	local p="$1";shift
	p="$agepass_dir"/pass/"$p"'.age'
	[ -f "$p" ]
}

## get ##
agepass_cmds="${agepass_cmds:+$agepass_cmds }get"
agepass_cmd_help_get() {
	echo >&2 'Usage: agepass.sh get <entry/path>'
}
agepass_get() {
	agepass_reqargs get 1 $# || return $?
	local agepass_dir="$(agepass_dir)"
	local p="$1";shift
	p="$agepass_dir"/pass/"$p"'.age'
	if [ ! -f "$p" ]; then
		echo >&2 "$p: no such file"
		return 1
	fi
	cat "$p" | age -d -i "$agepass_dir/secrets/age.key"
}

## set ##
agepass_cmds="${agepass_cmds:+$agepass_cmds }set"
agepass_cmd_help_set() {
	echo >&2 'Usage: echo '\''value'\'' | agepass.sh set <entry/path>'
}
agepass_set() {
	agepass_reqargs set 1 $# || return $?
	local agepass_dir="$(agepass_dir)"
	local p="$1";shift
	case "$p" in
	(*'..'*) echo >&2 "ERROR: .. not allowed";return 1;;
	(/*) echo >&2 "ERROR: must be a relative path";return 2;;
	esac
	p="$agepass_dir"/pass/"$p"'.age'
	if [ -f "$p" ]; then
		echo >&2 "$key: already exists"
		return 2
	fi
	local d="$(dirname "$p")"
	[ -d "$d" ] || mkdir -p -- "$d"
	cat | age -a -R "$agepass_dir/secrets/recipients.pub" > "$p"
}

## unset ##
agepass_cmds="${agepass_cmds:+$agepass_cmds }unset"
agepass_cmd_help_unset() {
	echo >&2 'Usage: agepass.sh unset <entry/path>'
}
agepass_unset() {
	agepass_reqargs unset 1 $# || return $?
	local agepass_dir="$(agepass_dir)"
	local p="$1";shift
	case "$p" in
	(*'..'*) echo >&2 "ERROR: .. not allowed";return 1;;
	(/*) echo >&2 "ERROR: must be a relative path";return 2;;
	esac
	p="$agepass_dir"/pass/"$p"'.age'
	if [ ! -f "$p" ]; then
		echo >&2 "$p: no such file"
		return 1
	fi
	rm -- "$p"
}

## help ##
agepass_cmds2="${agepass_cmds2:+$agepass_cmds2 }help"
agepass_help() {
	if [ -n "$1" ]; then
		if ! command >/dev/null 2>&1 -v "agepass_cmd_help_$1"; then
			echo >&2 "$0: ERROR: unknown command $1"
			return 1
		fi
		"agepass_cmd_help_$1"
		return $?
	fi
	echo 'Usage: '"$0"' [help] '"$(echo "$agepass_cmds"| tr \  \|)"' [args]'
}
agepass_cmd_help_help() {
	echo >&2 'Usage: agepass.sh help '"$(echo "$agepass_cmds"| tr \  \|)"''
}
agepass_cmd_help_all() {
	echo >&2 'Usage: agepass.sh help '"$(echo "$agepass_cmds $agepass_cmds2"| tr \  \|)"''
}
agepass_cmd_help_xtra() {
	echo >&2 'Usage: agepass.sh help '"$(echo "$agepass_cmds2"| tr \  \|)"''
}


## (internal) ##
# build command wrapper functions
for cmd in $agepass_cmds $agepass_cmds2; do
	#if command >/dev/null 2>&1 -v 'agepass_'"${cmd}"; then
	eval 'agepass_cmd_'"${cmd}"'() { agepass_'"${cmd}"' "$@"; }'
	#fi
done


agepass() {
	agepass_reqargs "" 1 $# || return $?
	local cmd="$1";shift
	if ! command >/dev/null 2>&1 -v "agepass_cmd_$cmd"; then
		echo >&2 "$0: ERROR: unknown command $cmd"
		return 1
	fi
	"agepass_cmd_${cmd}" "$@"
}
agepass "$@"
