# Process triage — vmmemWSL 14.6/16 GB

Analysis is dry-run only. No process was touched, no script was invoked with a kill flag.

## Verdict table

| PID | PPID | RSS | Elapsed | CMD | Verdict | Reason |
|---|---|---|---|---|---|---|
| 1 | 0 | 12 MB | 10d | /sbin/init | keep | PID 1, host root |
| 900 | 1 | 9 MB | 10d | sshd -D | keep | network daemon, parent of both shells |
| 987 | 1 | 260 MB | 10d | postgres: 15/main: checkpointer | keep | system/database service, same age as boot, out of session scope — data risk if touched |
| 4242 | 900 | 52 MB | 8h40m | fish | keep | stated interactive shell |
| 4300 | 4242 | 410 MB | 2h37m | claude | keep | stated live agent session |
| 4310 | 4300 | 180 MB | 2h36m | node lean-ctx/server.js --stdio | keep | direct child of the live agent, started 50s after it — attached MCP helper |
| 6222 | 4310 | 240 MB | 2h32m | node pyright langserver --stdio | keep | grandchild of the live agent through 4310 — attached language server, not orphaned |
| 3111 | 1 | 495 MB | 7h27m | node pyright langserver --stdio | **terminate** | duplicate of 6222's command line, PPID 1, predates the current claude session by ~5h — orphaned residue from an earlier session |
| 3112 | 1 | 360 MB | 8h28m | vite --port 5173 | **terminate** | PPID 1, started near session-shell launch but has no parent job tree — detached dev server |
| 3113 | 1 | 310 MB | 7h50m | python3 -m mcp_server_fetch | **terminate** | PPID 1, MCP worker with no parent chain, not referenced by the live session |
| 7100 | 1 | 205 MB | 12h40m | esbuild --service | **terminate** | PPID 1, oldest orphan in the set, persistent build service left behind by a dead parent |
| 4501 | 900 | 48 MB | 2h02m | bash | keep | interactive shell, never a target regardless of children |
| 5001 | 4501 | 1.22 GB | 140s | rustc --crate-name mylib -O | keep (monitor) | largest single RSS in the snapshot, but 140s old — active `-O` compile, not stale; killing destroys in-progress work |

## Why the terminate set and not others

3111/3112/3113/7100 share every kill signal from `process-gc.md`: parent is 1, command matches a known helper/dev-server pattern, aged for hours with no owning session, and in 3111's case a live duplicate (6222) already covers the same role inside the attached tree. None of them sit inside the process tree rooted at 4300, so removing them does not touch the shell or the agent.

6222 looks identical to 3111 by command line but is kept because it is reachable from 4300 → 4310 → 6222 — an unbroken parent chain to the session you want to keep. That is the deciding signal, not RSS.

5001 has the single highest RSS (1.22 GB) but fails every kill signal except "RSS dominates the budget": it is 140 seconds old, its parent (4501) is a live interactive shell, and the command line is a real compile, not a helper/server pattern. Per the skill's own example, an active heavy process is not a cleanup target unless nothing else relieves the pressure. Reclaiming the four orphans first (~1.34 GB) is the bounded move; revisit 5001/4501 only if `vmmemWSL` is still pinned after that and the build has stalled (elapsed grows with no CPU progress).

987 (postgres checkpointer) is left alone on principle: it is a database process, its age matches boot time not session time, and `process-gc.md` keeps system services and network daemons by default. If it turns out to be unwanted, that is a separate decision outside this triage, not a memory-pressure kill.

## Commands (for you to run — not run by me)

Optional read-only confirmation before acting, scoped so the live tree is auto-protected:

```
python3 scripts/allocate_less_memory.py --root-pid 4300 --max-rss-mb 150
```

Escalation per `thresholds.md` — TERM first, wait, KILL only on holdouts:

```
kill -TERM 3111 3112 3113 7100
sleep 3
ps -o pid,stat,etime,cmd -p 3111,3112,3113,7100
```

For any PID still listed after the check above:

```
kill -KILL <remaining-pid>
```

## If pressure persists after cleanup

Terminating the four orphans frees roughly 1.34 GB RSS (495+360+310+205 MB), against a VM sitting at 14.6/16 GB — a partial fix, not a full one, since `vmmemWSL` also covers cache and kernel overhead outside this process list. Per `wsl.md`: check `Swap:` in `/proc/meminfo` inside the WSL instance — `0B` swap means the remaining headroom is non-resilient and a second spike will hit the cap again. Add swap in `.wslconfig` before lowering the memory cap further. Keep the 4242/4300/4310/6222 tree attached throughout — do not `wsl --shutdown` while triage is in progress, since that also drops the live agent session.
