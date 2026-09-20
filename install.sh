#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
if [ -n "${PREFIX:-}" ]; then
    PREFIX=$PREFIX
elif [ -n "${HOME:-}" ]; then
    PREFIX=$HOME/.local
else
    PREFIX=/usr/local
fi
DESTDIR=${DESTDIR:-}
DRY_RUN=0

die() {
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

require_command() {
    command -v "$1" > /dev/null 2>&1 || die "required command not found: $1"
}

usage() {
    printf '%s\n' \
        "Usage: $0 [options]" \
        "" \
        "  -p, --prefix DIR   installation prefix (default: $PREFIX)" \
        "      --dry-run     show actions without changing files" \
        "  -h, --help        show this help" \
        "" \
        "DESTDIR can be used for packaging staged installations."
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -p|--prefix)
            [ "$#" -ge 2 ] || { printf 'Error: %s requires a directory\n' "$1" >&2; exit 1; }
            PREFIX=$2
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
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

require_command install
require_command mkdir
[ -r "$SCRIPT_DIR/main.sh" ] || die "main.sh not found"
[ -d "$SCRIPT_DIR/logos" ] || die "logos directory not found"

case "$DESTDIR" in
    /) DESTDIR='' ;;
    */) DESTDIR=${DESTDIR%/} ;;
esac

BIN_DIR=$DESTDIR$PREFIX/bin
LOGO_DIR=$DESTDIR$PREFIX/share/shfetch/logos

install_logo() {
    logo=$1
    target=$LOGO_DIR/${logo##*/}
    if [ "$DRY_RUN" -eq 1 ]; then
        printf 'Would install %s -> %s\n' "$logo" "$target"
    else
        install -m 644 "$logo" "$target"
    fi
}

if [ "$DRY_RUN" -eq 1 ]; then
    printf 'Would create %s\n' "$BIN_DIR"
    printf 'Would create %s\n' "$LOGO_DIR"
    printf 'Would install %s -> %s\n' "$SCRIPT_DIR/main.sh" "$BIN_DIR/shfetch"
else
    mkdir -p "$BIN_DIR" "$LOGO_DIR"
    install -m 755 "$SCRIPT_DIR/main.sh" "$BIN_DIR/shfetch"
fi

for logo in "$SCRIPT_DIR"/logos/*.txt; do
    [ -f "$logo" ] || continue
    install_logo "$logo"
done

if [ "$DRY_RUN" -eq 1 ]; then
    printf 'Dry run complete\n'
else
    printf 'Installed shfetch to %s\n' "$BIN_DIR/shfetch"
    printf 'Logo assets installed to %s\n' "$LOGO_DIR"
fi
