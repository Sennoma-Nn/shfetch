#!/bin/sh

set -eu

ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
SHFETCH=$ROOT/main.sh

sh -n "$SHFETCH"

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

if sh "$SHFETCH" --does-not-exist >/dev/null 2>&1; then
    echo 'unknown option unexpectedly succeeded' >&2
    exit 1
fi

echo 'ok'
