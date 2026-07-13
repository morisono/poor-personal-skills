## Verdict

Risky as stated. The number 6GB isn't the main problem — pairing a hard `memory=` ceiling with `swap=0` is. With no swap, once the VM hits 6GB the Linux OOM killer inside WSL starts terminating processes abruptly (pyright, vite, an MCP server, possibly the Claude Code session itself) instead of degrading gracefully. You'd trade "Windows host starved by vmmemWSL" for "WSL VM randomly kills my tools," which is generally worse because failures are silent and unpredictable rather than just slow.

## Why swap=0 changes the risk profile

WSL2's own memory model has no cushion once `swap=0`: the VM either has free pages or it doesn't, and when it doesn't, reclaim happens by killing. Swap is disk-backed (`%UserProfile%\AppData\Local\Temp\swap.vhdx` by default), so enabling it costs disk space and some I/O latency under pressure, not RAM — a fair trade against outright process kills. _Ref: https://learn.microsoft.com/en-us/windows/wsl/wsl-config_

Microsoft's own default for `.wslconfig` is `swap` = 25% of assigned `memory`, rounded up to the nearest GB, and default `memory` is 50% of total host RAM (so on a 32GB laptop the unconfigured default is ~16GB VM memory, ~4GB swap). Landing on 6GB memory / 0 swap is a large deviation from that default pairing in both directions. _Source: https://learn.microsoft.com/en-us/windows/wsl/wsl-config_

## Why 6GB is tight for this toolchain

Claude Code, a vite dev server, pyright, and "a few" MCP servers are four to five separate node/python processes running concurrently, each with its own baseline heap plus project-specific state (pyright's type index scales with workspace size; vite's dev server and its file watcher hold module graphs in memory; each MCP server is its own long-lived node/python process). Treat this as an assumption, not a measured fact — you haven't shared per-process RSS — but a 6GB hard ceiling across all of that plus the interactive shell leaves very little headroom before the first OOM event, particularly on a cold start where several tools index simultaneously.

## Diagnose before capping

The "90% of 32GB" figure deserves a source check before you use it to size a cap:

- Confirm it's actually `vmmemWSL`'s working set in Task Manager, not overall Windows memory usage (browser tabs, other apps) alongside a smaller WSL footprint.
- Inside WSL, rank processes by RSS and check parentage/age before assuming the number reflects genuine steady-state need: `ps -eo pid,ppid,rss,etimes,cmd --sort=-rss | head -30`. A `ppid` of `1` on a node/python/mcp process with no attached job tree is residue, not live work — long-running Claude Code sessions commonly accumulate orphaned or duplicate MCP/pyright/vite helpers that never get reclaimed, and that residue is frequently the real driver of "WSL eats everything," not the legitimate tool set. This skill ships a dry-run-only scanner (`scripts/allocate_less_memory.py` / `.sh`, default `--dry-run`) that surfaces exactly this: high-RSS processes outside the active session tree, sorted by size. Run it in dry-run only and review the list yourself before terminating anything.
- Only size a cap after separating genuine load from residue. Capping first hides the residue problem; it just makes the VM OOM-kill sooner.

## Recommended sequence

- Clean up residue first (orphaned/duplicate MCP, pyright, vite processes) — this is usually cheaper than a hard cap and doesn't risk starving legitimate work.
- Re-enable swap. Start at 4–8GB rather than 0. This alone removes the "stalls at the boundary" failure mode described for tight WSL memory even before you touch the cap.
- If still capping, size it from measured peak (`free -h` / `vmmemWSL` working set) over a normal working session plus headroom, not a round guess. Given the four-to-five-process toolchain, 6GB is likely below that peak; 10–12GB is a safer starting point to test from.
- Consider the experimental `autoMemoryReclaim` setting (`[experimental]` section, values `disabled`/`gradual`/`dropCache`, default `dropCache` on current WSL) — it reclaims cached (non-live) memory back to Windows continuously, which addresses the "vmmemWSL keeps climbing" symptom without a hard wall that can kill live processes. Check `wsl --version` for availability. _Source: https://learn.microsoft.com/en-us/windows/wsl/wsl-config_
- Apply changes with `wsl --shutdown` from PowerShell, then wait for `wsl --list --running` to report none running before relaunching — WSL does not hot-apply `.wslconfig` edits to a running instance (documented "8 second rule"). _Source: https://learn.microsoft.com/en-us/windows/wsl/wsl-config_

| Setting | Current | Your plan | Suggested starting point |
|---|---|---|---|
| `memory` | unset (default ~16GB on 32GB host) | `6GB` | `10–12GB`, then ratchet down after measuring real headroom |
| `swap` | `0` | `0` (unchanged) | `4–8GB` |
| `[experimental] autoMemoryReclaim` | unset | unset | `gradual` or `dropCache` if supported by your WSL version |

## Sources

- [Advanced settings configuration in WSL — Microsoft Learn](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)
