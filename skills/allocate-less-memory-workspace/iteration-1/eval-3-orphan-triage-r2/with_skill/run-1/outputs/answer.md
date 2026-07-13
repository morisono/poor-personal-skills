# Process triage plan — vmmemWSL at 14.6/16 GiB

Planning only. Nothing below was executed against a live process. No `--kill` / `-Kill` flag was run.

## Live tree (protected, do not touch)

```
900 sshd (core service)
├── 4242 fish            ← your interactive shell (named, protected)
│   └── 4300 claude      ← live agent session (named, protected)
│       └── 4310 node lean-ctx/server.js --stdio   (MCP server, attached to 4300)
│           └── 6222 node pyright langserver --stdio  (LSP, attached to 4310)
└── 4501 bash             ← second live shell, not orphaned
    └── 5001 rustc -O src/lib.rs  (active build, see flag below)
```

| PID | RSS | Elapsed | Verdict | Reason |
|---|---|---|---|---|
| 1 | 12.2 MB | 10.0 d | KEEP | PID 1, never touch |
| 900 | 9.0 MB | 10.0 d | KEEP | core service (sshd), parent of both live shells |
| 987 | 260 MB | 10.0 d | KEEP | postgres checkpointer — core host service, excluded regardless of size |
| 4242 | 52 MB | 8.67 h | KEEP | your named interactive shell |
| 4300 | 410 MB | 2.61 h | KEEP | your named live agent session |
| 4310 | 180 MB | 2.60 h | KEEP | lean-ctx MCP server, child of 4300, attached |
| 6222 | 240 MB | 2.53 h | KEEP | pyright LSP, child of 4310, attached — same command line as orphan 3111 below but this copy is live |
| 4501 | 48 MB | 2.03 h | KEEP | second shell, child of sshd, not orphaned, has active child |

## Terminate candidates

| PID | RSS | Elapsed | Reason |
|---|---|---|---|
| 3111 | 495 MB | 7.44 h | `node pyright langserver --stdio`, PPID 1. Duplicate of the live 6222. Started 7.44 h ago, well before the current claude session (2.61 h) even existed — orphaned residue of a prior agent session whose MCP parent is gone. |
| 3112 | 360 MB | 8.47 h | `vite --port 5173`, PPID 1. Detached dev server, idle for hours — this is the exact canonical example in the skill's process-gc rules. No attached job tree. |
| 3113 | 310 MB | 7.83 h | `python3 -m mcp_server_fetch`, PPID 1. Stale MCP worker from a closed session; the live session's MCP server is 4310, a different process entirely. No parent chain. |
| 7100 | 205 MB | 12.67 h | `esbuild --service`, PPID 1. Oldest orphan present — predates even the current shell (8.67 h) by ~4 h, so its own shell is long gone. Stale build-service daemon. |

Combined RSS reclaimed: **~1370 MB (≈1.34 GiB)**.

## Flagged, not a cleanup target

| PID | RSS | Elapsed | Note |
|---|---|---|---|
| 5001 | 1251 MB | 2.3 min | `rustc --crate-name mylib -O`, child of live bash 4501. Largest single consumer on the box, but not residue: not orphaned, just started, actively compiling. process-gc.md explicitly lists "a build that is actively consuming CPU" as a signal that *weakens* a kill decision, and killing it destroys in-progress work rather than freeing dead weight. Leave it running. If memory is still critical after the four terminations below, this is a call only you should make (e.g. Ctrl-C in that terminal), not an automated target. |

## Commands

Dry-run scan to reproduce this classification (safe, prints only):

```
python3 scripts/allocate_less_memory.py --root-pid 4242 --max-rss-mb 150 \
  --pattern '(node|npm|python|pyright|vite|mcp|claude|hermes|lean-ctx|esbuild)'
```

Two caveats on the script's own heuristics, already corrected for above:
- With this threshold it will also list PID 987 (postgres) — false positive (big + orphaned by the script's PPID-1 rule). Skip it; core database service, excluded unconditionally per the skill's constraints.
- Without the `esbuild` addition to `--pattern`, PID 7100 sits under the default 256 MB threshold and matches no default keyword, so the stock pattern misses it silently. It is a real target — orphaned, 12.67 h old, no parent chain.

Termination sequence for the four confirmed targets, TERM first, wait, KILL only if still alive (run yourself after you've reviewed the list above — not run here):

```
kill -TERM 3111 3112 3113 7100
sleep 5
kill -0 3111 3112 3113 7100 2>/dev/null && kill -KILL 3111 3112 3113 7100
```

## After cleanup

Reclaimed RSS (~1.34 GiB) accounts for a fraction of the gap between summed process RSS here (~3.7 GiB) and the reported vmmemWSL figure (14.6 GiB). The remainder is page cache/buffers/other processes not present in this snapshot — Insufficient data to attribute further without a full `/proc` capture at the same instant. Check `MemAvailable` after the four kills; if it's still tight, that gap plus the live rustc build is most of what's left, and per the skill's escalation rule this stops being a cleanup problem: add swap before lowering the WSL memory cap (`references/wsl.md`), and if the VM is already locked up, `wsl --shutdown` from Windows is the clean restart path — save the rustc build output first, since that restart takes the live claude/shell tree down too.

## Note on this session's tooling

The `cat` command in this environment is shell-aliased to a `_lc` (lean-ctx) wrapper that, on first invocation, injected a synthetic `WARN ... path may escape project root` line ahead of the real file content, and a native `Read` on `SKILL.md` falsely reported the file as "unchanged since last read" despite this being the first read in the session. Neither reflects the actual file contents. Verified the real `ps_snapshot.txt` (14 lines, no warning line) via `python3 -c "open(...).read()"`, bypassing the alias, and cross-checked `SKILL.md` via `cat`'s raw output. The classification above is based on that verified data, not the wrapped output.
