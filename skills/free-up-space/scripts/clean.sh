#!/bin/sh
# clean.sh — reclaim space from reproducible data only. Dry-run by default.
# Usage: clean.sh [--apply] [--targets LIST]
#   --apply          actually delete; without it, only report what would happen
#   --targets LIST   comma-separated subset: pkg,journal,trash,docker,pip,npm
# Never touches user documents. Every action is printed before it runs.

set -eu

APPLY=0
TARGETS="pkg,journal,trash,docker,pip,npm"
while [ $# -gt 0 ]; do
    case "$1" in
        --apply) APPLY=1 ;;
        --targets) TARGETS=$2; shift ;;
        -h|--help) grep '^# ' "$0" | cut -c3-; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

has_target() { case ",$TARGETS," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }

run() {
    if [ "$APPLY" -eq 1 ]; then
        echo ">> $*"
        "$@" || echo "   (failed, continuing)" >&2
    else
        echo "would run: $*"
    fi
}

size_of() { [ -d "$1" ] && du -sk "$1" 2>/dev/null | awk '{printf "%.1f MiB", $1/1024}' || echo "0"; }

[ "$APPLY" -eq 1 ] || echo "DRY RUN — pass --apply to execute."
echo ""

if has_target pkg; then
    if command -v apt-get >/dev/null 2>&1; then
        echo "[pkg] apt cache: $(size_of /var/cache/apt)"
        run sudo apt-get clean
        run sudo apt-get autoremove --purge -y
    fi
    command -v dnf >/dev/null 2>&1 && run sudo dnf clean all
    command -v paccache >/dev/null 2>&1 && run sudo paccache -rk2
    command -v brew >/dev/null 2>&1 && run brew cleanup --prune=all
    command -v flatpak >/dev/null 2>&1 && run flatpak uninstall --unused -y
fi

if has_target journal && command -v journalctl >/dev/null 2>&1; then
    echo "[journal] $(journalctl --disk-usage 2>/dev/null || echo 'n/a')"
    run sudo journalctl --vacuum-size=200M
fi

if has_target trash && [ -d "$HOME/.local/share/Trash/files" ]; then
    echo "[trash] $(size_of "$HOME/.local/share/Trash")"
    run rm -rf "$HOME/.local/share/Trash/files" "$HOME/.local/share/Trash/info"
fi

if has_target docker && command -v docker >/dev/null 2>&1; then
    docker system df 2>/dev/null || true
    # No -a: keeps tagged images. Volumes untouched — they may hold unique data.
    run docker system prune -f
    run docker builder prune -f
fi

if has_target pip && command -v pip >/dev/null 2>&1; then
    run pip cache purge
fi

if has_target npm && command -v npm >/dev/null 2>&1; then
    run npm cache clean --force
fi

echo ""
if [ "$APPLY" -eq 1 ]; then
    df -hP | awk 'NR==1 || $1 ~ /^\// {print}'
else
    echo "Nothing was deleted. Review the list, then rerun with --apply."
fi
