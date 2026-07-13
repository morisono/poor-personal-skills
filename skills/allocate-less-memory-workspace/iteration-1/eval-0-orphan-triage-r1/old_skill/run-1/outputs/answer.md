# WSL memory triage — plan only, nothing executed

Source: `fixtures/ps_snapshot.txt`. `vmmemWSL` 14.6 GB / 16 GB cap (91%). Protected roots per your message: shell PID 4242, live agent PID 4300.

## Verdict table

| PID | PPID | RSS | Age | Verdict | Reason |
|---|---|---|---|---|---|
| 1 | 0 | 12.2 MB | 10.0 d | KEEP | PID 1, init, never a target |
| 900 | 1 | 9.0 MB | 10.0 d | KEEP | sshd, network daemon, parent of both login shells |
| 987 | 1 | 260.0 MB | 10.0 d | KEEP — flag | postgres checkpointer. Core DB service, excluded from cleanup scope by policy. `ppid=1` with no postmaster row in this snapshot is unusual (checkpointer normally reports to the postmaster, not init) — either it was reparented after the postmaster exited, or the snapshot simply omits that row. Insufficient data to conclude a crash. Do not signal it from a memory-triage pass; check separately with `pg_ctl status` / `systemctl status postgresql` |
| 4242 | 900 | 52.0 MB | 8.7 h | KEEP | your interactive shell, explicitly protected |
| 4300 | 4242 | 410.0 MB | 2.6 h | KEEP | your live agent session, explicitly protected. A frozen session is a symptom of the orphans below starving the VM, not a reason to kill the session itself |
| 4310 | 4300 | 180.0 MB | 2.6 h | KEEP | lean-ctx MCP server, child of the live agent, started 50 s after it — attached, active |
| 6222 | 4310 | 240.0 MB | 2.5 h | KEEP | pyright language server, child of the lean-ctx MCP, started 250 s after it — attached to the live tree, this is the one actually serving your session |
| 3111 | 1 | 495.0 MB | 7.4 h | **TERMINATE** | identical command line to 6222 (pyright langserver) but `ppid=1`, predates the live session by ~17,400 s. Orphaned duplicate with no attached job tree — the exact "duplicate helper, parent gone" pattern |
| 3112 | 1 | 360.0 MB | 8.5 h | **TERMINATE** | vite dev server, `ppid=1`, no shell above it, older than the live session. Detached dev server with no parent — textbook orphan |
| 3113 | 1 | 310.0 MB | 7.8 h | **TERMINATE** | `mcp_server_fetch`, `ppid=1`, no parent chain, predates the live session by hours. Stale MCP worker |
| 7100 | 1 | 205.0 MB | 12.7 h | TERMINATE (secondary) | esbuild `--service`, `ppid=1`, oldest orphan in the snapshot, no client attached (its likely caller, the vite process above, is itself orphaned). Below the script's default 256 MB auto-threshold and outside its regex, so a blind scan misses it — flagged here on orphan age/parentage instead of RSS |
| 4501 | 900 | 48.0 MB | 2.0 h | KEEP | separate login shell (bash), `ppid=900` not `1` — live, not orphaned, parent of the build below |
| 5001 | 4501 | 1251.0 MB | 2.3 min | KEEP — monitor | rustc, largest single RSS in the snapshot, but not orphaned (parent is the live bash 4501) and only 140 s old — reads as an active compile, not residue. No CPU% column in this snapshot, so "still making progress" is an assumption, not a confirmed fact. Re-check after the terminations below; if `vmmemWSL` is still pinned and this PID's elapsed time keeps climbing with flat RSS, reclassify as a stuck build and reconsider |

## Recovered memory if the four TERMINATE targets are cleared

495.0 + 360.0 + 310.0 + 205.0 = 1370 MB ≈ 1.34 GB, roughly 8–9% of the 16 GB cap.

## Commands (run these yourself — not executed here)

TERM first, wait, escalate to KILL only for survivors, per the skill's kill-order rule:

```sh
for pid in 3111 3112 3113 7100; do kill -TERM "$pid"; done
sleep 5
for pid in 3111 3112 3113 7100; do
  kill -0 "$pid" 2>/dev/null && kill -KILL "$pid"
done
```

Verify afterward:

```sh
ps -o pid,ppid,rss,etimes,cmd -p 3111,3112,3113,7100 2>/dev/null   # should print nothing
free -h                                                            # confirm MemAvailable recovered
```

From Windows, if `vmmemWSL` is still near the cap after the above (rustc build finishes or turns out stuck):

```powershell
wsl --shutdown
```

Only as a last resort — it drops the live agent session (4300) and the fish shell (4242) too, so it should follow, not replace, the targeted cleanup above.

## Not recommended

Do not signal 4300 (live agent) or 4242 (shell) — both are explicitly protected session roots. Do not signal 987 (postgres) — core DB service, out of this skill's scope, and its unusual parentage needs a database-side check, not a kill. Do not signal 5001 (rustc) yet — no orphan/duplicate/staleness signal present, only high RSS on an apparently active, freshly started build.
