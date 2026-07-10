#!/usr/bin/env sh
# Scan (default) or trim stale memory-heavy dev helpers.
# Candidate rule: matches --pattern AND (RSS >= --max-rss-mb OR orphaned, PPID 1);
# non-matching processes qualify only when both big AND orphaned.
# Protected always: PID 1, this shell, shells, --root-pid and its whole tree.
set -eu

DRY_RUN=1
MAX_RSS_MB=256
ROOT_PID=""
# Trailing guard stops substring hits, e.g. "node" inside the "nodev" mount flag.
PATTERN='(node|npm|python|pyright|vite|mcp|claude|hermes|lean-ctx)([^a-z]|$)'

while [ "$#" -gt 0 ]; do
  case "$1" in
    --kill) DRY_RUN=0 ;;
    --dry-run) DRY_RUN=1 ;;
    --max-rss-mb) MAX_RSS_MB="${2:?}"; shift ;;
    --root-pid) ROOT_PID="${2:?}"; shift ;;
    --pattern) PATTERN="${2:?}"; shift ;;
    *) echo "usage: $0 [--dry-run|--kill] [--max-rss-mb N] [--root-pid PID] [--pattern REGEX]" >&2; exit 2 ;;
  esac
  shift
done

# Single snapshot so the list shown and the list killed are identical.
SNAPSHOT=$(ps -eo pid=,ppid=,rss=,etimes=,cmd=)

select_candidates() {
  # $1 = "list" (human table) or "pids" (kill input)
  printf '%s\n' "$SNAPSHOT" | awk -v max_mb="$MAX_RSS_MB" -v root="$ROOT_PID" \
    -v pat="$PATTERN" -v self="$$" -v mode="$1" '
    $1 ~ /^[0-9]+$/ {
      pid=$1; ppid=$2; rss=$3; et=$4;
      cmd=""; for(i=5;i<=NF;i++) cmd=cmd $i (i<NF?" ":"");
      P[pid]=ppid; R[pid]=rss; E[pid]=et; C[pid]=cmd;
    }
    END {
      if (root != "") {
        tree[root]=1; changed=1
        while (changed) {
          changed=0
          for (p in P) if (!(p in tree) && (P[p] in tree)) { tree[p]=1; changed=1 }
        }
      }
      for (p in P) {
        if (p==1 || p==self || p in tree) continue
        cmd=C[p]
        if (cmd ~ /(^|\/|[[:space:]])(bash|sh|zsh|fish|pwsh|powershell)([[:space:]]|$)/) continue
        big = (R[p]/1024.0 >= max_mb)
        orphan = (P[p]==1)
        if (cmd ~ pat) cand = (big || orphan); else cand = (big && orphan)
        if (!cand) continue
        if (mode=="pids") print p
        else printf "%s  %.1f  %s  %s  %s\n", p, R[p]/1024.0, P[p], E[p], cmd
      }
    }'
}

printf '%s\n' "PID  RSS_MB  PPID  ELAPSED_S  CMD"
select_candidates list | sort -k2,2nr

if [ "$DRY_RUN" -eq 1 ]; then
  exit 0
fi

CANDS=$(select_candidates pids)
for pid in $CANDS; do
  kill -TERM "$pid" 2>/dev/null || true
done
sleep 2
for pid in $CANDS; do
  kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null || true
done
