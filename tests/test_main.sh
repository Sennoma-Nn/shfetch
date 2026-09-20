#!/bin/sh

set -eu

ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
SHFETCH=$ROOT/main.sh
INSTALL=$ROOT/install.sh

sh -n "$SHFETCH" "$INSTALL"

version=$(sh "$SHFETCH" --version)
printf '%s\n' "$version" | grep -q '^shfetch '

logos=$(sh "$SHFETCH" --list-logos)
printf '%s\n' "$logos" | grep -qw ubuntu
printf '%s\n' "$logos" | grep -qw freebsd
printf '%s\n' "$logos" | grep -qw openbsd
printf '%s\n' "$logos" | grep -qw netbsd
printf '%s\n' "$logos" | grep -qw windows
if printf '%s\n' "$logos" | grep -qw default; then
    echo 'fallback logo leaked into public logo list' >&2
    exit 1
fi

help=$(sh "$SHFETCH" --help)
printf '%s\n' "$help" | grep -q -- '--plain'

plain=$(TERM=dumb sh "$SHFETCH" --plain)
printf '%s\n' "$plain" | grep -q 'SYSTEM'
printf '%s\n' "$plain" | grep -q 'HOST'

external_plain=$(cd /tmp && TERM=dumb sh "$SHFETCH" --plain -l freebsd)
printf '%s\n' "$external_plain" | grep -q "FreeBSD\|SYSTEM"

install_root=$(mktemp -d)
trap 'rm -rf "$install_root"' EXIT HUP INT TERM
PREFIX="$install_root" sh "$INSTALL"
installed_plain=$(TERM=dumb "$install_root/bin/shfetch" --plain -l openbsd)
printf '%s\n' "$installed_plain" | grep -q 'SYSTEM'

if sh "$SHFETCH" --does-not-exist >/dev/null 2>&1; then
    echo 'unknown option unexpectedly succeeded' >&2
    exit 1
fi

echo 'ok'
