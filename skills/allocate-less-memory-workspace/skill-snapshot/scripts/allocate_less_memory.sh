#!/usr/bin/env sh
set -eu

DRY_RUN=1
MAX_RSS_MB=256
ROOT_PID=""
PATTERN='(node|npm|python|pyright|vite|mcp|claude|hermes|lean-ctx)'

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

printf '%s\n' "PID  RSS_MB  PPID  ELAPSED  CMD"
ps -eo pid=,ppid=,rss=,etimes=,cmd= | awk -v max_mb="$MAX_RSS_MB" -v root="$ROOT_PID" -v pat="$PATTERN" '
  function mb(x){ return x/1024.0 }
  $1 ~ /^[0-9]+$/ {
    pid=$1; ppid=$2; rss=$3; et=$4;
    cmd=""; for(i=5;i<=NF;i++) cmd=cmd $i (i<NF?" ":"");
    keep=0
    if (pid==1 || cmd ~ /(^|[[:space:]])(bash|sh|zsh|fish|pwsh|powershell)([[:space:]]|$)/) keep=1
    if (root != "" && (pid==root || ppid==root)) keep=1
    if (cmd ~ pat) keep=1
    if (mb(rss) >= max_mb && keep==0) {
      printf "%s  %.1f  %s  %s  %s\n", pid, mb(rss), ppid, et, cmd
    }
  }
' | sort -k2,2nr

if [ "$DRY_RUN" -eq 1 ]; then
  exit 0
fi

cands=$(ps -eo pid=,ppid=,rss=,cmd= | awk -v max_mb="$MAX_RSS_MB" -v root="$ROOT_PID" -v pat="$PATTERN" '
  function mb(x){ return x/1024.0 }
  $1 ~ /^[0-9]+$/ {
    pid=$1; ppid=$2; rss=$3; cmd=""; for(i=4;i<=NF;i++) cmd=cmd $i (i<NF?" ":"");
    keep=0
    if (pid==1) keep=1
    if (root != "" && (pid==root || ppid==root)) keep=1
    if (cmd ~ pat) keep=1
    if (mb(rss) >= max_mb && keep==0) print pid
  }
')

for pid in $cands; do
  kill -TERM "$pid" 2>/dev/null || true
 done
sleep 2
for pid in $cands; do
  kill -KILL "$pid" 2>/dev/null || true
 done
