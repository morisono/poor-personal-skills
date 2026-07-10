---
name: allocate-less-memory
description: Diagnose and relieve RAM pressure from stale dev-session processes on WSL, Linux, and Windows. Use whenever the user mentions out-of-memory or OOM kills, a frozen or sluggish agent/WSL session, vmmemWSL growing toward its cap, orphaned or duplicate helper processes (node, npm, python, pyright, MCP servers, dev servers) outliving closed sessions, or asks which processes to kill to free RAM — even if they never say "memory". Covers process-tree scanning, bounded TERM→KILL cleanup with bundled dry-run scripts, and WSL cap/swap tuning. Not for fixing memory leaks or reducing allocations inside the user's own code, and not for disk space (use free-up-space).
license: Apache-2.0
metadata:
  author: fognito
  version: 0.2.0
---

# allocate-less-memory

## Purpose

Keep constrained dev sessions below failure thresholds: find processes that hold memory without doing work — orphans, duplicates, stale dev servers — and trim them without touching live work. Success = interactivity restored with the active shell, editor, and agent session intact.

## Scope

Includes: resident-memory triage of local dev sessions (agents, editors, indexers, MCP/dev servers), bounded process-tree cleanup, WSL memory-cap/swap advice.
Excludes: application-level memory profiling or leak fixing, generic OS tuning, disk space (use free-up-space).

### Constraints

- Dry-run by default; termination requires explicit user confirmation and the kill flag.
- Never target PID 1, the current shell, the active agent/editor tree, or core host services (init, sshd, databases) — even when they exceed thresholds.
- TERM first, brief wait, KILL only for processes that ignore TERM.
- Bounded tree cleanup, never blanket "kill everything big": a process is residue because of parentage and age, not size alone.

## Workflow

1. Scan (dry-run prints ranked candidates, kills nothing): `scripts/allocate_less_memory.sh` (POSIX ps), `scripts/allocate_less_memory.py` (Linux /proc, exact tree walk), or `scripts/allocate_less_memory.ps1` (Windows). Flags: `--max-rss-mb N` (default 256), `--root-pid PID` protects that PID's whole tree, `--pattern REGEX` sets which command lines count as dev helpers.
2. Classify candidates by parentage and age: orphaned helper (PPID 1, owning session gone) → residue; duplicate helper command lines → keep the attached one, drop the orphan; high-RSS but active (CPU progress, attached to live tree) → not a target. Full rules in `references/process-gc.md` — read before any kill.
3. Show the user the target list, get confirmation, re-run with `--kill` (sh/py) or `-Kill` (ps1).
4. Verify: MemAvailable / vmmemWSL back off the cap; shell, editor, and agent still alive.
5. Recurring pressure means configuration, not repeated cleanup: add swap before lowering the WSL cap (`references/wsl.md`), tune defaults per `references/thresholds.md`.

## Heuristics

- First cut: duplicate tool servers, detached npm/node/python workers, idle MCP endpoints.
- Count RSS, not VSZ. `vmmemWSL` is the VM envelope; per-process RSS explains the contributors.
- One large but active indexer is not residue — leave it unless memory is already at the cap.
- Lowering the WSL cap without swap and cleanup just moves the stall to the new boundary.

## Evaluation

Correct: MemAvailable rises, interactivity returns, orphan count drops, active session intact.
Failure modes: over-killing shared tools; killing a parent and leaving detached children (kill by tree); mistaking cache growth for live process load.

## Escalation

Stop and ask when a candidate is ambiguous, still inside the active job tree, or required by the current editor/agent. Escalate to configuration (swap, cap size, fewer resident helpers) when the same session repeatedly refills memory.

## Examples

- Frozen Claude Code session with leftover node/python/MCP workers → trim by tree, not by process name.
- Detached vite dev server, PPID 1, idle for hours → TERM candidate.
- Single 2 GiB indexer actively serving the editor → keep, unless already at the cap.

## References

- `references/wsl.md` — WSL2 memory model, cap/swap behavior, freeze signature. Read for any WSL-specific question.
- `references/process-gc.md` — kill order and keep-alive rules. Read before any `--kill`.
- `references/thresholds.md` — default dry-run/warn/terminate thresholds.
