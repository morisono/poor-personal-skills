Verdict: no — `memory=6GB` with `swap=0` fixes the symptom by relocating it, not by removing it.

Two separate problems here, and the plan only addresses one of them badly.

**Problem 1: `swap=0` removes your safety margin, not adds one.**
`swap=0` disables the WSL2 VM's swap file entirely. Default swap is 25% of the memory size, rounded up to the nearest GB — `swap=0` is an explicit opt-out of that buffer. _Source: https://learn.microsoft.com/en-us/windows/wsl/wsl-config_. With no swap, once the VM hits its `memory=` ceiling there's nothing to page out to — the Linux OOM killer inside the VM starts killing processes abruptly, or the VM stalls. That matches this skill's own WSL reference: "`Swap: 0B` makes memory pressure non-resilient," and "lowering the WSL cap without swap and cleanup just moves the stall to the new boundary." Capping to 6GB with swap still at 0 trades "vmmemWSL slowly eats the host" for "the VM hard-stalls or kills something the moment you cross 6GB," which is worse for an interactive session running Claude Code.

**Problem 2: 6GB is thin for that toolset running concurrently, and untested.**
Claude Code's own process, "a few" Node-based MCP servers, a vite dev server, and pyright's language server all have to fit inside the same 6GB ceiling as the Linux base OS overhead. Pyright and Node processes are the ones most likely to push against a low ceiling on any real-sized project. Windows' own default for `memory=` is 50% of host RAM (so ~16GB on a 32GB machine) — 6GB is a large cut from that default, chosen without first measuring what this specific workload actually needs. _Source: https://learn.microsoft.com/en-us/windows/wsl/wsl-config_

**The 90% figure is itself suspicious, not just "WSL is heavy."**
~29GB resident for Claude Code + vite + pyright + a handful of MCP servers is disproportionate to steady-state need for that toolset. This skill's model treats that gap as a signature of residue — orphaned helper processes (PPID 1, owning session gone) or duplicate tool-server instances outliving closed sessions — rather than one legitimate working set. Diagnose before capping: run the skill's dry-run scanner (`scripts/allocate_less_memory.sh` or `.py`, no `--kill`) to rank current processes by RSS and check for orphaned/duplicate node, python, pyright, or MCP-server processes. If a handful of stale processes account for most of the 90%, cleaning those up solves the actual problem; a hard cap does not.

**Recommended order, per this skill's escalation path:**
- Dry-run scan first, clean confirmed residue (orphaned/duplicate helpers only, TERM before KILL).
- If pressure still recurs after cleanup, add swap before tightening the cap — a cap without swap just moves the failure point, it doesn't remove it.
- Then size the cap to the measured working set with headroom, not to an arbitrary low number picked before diagnosis.

**If you still want to set a ceiling in `.wslconfig`:**
- Keep `swap` non-zero — something like `swap=4GB` to `8GB` gives the VM a buffer to degrade into instead of hard-stalling.
- Don't start at 6GB blind. Given Claude Code + several MCP servers + vite + pyright running together, a ceiling in the 12–16GB range is a more defensible starting point than 6GB; tighten it only after the scanner confirms actual steady-state usage with everything running.
- Any `.wslconfig` edit requires a full `wsl --shutdown` (stops every running distro) and roughly 8 seconds before the new values take effect — partial restarts won't pick it up. _Source: https://learn.microsoft.com/en-us/windows/wsl/wsl-config_
- After changing it, verify with `free -h` for `MemAvailable` inside WSL and watch for this skill's documented freeze signature — session looks frozen, a new terminal shows WSL service errors, `wsl --shutdown` is needed to recover — which means the new cap is still too tight relative to swap.

This is advisory only — no process was terminated and no config file was modified as part of answering this.
