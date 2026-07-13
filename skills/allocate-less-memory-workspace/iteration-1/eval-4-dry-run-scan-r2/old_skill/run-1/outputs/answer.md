# Dry-run memory scan — allocate-less-memory skill

Scan only. No `--kill` flag used. No process terminated.

## Exact command

```sh
SCRIPT="/mnt/c/Users/gemjin/Downloads/skills/poor-personal-skills/skills/allocate-less-memory-workspace/skill-snapshot/scripts/allocate_less_memory.sh"
ROOT_PID=$$
sh "$SCRIPT" --dry-run --max-rss-mb 300 --root-pid "$ROOT_PID"
```

`$ROOT_PID` resolved to `26291` (PID of the shell that ran the scan). `--root-pid` protects that PID and its direct children from ever appearing as candidates, in addition to the script's built-in protections (PID 1, and any `bash|sh|zsh|fish|pwsh|powershell` command).

## Exact output

```
PID  RSS_MB  PPID  ELAPSED  CMD
```

Exit code: `0`. Header only, zero candidate rows.

## Why zero candidates, despite large processes on the box

The script's default `--pattern` is:

```
(node|npm|python|pyright|vite|mcp|claude|hermes|lean-ctx)
```

Any process whose command line matches this pattern is marked `keep=1` and excluded from candidacy, regardless of RSS. A read-only `ps -eo pid,ppid,rss,etimes,cmd --sort=-rss` snapshot taken alongside the scan shows several processes above the 300 MB threshold that fall under this exclusion, for example:

| PID | RSS | ELAPSED | CMD |
|---|---|---|---|
| 6568 | ~530 MB | 687 | `claude --dangerously-skip-permissions` |
| 2018 | ~527 MB | 935 | `claude --dangerously-skip-permissions --continue` |
| 3662 | ~504 MB | 844 | `claude --dangerously-skip-permissions --continue` |
| 30797 | ~403 MB | 14 | `claude -p ...` |
| 30603 | ~401 MB | 14 | `claude -p ...` |
| 31431 | ~400 MB | 11 | `claude -p ...` |
| 519 | ~322 MB | 988 | `/home/sana/.hermes/hermes-agent/venv/bin/python -m hermes_cli.main gateway run` |
| 29860 | ~315 MB | 20 | `npm exec flow-nexus@latest mcp start` |
| 11865 | ~122 MB | 267 | `node .../pyright/dist/langserver...` (below 300 MB, shown for context) |

Plus a long tail of `npm exec flow-nexus@latest mcp start` and `npm exec ruflo@latest mcp start` processes in the 120–130 MB range (below the 300 MB threshold individually).

This is expected behavior of the script as written, not a scan failure: the default pattern is a safety allowlist for common agent/dev-tool names, so `claude`, `npm ... mcp start`, `pyright`, and `hermes` processes are never surfaced as termination candidates unless `--pattern` is narrowed. To actually see stale `node`/`python`/language-server helpers as candidates, the scan would need to be rerun with a tighter `--pattern` that no longer blanket-protects those names — not done here, since the task was scan-only with the skill's default thresholds.

## Safety confirmation

No `--kill` flag was passed at any point. No process was signaled (`kill -TERM`/`kill -KILL` code paths in the script were never reached — the script exits after the report when `DRY_RUN=1`, which is the default and was reinforced explicitly with `--dry-run`).
