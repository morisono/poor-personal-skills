---
name: allocate-less-memory
description: Reduce memory pressure in agentic dev sessions by identifying excess resident memory, orphaned children, and stale helper processes, then applying bounded cleanup or configuration changes.
license: Apache-2.0
metadata:
  author: you
  version: 0.1.0
---

# allocate-less-memory

## Purpose
Keep constrained WSL/Linux coding sessions below failure thresholds by shrinking avoidable resident memory, isolating heavy helpers, and terminating stale process trees before the host becomes unresponsive.

## Scope
Applies to long-running local dev sessions with many child tools, daemons, editors, indexers, and MCP services. Excludes generic OS tuning, app architecture, and process-management tutorials.

### Constraints
Default to dry-run. Prefer bounded cleanup over broad killing. Never target PID 1, the current shell, or core host services. Treat memory pressure as a session-level problem first and a platform problem second.

## Workflow
Start from the active session root, then inspect process trees, RSS, parentage, and launch age. Rank candidates by orphaned children, duplicate helpers, high RSS, and known dev-server patterns. Apply TERM first, escalate to KILL only for confirmed stale processes.

### Activation
Use when a coding agent freezes, WSL becomes sluggish, `vmmemWSL` climbs toward the cap, or helper processes outlive their parent session. Skip when the request is about one-off code review, static docs, or normal CPU-bound builds.

## Heuristics
Prefer process-tree cleanup over blanket memory hunts. Treat duplicate tool servers, detached npm/node/python workers, and idle MCP endpoints as the first cut. Count RSS, not VSZ. Use age and parentage to distinguish live work from residue. When memory is tight, lowering the WSL cap only helps if swap and cleanup are also present; otherwise the system stalls at the boundary.

## Evaluation
Success is visible as lower RSS/working-set pressure, restored interactivity, fewer orphaned helpers, and no loss of the active shell or editor session. Common failures are over-killing shared tools, missing detached children, and confusing cache growth with live process load.

## Escalation
Stop if a candidate is ambiguous, still attached to the active job tree, or required by the current editor/agent session. Escalate to configuration changes when cleanup recurs, when the same session repeatedly repopulates memory, or when the host cap is structurally too small.

## Examples
A frozen Claude Code session with leftover node, python, and MCP workers should be trimmed by tree, not by name alone. A detached dev server with no parent and no activity is a cleanup target. A single large but active indexer is not, unless memory pressure is already near the cap.

## References
- `references/wsl.md` — WSL-specific memory model, cap behavior, and failure signatures.
- `references/process-gc.md` — process-tree cleanup rules and kill ordering.
- `references/thresholds.md` — compact thresholds for dry-run, warning, and termination.
- `scripts/` — portable helpers for scanning, reporting, and bounded cleanup.
