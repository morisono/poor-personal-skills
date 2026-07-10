#!/usr/bin/env python3
"""Scan (default) or trim stale memory-heavy dev helpers via /proc.

Candidate rule: matches --pattern AND (RSS >= --max-rss-mb OR orphaned, PPID 1);
non-matching processes qualify only when both big AND orphaned.
Protected always: PID 0/1, this process, shells, --root-pid and its whole tree.
"""
from __future__ import annotations

import argparse
import os
import re
import signal
import time
from dataclasses import dataclass
from typing import Iterable

# Trailing guard stops substring hits, e.g. "node" inside the "nodev" mount flag.
PATTERN = re.compile(r"(node|npm|python|pyright|vite|mcp|claude|hermes|lean-ctx)(?![a-z])", re.I)
SHELLS = re.compile(r"(^|/|\s)(bash|sh|zsh|fish|pwsh|powershell)(\s|$)")
CLK_TCK = os.sysconf(os.sysconf_names["SC_CLK_TCK"])


@dataclass
class Proc:
    pid: int
    ppid: int
    rss_kb: int
    etimes: int
    cmd: str


def read_proc(pid: int, uptime: float) -> Proc | None:
    try:
        with open(f"/proc/{pid}/stat", "r", encoding="utf-8") as f:
            stat = f.read()
        # comm (field 2) may contain spaces/parens; split after its closing ')'.
        rparen = stat.rindex(")")
        comm = stat[stat.index("(") + 1 : rparen]
        fields = stat[rparen + 2 :].split()  # fields[0] == state (field 3)
        ppid = int(fields[1])
        starttime_ticks = int(fields[19])
        etimes = max(0, int(uptime - starttime_ticks / CLK_TCK))
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            raw = f.read().replace(b"\x00", b" ").strip()
        cmd = raw.decode("utf-8", "replace") if raw else comm
        rss = 0
        with open(f"/proc/{pid}/status", "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("VmRSS:"):
                    rss = int(line.split()[1])
                    break
        return Proc(pid=pid, ppid=ppid, rss_kb=rss, etimes=etimes, cmd=cmd)
    except Exception:
        return None


def all_procs() -> list[Proc]:
    with open("/proc/uptime", "r", encoding="utf-8") as f:
        uptime = float(f.read().split()[0])
    out: list[Proc] = []
    for name in os.listdir("/proc"):
        if name.isdigit():
            p = read_proc(int(name), uptime)
            if p:
                out.append(p)
    return out


def inside_tree(root: int, procs: Iterable[Proc]) -> set[int]:
    by_parent: dict[int, list[int]] = {}
    for p in procs:
        by_parent.setdefault(p.ppid, []).append(p.pid)
    seen = {root}
    stack = [root]
    while stack:
        cur = stack.pop()
        for child in by_parent.get(cur, []):
            if child not in seen:
                seen.add(child)
                stack.append(child)
    return seen


def candidate(p: Proc, max_rss_mb: int, root_set: set[int], pattern: re.Pattern[str]) -> bool:
    if p.pid in {0, 1, os.getpid()} or p.pid in root_set:
        return False
    if SHELLS.search(p.cmd):
        return False
    big = p.rss_kb >= max_rss_mb * 1024
    orphan = p.ppid == 1
    if pattern.search(p.cmd):
        return big or orphan
    return big and orphan


def main() -> int:
    ap = argparse.ArgumentParser(description="Scan or trim stale memory-heavy helpers.")
    ap.add_argument("--kill", action="store_true", help="Terminate candidates (TERM, wait, KILL)")
    ap.add_argument("--max-rss-mb", type=int, default=256)
    ap.add_argument("--root-pid", type=int, default=0)
    ap.add_argument("--pattern", default=PATTERN.pattern)
    args = ap.parse_args()
    pattern = re.compile(args.pattern, re.I)

    procs = all_procs()
    root_set = inside_tree(args.root_pid, procs) if args.root_pid else set()
    targets = [p for p in procs if candidate(p, args.max_rss_mb, root_set, pattern)]
    targets.sort(key=lambda p: p.rss_kb, reverse=True)

    print("PID  RSS_MB  PPID  ELAPSED_S  CMD")
    for p in targets:
        print(f"{p.pid:<5} {p.rss_kb/1024:>6.1f} {p.ppid:<5} {p.etimes:<9} {p.cmd}")

    if not args.kill:
        return 0

    for p in targets:
        try:
            os.kill(p.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    time.sleep(2)
    for p in targets:
        try:
            os.kill(p.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
