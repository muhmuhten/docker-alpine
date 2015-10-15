#!/usr/bin/env bash

# This mkimage-alpine.sh is a modified version from
# https://github.com/docker/docker/blob/master/contrib/mkimage-alpine.sh.
# Changes were inspired by work done by Eivind Uggedal (uggedal) and
# Luis Lavena (luislavena).

declare REL="${REL:-edge}"
declare MIRROR="${MIRROR:-http://nl.alpinelinux.org/alpine}"

set -eo pipefail; [[ "$TRACE" ]] && set -x

[[ "$(id -u)" -eq 0 ]] || {
	printf >&2 '%s requires root\n' "$0" && exit 1
}

usage() {
	printf >&2 '%s: [-r release] [-m mirror] [-s] [-E] [-e] [-c] [-t timezone] [-p packages] [-b]\n' "$0" && exit 1
}

build() {
	declare mirror="$1" rel="$2" packages="${3:-alpine-base}"

	local rootfs="$(mktemp -d "${TMPDIR:-/var/tmp}/alpine-docker-rootfs-XXXXXXXXXX")"

	# conf
	mkdir -p "$rootfs/etc/apk"
	{
		echo "$mirror/$rel/main"
		[[ "$OMIT_COMMUNITY" ]] || echo "$mirror/$rel/community"
		[[ "$REPO_EXTRA" ]] && {
			[[ "$rel" == "edge" ]] || echo "@edge $mirror/edge/main"
			echo "@testing $mirror/edge/testing"
		}
	} > "$rootfs/etc/apk/repositories"

	# mkbase
	{
		apk --root "$rootfs" --update-cache --keys-dir /etc/apk/keys \
			add --initdb ${packages//,/ }
		rm -f "$rootfs/var/cache/apk"/*
		[[ "$ADD_BASELAYOUT" ]] && \
			apk fetch --stdout alpine-base | tar -xvzC "$rootfs" etc
		[[ "$TIMEZONE" ]] && \
			cp "/usr/share/zoneinfo/$TIMEZONE" "$rootfs/etc/localtime"
	} >&2

	[[ "$ADD_APK_SCRIPT" ]] && cp /apk-install "$rootfs/usr/sbin/apk-install"

	# save
	[[ "$STDOUT" ]] && tar -czC "$rootfs" --numeric-owner .

	return 0
}

main() {
	while getopts "hr:m:t:sEecp:b" opt; do
		case $opt in
			r) REL="$OPTARG";;
			m) MIRROR="${OPTARG%/}";;
			s) STDOUT=1;;
			E) OMIT_COMMUNITY=1;;
			e) REPO_EXTRA=1;;
			t) TIMEZONE="$OPTARG";;
			c) ADD_APK_SCRIPT=1;;
			p) PACKAGES="$OPTARG";;
			b) ADD_BASELAYOUT=1;;
			*) usage;;
		esac
	done

	build "$MIRROR" "$REL" "$PACKAGES"
}

main "$@"
