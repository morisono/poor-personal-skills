---
name: free-up-space
description: Analyze disk usage and reclaim storage safely on Linux, macOS, Windows, and WSL. Use whenever the user mentions low disk space, "disk full", "clean up my drive", large directories, cache bloat, node_modules sprawl, Docker eating space, WSL vhdx growth, or asks which files to delete — even if they never say "free up space". Covers analysis tools (dust, dua, dysk, ncdu, WizTree), safe cleanup targets per platform, and bundled dry-run scripts.
license: Apache-2.0
metadata:
  author: fognito
  version: 1.0.0
---

# Free Up Space

## Purpose

Recover disk space with minimal risk: measure first, delete reproducible data only, verify reclaimed bytes after. Success = user-stated space goal met (or best achievable) with zero loss of unique data.

## Scope

Includes: local filesystem analysis, cache/artifact cleanup, package-manager cache pruning, container/VM image pruning, WSL vhdx compaction.
Excludes: partition resizing, filesystem repair, cloud storage quotas, data recovery, deduplication of user documents.

### Constraints

- Never delete without a size estimate and an explicit target list shown first.
- Only remove reproducible data (caches, build artifacts, package archives, old logs, trash). User documents, dotfile configs, and databases are out of bounds even when large.
- Bundled scripts default to dry-run; destructive mode requires `--apply`.
- Anything irreversible and ambiguous (e.g., old VM images, ~/Downloads contents) → list it, let user decide.

## Workflow

1. Quantify: total/free per filesystem, then top consumers. Run `scripts/analyze.sh` (POSIX), `scripts/analyze.ps1` (Windows), or `scripts/analyze.py` (cross-platform, JSON output).
2. Classify findings: reproducible (safe) vs unique (user decision) vs system-managed (use platform tool).
3. Estimate reclaim per target, present ranked list.
4. Clean: `scripts/clean.sh` / `scripts/clean.ps1` / `scripts/clean.py` — dry-run first, then `--apply` after user confirms.
5. Verify: re-run free-space check, report delta.

### Activation

Trigger on: disk-full errors (ENOSPC, "not enough space"), CI/build failures from full disks, slow machines with <10% free, requests to compare disk-usage tools.
Do not trigger for: file search unrelated to size, backup strategy design, RAID/partition work.

## Heuristics

- Biggest wins first: package caches, container images, and build artifacts usually dwarf everything else; check them before deep directory scans.
- Directory scan order: caches → build outputs → logs → downloads → media. Stop when goal met.
- `node_modules`, `target/`, `.venv`, `__pycache__` in inactive projects (no commit in 90+ days) are prime candidates — still list before removing.
- On Windows, prefer built-in mechanisms (Storage Sense, `cleanmgr`, DISM) over manual deletion inside `C:\Windows`.
- On WSL, deleting files inside the guest does not shrink the `.vhdx`; compaction is a separate required step (see `references/cleanup-targets.md`).
- Interactive exploration: recommend `dust` for tree overview, `dua interactive`/`ncdu` for browse-and-delete. Tool comparison in `references/analysis-tools.md`.

## Evaluation

- Correct: `df`/`Get-PSDrive` free-space delta matches estimate within ~10%.
- Failure mode: deleted files still held by running processes → space not released; detect with `lsof +L1` (Linux) and restart holders.
- Failure mode: WSL/VM host file unchanged after guest cleanup → run compaction step.
- Recovery: all script actions are logged to stdout; caches regenerate on next use; nothing unique is touched, so worst case is a slow rebuild.

## Escalation

Stop and ask when: target is not clearly reproducible, requested path is under user profile documents, cleanup requires elevation the user has not granted, or goal is unreachable without touching unique data. Defer filesystem corruption symptoms (I/O errors, mount failures) to repair tooling — not this skill.

## Examples

- "My CI agent fails with ENOSPC" → analyze, find 40 GB Docker layers → `docker system prune` dry-run list → apply → verify.
- "C: drive full but I deleted everything" (WSL user) → `.vhdx` never shrinks automatically → compact per `references/cleanup-targets.md`.
- Anti-pattern: running `rm -rf` on scan results directly — always classify and confirm first.

## References

- `references/analysis-tools.md` — comparison of dust, dua, dysk, ncdu, duf, erdtree, WizTree; command recipes. Read when choosing or explaining an analysis tool.
- `references/cleanup-targets.md` — per-platform reclaim targets with commands and typical sizes (Linux, macOS, Windows, WSL, dev toolchains). Read before proposing any cleanup.
- `scripts/` — analyze + clean, each in POSIX sh, PowerShell Core, Python. Run `--help` for options.
