Ran the `allocate-less-memory` skill's Linux scanner (`allocate_less_memory.py`, uses `/proc` for an exact process-tree walk) in scan-only mode. No `--kill` flag was passed — nothing was terminated.

## Command

```bash
ROOT_PID=$$
echo "Protected root PID (current shell): $ROOT_PID"
python3 /mnt/c/Users/gemjin/Downloads/skills/poor-personal-skills/skills/allocate-less-memory/scripts/allocate_less_memory.py --max-rss-mb 300 --root-pid $ROOT_PID
```

`$$` captures the current shell's PID so `--root-pid` protects that shell's entire process tree (per SKILL.md constraint: never target the current shell or active session tree). `--max-rss-mb 300` sets the 300 MB resident-memory threshold requested. No `--kill` was used — the script defaults to dry-run and only prints candidates.

## Output

```
Protected root PID (current shell): 23844
PID  RSS_MB  PPID  ELAPSED_S  CMD
6568   559.7 3913  618       claude --dangerously-skip-permissions
3662   528.8 742   775       claude --dangerously-skip-permissions --continue
2018   528.6 1756  866       claude --dangerously-skip-permissions --continue
519    326.7 457   919       /home/sana/.hermes/hermes-agent/venv/bin/python -m hermes_cli.main gateway run
428     23.0 1     919       /usr/bin/python3 /usr/share/unattended-upgrades/unattended-upgrade-shutdown --wait-for-signal
321     21.2 1     919       /usr/bin/python3 /usr/bin/networkd-dispatcher --run-startup-triggers
149     13.5 1     921       snapfuse /var/lib/snapd/snaps/core22_2411.snap /snap/core22/2411 -o ro,nodev,allow_other,suid
223     13.0 1     921       snapfuse /var/lib/snapd/snaps/snapd_27406.snap /snap/snapd/27406 -o ro,nodev,allow_other,suid
173     12.0 1     921       snapfuse /var/lib/snapd/snaps/cups_1225.snap /snap/cups/1225 -o ro,nodev,allow_other,suid
154      1.8 1     921       snapfuse /var/lib/snapd/snaps/core24_1643.snap /snap/core24/1643 -o ro,nodev,allow_other,suid
122      1.8 1     921       snapfuse /var/lib/snapd/snaps/bare_5.snap /snap/bare/5 -o ro,nodev,allow_other,suid
214      1.7 1     921       snapfuse /var/lib/snapd/snaps/ngrok_419.snap /snap/ngrok/419 -o ro,nodev,allow_other,suid
134      1.7 1     921       snapfuse /var/lib/snapd/snaps/chromium_3483.snap /snap/chromium/3483 -o ro,nodev,allow_other,suid
192      1.7 1     921       snapfuse /var/lib/snapd/snaps/gnome-46-2404_153.snap /snap/gnome-46-2404/153 -o ro,nodev,allow_other,suid
180      1.6 1     921       snapfuse /var/lib/snapd/snaps/gnome-42-2204_263.snap /snap/gnome-42-2204/263 -o ro,nodev,allow_other,suid
190      1.6 1     921       snapfuse /var/lib/snapd/snaps/gtk-common-themes_1535.snap /snap/gtk-common-themes/1535 -o ro,nodev,allow_other,suid
201      1.6 1     921       snapfuse /var/lib/snapd/snaps/mesa-2404_1165.snap /snap/mesa-2404/1165 -o ro,nodev,allow_other,suid
218      1.6 1     921       snapfuse /var/lib/snapd/snaps/snapd_26865.snap /snap/snapd/26865 -o ro,nodev,allow_other,suid
178      1.5 1     921       snapfuse /var/lib/snapd/snaps/gnome-42-2204_247.snap /snap/gnome-42-2204/247 -o ro,nodev,allow_other,suid
208      1.5 1     921       snapfuse /var/lib/snapd/snaps/ngrok_409.snap /snap/ngrok/409 -o ro,nodev,allow_other,suid
133      1.5 1     921       snapfuse /var/lib/snapd/snaps/chromium_3479.snap /snap/chromium/3479 -o ro,nodev,allow_other,suid
157      1.5 1     921       snapfuse /var/lib/snapd/snaps/core24_1587.snap /snap/core24/1587 -o ro,nodev,allow_other,suid
140      1.5 1     921       snapfuse /var/lib/snapd/snaps/core22_2339.snap /snap/core22/2339 -o ro,nodev,allow_other,suid
168      1.5 1     921       snapfuse /var/lib/snapd/snaps/cups_1221.snap /snap/cups/1221 -o ro,nodev,allow_other,suid
```

## Reading the results

Candidate rule (from the script): a process qualifies if its command line matches the dev-helper pattern (`node|npm|python|pyright|vite|mcp|claude|hermes|lean-ctx`) AND is either over the 300 MB threshold OR orphaned (PPID 1); non-matching processes only qualify if both big and orphaned. The current shell (PID 23844) and its whole tree were excluded via `--root-pid`.

Two groups appear:

- Over 300 MB, pattern-matched, worth a closer look: three `claude --dangerously-skip-permissions` processes (PIDs 6568, 3662, 2018, roughly 530-560 MB each, 10-14 minutes elapsed) and one `hermes_cli.main gateway run` process (PID 519, 327 MB, 15 minutes elapsed). These are candidates by rule, not confirmed residue — need parentage/attachment check per `references/process-gc.md` before any action: still-attached Claude sessions or an active hermes gateway are not residue, only orphaned/duplicate ones are.
- Under 300 MB but PPID 1 (orphaned), pattern-matched: two `python3` system processes (unattended-upgrade-shutdown, networkd-dispatcher) and eleven `snapfuse` mounts. These are normal Ubuntu/snapd system infrastructure, not dev-session residue — snapfuse and unattended-upgrades are expected long-running orphans, not stale helpers.

No language-server processes (pyright, node, npm, vite) or MCP servers appeared above the noise floor in this scan.

No process was terminated. This was scan-only; `--kill` was never passed.
