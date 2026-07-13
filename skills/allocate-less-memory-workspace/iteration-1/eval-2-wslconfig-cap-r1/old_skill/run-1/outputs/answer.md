# memory=6GB with swap=0: not recommended as described

Verdict: capping at 6GB while swap=0 trades one failure mode (slow, visible RAM hog) for a worse one (sudden, silent process kills). Fix the diagnosis first, then size the cap with a swap safety net.

## Why the cap alone is risky

`memory=` in `.wslconfig` is a hard ceiling on the WSL2 VM, not a target — the VM cannot grow past it. Default is 50% of Windows RAM, so on a 32GB host the default ceiling is already 16GB, not 28.8GB. If `vmmemWSL` is eating ~90% of 32GB today, that points to something inside the VM growing unbounded (orphaned helper, duplicate process, or filesystem page cache counted as "used") rather than proof that 6GB is the right number.
_Source: https://learn.microsoft.com/en-us/windows/wsl/wsl-config_

`swap=` defaults to 25% of the memory size, rounded up to the nearest GB — `swap=0` explicitly disables the swap file, removing that buffer.
_Source: https://learn.microsoft.com/en-us/windows/wsl/wsl-config_

With no swap and a hard ceiling, once resident memory inside the VM hits 6GB the Linux kernel's OOM killer activates and picks a victim by badness score — proportional to each process's memory footprint, not by importance to your session. It could pick pyright, vite, an MCP server, or Claude Code itself.
_Source: https://man7.org/linux/man-pages/man5/proc_pid_oom_score_adj.5.html_

That failure mode is worse than the current one: instead of a laptop that feels sluggish, tools disappear mid-session without warning.

## Sizing against your actual workload

Rough per-process footprints for the stack described (Claude Code, vite, pyright, several MCP servers):

- Claude Code: a Node process, several hundred MB up to 1-2GB+ depending on session length and context held.
- vite dev server: Node, roughly 200-600MB, more under active HMR on a large module graph.
- pyright: holds the full type-checked program graph in memory; on a mid-to-large Python project this alone can reach multiple GB.
- each MCP server: a separate process, roughly 100-300MB idle, more when actively handling calls; "a few" of these adds up fast.

Sum these and 6GB leaves close to zero headroom once the WSL2 kernel, init, and page cache for the working tree are accounted for. Any burst — pyright re-indexing after a pull, a full vite rebuild, Claude Code loading a large tool result — can hit the ceiling with nothing to absorb the spike.

## What to do instead

Diagnose before capping:
- Run the skill's scanner in dry-run only (never `--kill`): `sh scripts/allocate_less_memory.sh --dry-run` or the Python equivalent, to see actual RSS by process.
- Look specifically for duplicate node/pyright/mcp processes and orphans whose parent is gone — this is the most common cause of "90% usage" that isn't legitimate tool memory, per this skill's process-gc heuristics.
- Compare `free -h`'s `available` column inside WSL against what Windows Task Manager reports for `vmmemWSL` — Windows counts reclaimable page cache as "in use," which inflates the apparent problem.
- Check `wsl --version`; if outdated, `wsl --update`. Current WSL defaults `[experimental] autoMemoryReclaim` to `dropCache`, meaning idle/cached VM memory is already supposed to be reclaimed automatically — an old build may be missing this.
  _Source: https://learn.microsoft.com/en-us/windows/wsl/wsl-config_

If a cap is still wanted after diagnosis:
- Size it to realistic peak plus headroom, not to an arbitrary low number — something in the 12-16GB range on a 32GB host is far more defensible than 6GB for this toolset, adjusted once you have real numbers from the scan.
- Never pair a tight cap with `swap=0`. Set an explicit swap size (e.g. `swap=4GB` or `swap=8GB`) so hitting the ceiling degrades to slower disk-backed swapping instead of triggering the kernel OOM killer.
- Consider leaving `autoMemoryReclaim` at its `gradual` or default `dropCache` setting rather than disabling it, so Windows reclaims idle VM memory continuously instead of relying only on a static ceiling.
- After any `.wslconfig` edit, changes only apply once every WSL instance is fully stopped — `wsl --shutdown`, wait for `wsl --list --running` to show none running, then relaunch.
  _Source: https://learn.microsoft.com/en-us/windows/wsl/wsl-config_

This is advisory only — no process was terminated and no config file was modified as part of producing this answer.
