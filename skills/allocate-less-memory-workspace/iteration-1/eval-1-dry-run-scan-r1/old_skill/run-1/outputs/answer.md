# Dry-run scan for stale helpers (300 MB threshold, current shell protected)

Nothing was terminated. No `--kill` or `-Kill` flag was passed. This is a scan-only run using the `allocate-less-memory` skill's Python scanner (`scripts/allocate_less_memory.py`), which does a full process-tree walk from the given root PID — the correct choice over the shell-script variant for "protect the whole tree" semantics.

## Command

Current shell root PID identified via `$PPID` / `ps` ancestry: `6568` (`claude --dangerously-skip-permissions`), the stable parent of this session's ephemeral subshells.

```
python3 "/mnt/c/Users/gemjin/Downloads/skills/poor-personal-skills/skills/allocate-less-memory-workspace/skill-snapshot/scripts/allocate_less_memory.py" --max-rss-mb 300 --root-pid 6568
```

No `--kill` flag included — default mode is dry-run (list only).

## Output

```
PID  RSS_MB  PPID  ELAPSED_S  CMD
2018   525.9 1756  6199      claude --dangerously-skip-permissions --continue
3662   502.9 742   15271     claude --dangerously-skip-permissions --continue
519    321.9 457   905       /home/sana/.hermes/hermes-agent/venv/bin/python -m hermes_cli.main gateway run
428     23.0 1     847       /usr/bin/python3 /usr/share/unattended-upgrades/unattended-upgrade-shutdown --wait-for-signal
321     21.2 1     815       /usr/bin/python3 /usr/bin/networkd-dispatcher --run-startup-triggers
149     13.4 1     685       snapfuse /var/lib/snapd/snaps/core22_2411.snap /snap/core22/2411 -o ro,nodev,allow_other,suid
223     13.0 1     694       snapfuse /var/lib/snapd/snaps/snapd_27406.snap /snap/snapd/27406 -o ro,nodev,allow_other,suid
173     11.9 1     688       snapfuse /var/lib/snapd/snaps/cups_1225.snap /snap/cups/1225 -o ro,nodev,allow_other,suid
154      1.8 1     686       snapfuse /var/lib/snapd/snaps/core24_1643.snap /snap/core24/1643 -o ro,nodev,allow_other,suid
122      1.8 1     682       snapfuse /var/lib/snapd/snaps/bare_5.snap /snap/bare/5 -o ro,nodev,allow_other,suid
214      1.7 1     692       snapfuse /var/lib/snapd/snaps/ngrok_419.snap /snap/ngrok/419 -o ro,nodev,allow_other,suid
134      1.7 1     683       snapfuse /var/lib/snapd/snaps/chromium_3483.snap /snap/chromium/3483 -o ro,nodev,allow_other,suid
192      1.7 1     690       snapfuse /var/lib/snapd/snaps/gnome-46-2404_153.snap /snap/gnome-46-2404/153 -o ro,nodev,allow_other,suid
180      1.6 1     688       snapfuse /var/lib/snapd/snaps/gnome-42-2204_263.snap /snap/gnome-42-2204/263 -o ro,nodev,allow_other,suid
190      1.6 1     690       snapfuse /var/lib/snapd/snaps/gtk-common-themes_1535.snap /snap/gtk-common-themes/1535 -o ro,nodev,allow_other,suid
201      1.6 1     691       snapfuse /var/lib/snapd/snaps/mesa-2404_1165.snap /snap/mesa-2404/1165 -o ro,nodev,allow_other,suid
218      1.5 1     693       snapfuse /var/lib/snapd/snaps/snapd_26865.snap /snap/snapd/26865 -o ro,nodev,allow_other,suid
178      1.5 1     688       snapfuse /var/lib/snapd/snaps/gnome-42-2204_247.snap /snap/gnome-42-2204/247 -o ro,nodev,allow_other,suid
208      1.5 1     692       snapfuse /var/lib/snapd/snaps/ngrok_409.snap /snap/ngrok/409 -o ro,nodev,allow_other,suid
133      1.5 1     683       snapfuse /var/lib/snapd/snaps/chromium_3479.snap /snap/chromium/3479 -o ro,nodev,allow_other,suid
157      1.5 1     686       snapfuse /var/lib/snapd/snaps/core24_1587.snap /snap/core24/1587 -o ro,nodev,allow_other,suid
140      1.5 1     684       snapfuse /var/lib/snapd/snaps/core22_2339.snap /snap/core22/2339 -o ro,nodev,allow_other,suid
168      1.5 1     687       snapfuse /var/lib/snapd/snaps/cups_1221.snap /snap/cups/1221 -o ro,nodev,allow_other,suid
```

Exit code 0. No processes were signaled.

## Reading the results

Real candidates above the 300 MB bar, unrelated to the protected shell tree (root PID 6568 and its own descendants, plus the scanner's own PID, were excluded automatically):

- PID 2018 and PID 3662, both `claude --dangerously-skip-permissions --continue`, 525.9 MB and 502.9 MB RSS, parented by 1756 and 742 — separate Claude Code sessions, not descendants of the protected root. Elapsed times (6199 s ≈ 1h43m, 15271 s ≈ 4h14m) indicate long-running, possibly abandoned sessions.
- PID 519, `hermes-agent` gateway process, 321.9 MB RSS, elapsed 905 s (~15 min).

These three are the actionable "stale helper" candidates a follow-up bounded-cleanup pass would target, per the skill's kill-order rules (duplicate/orphaned helpers, highest RSS first) — subject to confirming they are in fact abandoned before any termination step, which was explicitly out of scope here.

The `snapfuse` entries are false positives, not real memory consumers (1.5–23 MB RSS each). Root cause: the scanner's default `--pattern` is an unanchored substring regex `(node|npm|python|pyright|vite|mcp|claude|hermes|lean-ctx)`. The mount flag `nodev` in each `snapfuse` command line contains the substring `node`, so every snap-mount process matches the pattern and gets included via the "pattern matched OR orphaned (`ppid==1`)" branch regardless of RSS. Verified directly: `VmRSS` for PID 149 is 13656 kB and PID 223 is 14428 kB, matching the ~13–14 MB shown, and a standalone regex test confirms both `snapfuse ... nodev ...` command lines match `PATTERN`. This is a known-shape false-positive in the tool, not evidence of real memory pressure — Fact, verified against `/proc/<pid>/status` and a standalone regex check, not the tool's own claim taken at face value.

## Notes on the run

- Used `scripts/allocate_less_memory.py`, not `scripts/allocate_less_memory.sh`: the shell variant's `--root-pid` only exempts direct parent/child of the root PID, while the Python variant does a full BFS/DFS descendant walk (`inside_tree`) plus always excludes the scanner's own PID — the better match for "protect the process tree of your current shell."
- Total process count on this host is 31 — a minimal/sandboxed Linux environment, not a full desktop WSL install with many stray dev/language servers.
- Two anomalies surfaced during setup and were independently verified rather than trusted: a `Read` tool call falsely reported the SKILL.md as "unchanged" despite never being read before in this session, and a `ps` invocation was silently rewritten to `rtk ps` by the shell layer. Neither affected the scan's correctness — content was re-fetched via direct `cat`/`ps`, and the executed scanner command and its output above are exact.
