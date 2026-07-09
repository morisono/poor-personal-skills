#!/usr/bin/env python3
"""clean.py — cross-platform cleanup of reproducible data. Dry-run by default.

Usage:
    python3 clean.py [--apply] [--targets pkg,trash,docker,pip,npm,artifacts]
    python3 clean.py --apply --artifact-root ~/projects --stale-days 90

Deletes only regenerable data: package-manager caches, trash, dangling Docker
objects, and (opt-in) build-artifact directories in stale projects. User
documents are never candidates. Every action is printed; without --apply
nothing is executed.
"""

import argparse
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

ARTIFACT_DIRS = {"node_modules", "target", ".venv", "venv", "__pycache__", ".tox"}

# (target-name, availability-probe, command)
COMMANDS = [
    ("pkg", "apt-get", ["sudo", "apt-get", "clean"]),
    ("pkg", "dnf", ["sudo", "dnf", "clean", "all"]),
    ("pkg", "brew", ["brew", "cleanup", "--prune=all"]),
    ("pip", "pip", [sys.executable, "-m", "pip", "cache", "purge"]),
    ("npm", "npm", ["npm", "cache", "clean", "--force"]),
    # No -a: keeps tagged images. Volumes untouched — they may hold unique data.
    ("docker", "docker", ["docker", "system", "prune", "-f"]),
    ("docker", "docker", ["docker", "builder", "prune", "-f"]),
]

TRASH_DIRS = ["~/.local/share/Trash/files", "~/.local/share/Trash/info", "~/.Trash"]


def dir_size(path: Path) -> int:
    total = 0
    for dirpath, _, filenames in os.walk(path, onerror=lambda _e: None):
        for name in filenames:
            try:
                total += (Path(dirpath) / name).stat().st_size
            except OSError:
                pass
    return total


def newest_mtime(path: Path) -> float:
    """Most recent mtime in a project dir, ignoring the artifact dirs themselves."""
    newest = 0.0
    for dirpath, dirnames, filenames in os.walk(path, onerror=lambda _e: None):
        dirnames[:] = [d for d in dirnames if d not in ARTIFACT_DIRS]
        for name in filenames:
            try:
                newest = max(newest, (Path(dirpath) / name).stat().st_mtime)
            except OSError:
                pass
    return newest


def stale_artifacts(root: Path, stale_days: int):
    """Artifact dirs whose surrounding project is untouched for stale_days."""
    cutoff = time.time() - stale_days * 86400
    for dirpath, dirnames, _ in os.walk(root, onerror=lambda _e: None):
        for d in [d for d in dirnames if d in ARTIFACT_DIRS]:
            dirnames.remove(d)
            project = Path(dirpath)
            if newest_mtime(project) < cutoff:
                yield project / d


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--targets", default="pkg,trash,docker,pip,npm")
    ap.add_argument("--artifact-root", type=Path,
                    help="also remove build artifacts in stale projects under this root")
    ap.add_argument("--stale-days", type=int, default=90)
    args = ap.parse_args()
    targets = set(args.targets.split(","))

    if not args.apply:
        print("DRY RUN — pass --apply to execute.\n")

    def act(desc, fn):
        if args.apply:
            print(f">> {desc}")
            try:
                fn()
            except Exception as exc:  # keep going; report at the end
                print(f"   failed: {exc}", file=sys.stderr)
        else:
            print(f"would: {desc}")

    for target, probe, cmd in COMMANDS:
        if target in targets and shutil.which(probe):
            act(" ".join(cmd), lambda c=cmd: subprocess.run(c, check=False))

    if "trash" in targets:
        for d in TRASH_DIRS:
            p = Path(d).expanduser()
            if p.is_dir():
                size = dir_size(p) / 1048576
                act(f"remove {p} ({size:.1f} MiB)",
                    lambda q=p: shutil.rmtree(q, ignore_errors=True))

    if args.artifact_root:
        root = args.artifact_root.expanduser()
        print(f"\nStale build artifacts under {root} "
              f"(project untouched {args.stale_days}+ days):")
        for artifact in stale_artifacts(root, args.stale_days):
            size = dir_size(artifact) / 1048576
            act(f"remove {artifact} ({size:.1f} MiB)",
                lambda q=artifact: shutil.rmtree(q, ignore_errors=True))

    if not args.apply:
        print("\nNothing was deleted. Review the list, then rerun with --apply.")
    else:
        usage = shutil.disk_usage(Path.home())
        print(f"\nFree space now: {usage.free / 1e9:.1f} GB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
