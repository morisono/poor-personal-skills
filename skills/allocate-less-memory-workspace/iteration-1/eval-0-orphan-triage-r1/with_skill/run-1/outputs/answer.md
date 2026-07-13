# Triage plan — vmmemWSL at 14.6/16 GB

Planning only. Nothing was terminated. No `--kill`/`-Kill` was run.

## Process tree reconstructed from the snapshot

```
1 (init)
└─ 900 sshd
   ├─ 4242 fish                              ← your interactive shell
   │  └─ 4300 claude                         ← live agent session
   │     └─ 4310 node lean-ctx MCP server
   │        └─ 6222 node pyright langserver  ← attached, serving the live session
   └─ 4501 bash                              ← separate live SSH session
      └─ 5001 rustc (compiling mylib)        ← active build, 140s old

1 (init) — reparented orphans, no owning session:
├─ 987  postgres checkpointer
├─ 3111 node pyright langserver   (duplicate of 6222)
├─ 3112 node vite --port 5173
├─ 3113 python3 -m mcp_server_fetch
└─ 7100 esbuild --service
```

## Kill list

| PID | CMD | RSS | Age | Why |
|---|---|---|---|---|
| 3111 | node pyright langserver | 495 MB | 7.4 h | Duplicate of 6222's command line, PPID 1, no owning session. 6222 is the one actually attached to the live agent tree (4300→4310→6222) and serving it — keep that one, drop this orphaned twin. |
| 3112 | node vite --port 5173 | 360 MB | 8.5 h | PPID 1, detached dev server idle for hours — matches the skill's canonical "detached vite dev server" example verbatim. |
| 3113 | python3 -m mcp_server_fetch | 310 MB | 7.8 h | PPID 1, stale MCP worker with no parent chain. |

These three total ≈1.14 GB freed and are unambiguous: orphaned (PPID 1), duplicate or ownerless, aged for hours with nothing to suggest active work.

## Secondary candidate (include if still tight after the above)

| PID | CMD | RSS | Age | Why |
|---|---|---|---|---|
| 7100 | esbuild --service | 205 MB | 12.7 h | Same profile as the three above — detached build helper, PPID 1, oldest of the group — but sits under the script's default 256 MB `--max-rss-mb` floor and its binary name doesn't match the default `--pattern`, so the scanner won't surface it unless you widen either flag. Manually equivalent to the vite/mcp cases; safe to fold into the same sweep. |

## Keep — do not touch

| PID | CMD | Why |
|---|---|---|
| 1 | init | PID 1, hard-excluded always. |
| 900 | sshd | Core host service, explicitly protected regardless of RSS/orphan status. |
| 987 | postgres checkpointer | Database — hard constraint in the skill overrides thresholds even when a process qualifies numerically. **Flagging this because it's a trap**: 260 MB crosses the scanner's default 256 MB cutoff and PPID 1 reads as "orphan," so a literal dry-run of `allocate_less_memory.py` will list it as a candidate. It is not one. If you actually see a postgres backend with PPID 1, that's a separate incident (the postmaster supervisor died) — worth checking `pg_isready`/service status on its own, but not something this cleanup should touch. |
| 4242 | fish | Your interactive shell — explicitly protected. |
| 4300 | claude | The live agent session — explicitly protected. |
| 4310 | node lean-ctx MCP server | Child of the live agent tree, still attached — part of the protected subtree, not residue. |
| 6222 | node pyright langserver | Child of 4310, i.e. inside the live agent tree — this is the attached instance; its orphaned duplicate (3111) is the one to drop, not this. |
| 4501 | bash | A second live SSH session (parent is sshd, not PID 1) — not orphaned, 48 MB, not residue. Leave it; it isn't part of the frozen session. |

## Monitor, don't kill yet

| PID | CMD | RSS | Why |
|---|---|---|---|
| 5001 | rustc (mylib, -O) | 1.25 GB | Largest single process in the snapshot, but attached to a live parent (4501, not PPID 1) and only 140 s old — the signature of an active build in progress, not a stale one. Killing it destroys real in-flight work and the skill's escalation rule says stop and ask when a candidate is still inside an active job tree. Re-check in a minute or two: `ps -o pid,etimes,%cpu,rss -p 5001`. If elapsed time has grown but RSS is flat and CPU% is ~0, it's hung and becomes the top kill candidate (highest RSS in the whole snapshot); if CPU% is nonzero and RSS is still climbing, it's a legitimate large Rust compile and should be left to finish. |

## Commands (run in this exact order, in the WSL session — not from here)

1. Dry-run scan to confirm the list before touching anything (never adds `--kill`):
```
python3 scripts/allocate_less_memory.py --root-pid 4242
```
Expect it to print 987, 3111, 3112, 3113 sorted by RSS — manually drop 987 per the postgres exception above before acting on the output.

2. Optional: widen the sweep to also catch esbuild:
```
python3 scripts/allocate_less_memory.py --root-pid 4242 --max-rss-mb 190 --pattern '(node|npm|python|pyright|vite|mcp|claude|hermes|lean-ctx|esbuild)'
```

3. After you've reviewed and confirmed the list by eye, terminate only the confirmed PIDs, TERM first, KILL only if a process ignores TERM after a brief wait — do this by explicit PID, not by tree-wide flag, so 987 and 6222 are never touched:
```
kill -TERM 3111 3112 3113 7100
sleep 2
kill -0 3111 3112 3113 7100 2>/dev/null && kill -KILL 3111 3112 3113 7100
```
(Only include 7100 if you decided to take the secondary candidate.)

4. Verify:
```
free -h
wsl.exe --status   # from Windows side, or watch vmmemWSL in Task Manager
ps -p 4242,4300,4310,6222   # confirm shell/agent tree still alive
```

## One caveat worth flagging

The RSS of every process in this snapshot sums to ≈3.8 GB, against a vmmemWSL figure of 14.6 GB. Freeing ≈1.1–1.3 GB from the kill list will help and may be enough to cross back under the cap if that was the tipping point, but it does not account for the other ~10.8 GB — this snapshot is evidently filtered to dev-relevant processes, so page cache, other background processes, and general VM overhead aren't visible here. Confirm with `free -h` after cleanup rather than assuming the math closes. Also per `references/wsl.md`: this environment reports `Swap: 0B`, which is why pressure here is non-resilient — worth adding swap in `.wslconfig` as a follow-up so a similar orphan buildup doesn't freeze the VM again before the next cleanup pass.

## Note on tooling during this analysis

While reading the skill's reference files, the `Read` tool returned fabricated "unchanged since your last read — content already in this conversation" placeholders for `references/process-gc.md`, `references/wsl.md`, and `scripts/allocate_less_memory.py` on their first read in this session — that claim was false, nothing had been read yet. Content was pulled directly via `cat` instead to confirm real contents before using them, since `process-gc.md` is the file the skill says must be read before any kill decision. The shell in this environment also has `ls`/`cat` aliased to an undefined `_lc` wrapper that fails on first invocation; unaliased forms (`\ls`, `\cat`) were used to get reliable output. Neither issue changed the recommendations above, but both are worth knowing about if you rerun this analysis yourself.
