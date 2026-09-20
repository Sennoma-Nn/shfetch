#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
PREFIX=${PREFIX:-"${HOME:-/usr/local}/.local"}

usage() {
    printf '%s\n' \
        "Usage: $0 [--prefix DIR]" \
        "" \
        "Installs shfetch to DIR/bin and its logos to DIR/share/shfetch/logos." \
        "Default: $PREFIX"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -p|--prefix)
            [ "$#" -ge 2 ] || { printf 'Error: %s requires a directory\n' "$1" >&2; exit 1; }
            PREFIX=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Error: unknown option: %s\n' "$1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

BIN_DIR=$PREFIX/bin
LOGO_DIR=$PREFIX/share/shfetch/logos

mkdir -p "$BIN_DIR" "$LOGO_DIR"
install -m 755 "$SCRIPT_DIR/main.sh" "$BIN_DIR/shfetch"

for logo in "$SCRIPT_DIR"/logos/*.txt; do
    [ -f "$logo" ] || continue
    install -m 644 "$logo" "$LOGO_DIR/$(basename "$logo")"
done

printf 'Installed shfetch to %s\n' "$BIN_DIR/shfetch"
printf 'Logo assets installed to %s\n' "$LOGO_DIR"
