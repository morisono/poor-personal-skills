# memory=6GB + swap=0: not recommended

Verdict: don't ship that pair. A hard 6GB ceiling with zero swap trades slow degradation for hard crashes.

## Why the combination backfires

- `memory=` is a Hyper-V ceiling on the whole WSL2 VM, not a per-process limit. Default is 50% of host RAM (16GB on your 32GB box). Dropping straight to 6GB with `swap=0` removes both the size and the cushion at once. _Source: https://learn.microsoft.com/en-us/windows/wsl/wsl-config_
- With `swap=0` there is no page-out fallback. Once resident demand hits the ceiling, the guest kernel's OOM killer fires immediately and picks whatever scores worst — usually the largest RSS process, which on your stack is likely pyright or an MCP server, not something you'd choose to sacrifice. This skill's own WSL notes flag `Swap: 0B` as making memory pressure "non-resilient" for exactly this reason. _Ref: references/wsl.md in this skill_
- Skill heuristic, directly on point: "Lowering the WSL cap without swap and cleanup just moves the stall to the new boundary." A tighter cap without addressing what's actually resident just changes where the crash happens, not whether it happens.

## Why 6GB is tight for this exact toolset

Claude Code, a Vite dev server, pyright, and "a few" MCP servers is a legitimate multi-process baseline, not residue by default:

- pyright's language server alone commonly sits at 1–3GB RSS on a mid-to-large TS/Python project during indexing.
- Vite's dev server plus esbuild/rollup workers adds several hundred MB to low-GB territory, more during cold pre-bundling.
- Each Node-based MCP server carries its own runtime overhead (~100–300MB), and "a few" of them multiply.
- Claude Code's own CLI/runtime adds more on top.

A clean, single, fully-attached session can plausibly sit at 3–6GB before subtracting kernel and page-cache overhead from the 6GB envelope. That leaves near-zero headroom for anything transient (a pyright re-index, a cold Vite rebuild) — exactly the spikes swap exists to absorb.

## What "eating 90%" likely means before you cap anything

vmmemWSL total includes reclaimable Linux page cache, not just active RSS — this skill's own reference draws the same distinction ("`vmmemWSL` reflects the VM envelope; per-process RSS explains the contributors"). High vmmemWSL alone isn't proof of pressure; `MemAvailable` inside the distro is the actual signal, and the skill's own warn threshold is `MemAvailable` below 1GiB.

Also worth confirming before picking a number: the documented default cap is 50% of host RAM (16GB here). If vmmemWSL is genuinely reaching ~29GB (90% of 32GB), either your `.wslconfig` already sets `memory=` higher than default, or the reported figure includes cache Windows hasn't reclaimed yet. Insufficient data to say which without seeing the current file — check for an existing `memory=` line before assuming the default is what's in play.

## Better sequence, in order

- Diagnose first, don't guess. Run this skill's dry-run scanner (read-only, kills nothing) to see whether current usage is legitimate active work or residue — orphaned helpers (PPID 1, owning session gone), duplicate MCP/vite/pyright instances from prior sessions: `scripts/allocate_less_memory.py --max-rss-mb 256` (or the `.sh` variant). Full classification rules in `references/process-gc.md`.
- If it finds orphans or duplicates, that's free memory back with zero config change — clean those before touching `.wslconfig` at all.
- Add swap back rather than removing it. Windows' own default is 25% of the memory cap, rounded up (4GB against a 16GB cap). An explicit `swap=4GB` to `swap=8GB` turns a transient spike into slower disk I/O instead of a silent OOM kill.
- Try `[experimental] autoMemoryReclaim=gradual` before a hard cap. It reclaims idle cached memory back to Windows continuously instead of holding it until a session ends, which directly addresses "keeps eating 90%" without imposing a ceiling that can starve active work. Per current Microsoft Learn documentation, the experimental section's documented default is `dropCache` (release on idle detection, immediate rather than gradual); setting `gradual` explicitly avoids the more aggressive default and reclaims in smaller increments. Note this feature depends on cgroup v2 and has a documented caveat: it can conflict with running the Docker daemon as a WSL service — use Docker Desktop instead if that applies. _Source: https://learn.microsoft.com/en-us/windows/wsl/wsl-config_
- Only after cleanup, swap, and auto-reclaim, size a cap from observed steady-state, not from a guess. Run a normal working session (Claude Code + Vite + pyright + your MCP servers, all attached and active), check `free -h` inside WSL for the actual steady-state RSS, then set `memory=` a few GB above that observed number — not below it. The 50%-of-host default (16GB on 32GB) is a far safer starting ceiling than 6GB for this toolset; ratchet down in small increments only while `MemAvailable` comfortably stays clear of the skill's 1GiB warn line.

## Example direction (illustrative only, not applied to any file)

```
[wsl2]
memory=16GB
swap=6GB

[experimental]
autoMemoryReclaim=gradual
```

Start near current default behavior with swap restored and auto-reclaim on, watch `MemAvailable` and vmmemWSL for a few days of real usage, then tighten `memory=` only if headroom stays comfortable.

Sources:
- [Advanced settings configuration in WSL | Microsoft Learn](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)
