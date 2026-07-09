#!/bin/sh
# analyze.sh — report filesystem usage and top disk consumers. Read-only.
# Usage: analyze.sh [-n TOP] [PATH]
#   PATH defaults to $HOME. -n sets number of entries per section (default 15).

set -eu

TOP=15
while getopts n:h opt; do
    case "$opt" in
        n) TOP=$OPTARG ;;
        h) grep '^# ' "$0" | cut -c3-; exit 0 ;;
        *) exit 2 ;;
    esac
done
shift $((OPTIND - 1))
ROOT=${1:-"$HOME"}

echo "== Filesystems =="
df -hP | awk 'NR==1 || $1 ~ /^\// {print}'

echo ""
echo "== Largest directories under $ROOT (depth 3) =="
# -x: stay on one filesystem; -k for portable units, converted to MiB.
du -xk -d 3 "$ROOT" 2>/dev/null | sort -rn | head -n "$TOP" | \
    awk '{printf "%8.1f MiB  ", $1/1024; $1=""; sub(/^ /,""); print}'

echo ""
echo "== Largest files under $ROOT =="
find "$ROOT" -xdev -type f -size +100M 2>/dev/null -exec ls -l {} + | \
    sort -k5 -rn | head -n "$TOP" | \
    awk '{printf "%8.1f MiB  %s\n", $5/1048576, $NF}'

echo ""
echo "== Known cache locations =="
for d in \
    "$HOME/.cache" \
    "$HOME/.npm" \
    "$HOME/.cargo/registry" \
    "$HOME/.m2/repository" \
    "$HOME/.gradle/caches" \
    "$HOME/.local/share/Trash" \
    /var/cache/apt /var/cache/dnf /var/cache/pacman/pkg \
    /var/log; do
    [ -d "$d" ] || continue
    du -sk "$d" 2>/dev/null | awk '{printf "%8.1f MiB  %s\n", $1/1024, $2}'
done

if command -v docker >/dev/null 2>&1; then
    echo ""
    echo "== Docker =="
    docker system df 2>/dev/null || echo "(docker daemon not reachable)"
fi

if command -v journalctl >/dev/null 2>&1; then
    echo ""
    echo "== journald =="
    journalctl --disk-usage 2>/dev/null || true
fi
