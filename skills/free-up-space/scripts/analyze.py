#!/usr/bin/env python3
"""analyze.py — cross-platform disk usage report. Read-only.

Usage:
    python3 analyze.py [PATH] [--top N] [--json]

PATH defaults to the user's home directory. --json emits machine-readable
output for piping into further tooling.
"""

import argparse
import json
import os
import shutil
import sys
from pathlib import Path

CACHE_CANDIDATES = [
    "~/.cache",
    "~/.npm",
    "~/.cargo/registry",
    "~/.m2/repository",
    "~/.gradle/caches",
    "~/.local/share/Trash",
    "~/Library/Caches",
    "~/Library/Developer/Xcode/DerivedData",
    "~/AppData/Local/Temp",
    "~/AppData/Local/npm-cache",
    "~/AppData/Local/pip/cache",
    "/var/cache/apt",
    "/var/cache/dnf",
    "/var/cache/pacman/pkg",
    "/var/log",
]

ARTIFACT_DIRS = {"node_modules", "target", ".venv", "venv", "__pycache__", ".tox"}


def dir_size(path: Path) -> int:
    """Recursive size in bytes; skips unreadable entries and symlinks."""
    total = 0
    stack = [path]
    while stack:
        current = stack.pop()
        try:
            with os.scandir(current) as it:
                for entry in it:
                    try:
                        if entry.is_symlink():
                            continue
                        if entry.is_file():
                            total += entry.stat().st_size
                        elif entry.is_dir():
                            stack.append(Path(entry.path))
                    except OSError:
                        continue
        except OSError:
            continue
    return total


def top_dirs(root: Path, depth: int, top: int):
    """Sizes of directories up to `depth` levels below root."""
    results = []
    level = [root]
    for _ in range(depth):
        nxt = []
        for d in level:
            try:
                with os.scandir(d) as it:
                    nxt.extend(Path(e.path) for e in it
                               if e.is_dir(follow_symlinks=False))
            except OSError:
                continue
        results.extend((dir_size(d), d) for d in nxt)
        level = nxt
    results.sort(reverse=True)
    return results[:top]


def top_files(root: Path, min_bytes: int, top: int):
    found = []
    for dirpath, _, filenames in os.walk(root, onerror=lambda _e: None):
        for name in filenames:
            p = Path(dirpath) / name
            try:
                size = p.stat().st_size
            except OSError:
                continue
            if size >= min_bytes:
                found.append((size, p))
    found.sort(reverse=True)
    return found[:top]


def find_artifacts(root: Path, top: int):
    """Build-artifact directories (node_modules, target, ...) with sizes."""
    hits = []
    for dirpath, dirnames, _ in os.walk(root, onerror=lambda _e: None):
        matched = [d for d in dirnames if d in ARTIFACT_DIRS]
        for d in matched:
            p = Path(dirpath) / d
            hits.append((dir_size(p), p))
            dirnames.remove(d)  # do not descend into it
    hits.sort(reverse=True)
    return hits[:top]


def mib(n: int) -> float:
    return round(n / 1048576, 1)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("path", nargs="?", default=str(Path.home()))
    ap.add_argument("--top", type=int, default=15)
    ap.add_argument("--json", action="store_true", dest="as_json")
    args = ap.parse_args()

    root = Path(args.path).expanduser()
    if not root.is_dir():
        print(f"not a directory: {root}", file=sys.stderr)
        return 2

    usage = shutil.disk_usage(root)
    report = {
        "root": str(root),
        "filesystem": {
            "total_gb": round(usage.total / 1e9, 1),
            "free_gb": round(usage.free / 1e9, 1),
            "free_pct": round(100 * usage.free / usage.total, 1),
        },
        "top_dirs": [{"mib": mib(s), "path": str(p)}
                     for s, p in top_dirs(root, depth=3, top=args.top)],
        "top_files": [{"mib": mib(s), "path": str(p)}
                      for s, p in top_files(root, 100 * 1048576, args.top)],
        "artifacts": [{"mib": mib(s), "path": str(p)}
                      for s, p in find_artifacts(root, args.top)],
        "caches": [],
    }
    for cand in CACHE_CANDIDATES:
        p = Path(cand).expanduser()
        if p.is_dir():
            report["caches"].append({"mib": mib(dir_size(p)), "path": str(p)})
    report["caches"].sort(key=lambda c: -c["mib"])

    if args.as_json:
        json.dump(report, sys.stdout, indent=2)
        print()
        return 0

    fs = report["filesystem"]
    print(f"Filesystem at {root}: {fs['free_gb']} GB free "
          f"of {fs['total_gb']} GB ({fs['free_pct']}%)")
    for section in ("top_dirs", "top_files", "artifacts", "caches"):
        print(f"\n== {section} ==")
        for item in report[section]:
            print(f"{item['mib']:>10.1f} MiB  {item['path']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
