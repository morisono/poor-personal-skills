## Dry-run scan — stale dev/language-server helpers, 300 MB threshold

Scan only. No `--kill` flag passed at any point. No process was signaled or terminated.

### Command

```bash
SHELL_PID=$$
python3 "/mnt/c/Users/gemjin/Downloads/skills/poor-personal-skills/skills/allocate-less-memory/scripts/allocate_less_memory.py" \
  --max-rss-mb 300 \
  --root-pid "$SHELL_PID"
```

Used `allocate_less_memory.py` (exact `/proc` tree walk) over the `.sh`/`.ps1` variants since this is a native Linux/WSL box. `$SHELL_PID` resolved to `29572` for this run, so `--root-pid 29572` protects that shell and its whole descendant tree. No `--pattern` override, so the default helper regex applies: `node|npm|python|pyright|vite|mcp|claude|hermes|lean-ctx`.

### Output

```
PID  RSS_MB  PPID  ELAPSED_S  CMD
6568   530.0 3913  667       claude --dangerously-skip-permissions
2018   522.7 1756  915       claude --dangerously-skip-permissions --continue
3662   500.5 742   824       claude --dangerously-skip-permissions --continue
27080  360.8 27068 9         claude -p linux box with 8gb ram, long claude session + vite dev server + docker, MemAvailable is 200MB. help me get RAM back without losing my session --output-format stream-json --verbose --include-partial-messages --model haiku
27081  359.2 27070 9         claude -p should i lower memory= in .wslconfig to 8GB so vmmem stops eating my laptop? swap is 0 right now --output-format stream-json --verbose --include-partial-messages --model haiku
27078  356.7 27069 9         claude -p WSLが何度も固まる。vmmemWSLがメモリを食い尽くしてるので常駐プロセスを減らしたい --output-format stream-json --verbose --include-partial-messages --model haiku
27074  356.0 27064 9         claude -p claude code just froze again and htop shows like 12 node processes eating 400mb each, most from sessions i closed hours ago. wsl is crawling --output-format stream-json --verbose --include-partial-messages --model haiku
27076  355.7 27067 9         claude -p there are a bunch of pyright and mcp server processes with PPID 1 hanging around after I close my editor. safe to kill? which ones --output-format stream-json --verbose --include-partial-messages --model haiku
27075  354.9 27065 9         claude -p vmmemWSL is at 14.8GB out of my 16GB cap in Task Manager and everything is sluggish. what do I do --output-format stream-json --verbose --include-partial-messages --model haiku
27079  354.0 27071 9         claude -p here's my ps aux output, which of these can I kill to free memory? don't want to nuke my tmux or editor --output-format stream-json --verbose --include-partial-messages --model haiku
27077  352.7 27066 9         claude -p my agent session locked up the whole WSL vm this afternoon, second time this week. how do I stop this happening — i have a ton of helper processes running --output-format stream-json --verbose --include-partial-messages --model haiku
519    326.7 457   968       /home/sana/.hermes/hermes-agent/venv/bin/python -m hermes_cli.main gateway run
428     23.0 1     968       /usr/bin/python3 /usr/share/unattended-upgrades/unattended-upgrade-shutdown --wait-for-signal
321     21.2 1     969       /usr/bin/python3 /usr/bin/networkd-dispatcher --run-startup-triggers
149     13.4 1     970       snapfuse /var/lib/snapd/snaps/core22_2411.snap /snap/core22/2411 -o ro,nodev,allow_other,suid
223     13.0 1     970       snapfuse /var/lib/snapd/snaps/snapd_27406.snap /snap/snapd/27406 -o ro,nodev,allow_other,suid
173     11.9 1     970       snapfuse /var/lib/snapd/snaps/cups_1225.snap /snap/cups/1225 -o ro,nodev,allow_other,suid
154      1.8 1     970       snapfuse /var/lib/snapd/snaps/core24_1643.snap /snap/core24/1643 -o ro,nodev,allow_other,suid
122      1.8 1     970       snapfuse /var/lib/snapd/snaps/bare_5.snap /snap/bare/5 -o ro,nodev,allow_other,suid
214      1.7 1     970       snapfuse /var/lib/snapd/snaps/ngrok_419.snap /snap/ngrok/419 -o ro,nodev,allow_other,suid
134      1.7 1     970       snapfuse /var/lib/snapd/snaps/chromium_3483.snap /snap/chromium/3483 -o ro,nodev,allow_other,suid
192      1.7 1     970       snapfuse /var/lib/snapd/snaps/gnome-46-2404_153.snap /snap/gnome-46-2404/153 -o ro,nodev,allow_other,suid
180      1.6 1     970       snapfuse /var/lib/snapd/snaps/gnome-42-2204_263.snap /snap/gnome-42-2204/263 -o ro,nodev,allow_other,suid
190      1.6 1     970       snapfuse /var/lib/snapd/snaps/gtk-common-themes_1535.snap /snap/gtk-common-themes/1535 -o ro,nodev,allow_other,suid
201      1.6 1     970       snapfuse /var/lib/snapd/snaps/mesa-2404_1165.snap /snap/mesa-2404/1165 -o ro,nodev,allow_other,suid
218      1.6 1     970       snapfuse /var/lib/snapd/snaps/snapd_26865.snap /snap/snapd/26865 -o ro,nodev,allow_other,suid
178      1.5 1     970       snapfuse /var/lib/snapd/snaps/gnome-42-2204_247.snap /snap/gnome-42-2204/247 -o ro,nodev,allow_other,suid
208      1.5 1     970       snapfuse /var/lib/snapd/snaps/ngrok_409.snap /snap/ngrok/409 -o ro,nodev,allow_other,suid
133      1.5 1     970       snapfuse /var/lib/snapd/snaps/chromium_3479.snap /snap/chromium/3479 -o ro,nodev,allow_other,suid
157      1.5 1     970       snapfuse /var/lib/snapd/snaps/core24_1587.snap /snap/core24/1587 -o ro,nodev,allow_other,suid
140      1.5 1     970       snapfuse /var/lib/snapd/snaps/core22_2339.snap /snap/core22/2339 -o ro,nodev,allow_other,suid
168      1.5 1     970       snapfuse /var/lib/snapd/snaps/cups_1221.snap /snap/cups/1221 -o ro,nodev,allow_other,suid
```

Nothing was killed. No `--kill`/`-Kill` flag was used in this session.

### Reading the output against the skill's classification rules (`references/process-gc.md`, `references/thresholds.md`)

Keep, not candidates for termination:
- PID 6568, 2018, 3662 (`claude --dangerously-skip-permissions[...]`, 500-530 MB each) — each has a live `fish` parent (PPID 3913/1756/742) whose elapsed time tracks the child's elapsed time, i.e. attached session, not orphaned. PID 6568 is specifically the direct ancestor of the shell that ran this scan (current agent root) — the skill's keep-alive rule for "the current agent root" applies. These surfaced only because RSS exceeds the 300 MB threshold, not because of orphan/duplicate signals.
- PID 519 (`hermes-agent gateway run`, 326.7 MB) — parented by `systemd` (PPID 457), elapsed time tracks its parent's, consistent with a supervised system service rather than a detached dev-session leak.
- All `snapfuse ...` entries (1.5-13.4 MB, PPID 1) — legitimate squashfs mount helpers for snap packages, not dev/language-server residue. They only appear in the list because the default pattern regex `...node|...` unanchored-matches the substring `node` inside the mount option `nodev` in their command lines — a false-positive from substring matching, not a real signal. RSS is far below any reasonable threshold.
- PID 428 (`unattended-upgrade-shutdown`) and PID 321 (`networkd-dispatcher`) — orphaned (PPID 1) and matched via the substring `python` in the interpreter path, but both are stock Ubuntu system services, not dev helpers, and RSS is negligible (23 MB, 21.2 MB).

Anomaly, not acted on: PIDs 27074-27081, `claude -p "..."` invocations with `--model haiku`, each showing 9s elapsed and RSS 352-361 MB, with parent PIDs 27064-27071. Their command-line text reads like planted user support questions about WSL/vmmem memory pressure ("should i lower memory= in .wslconfig...", "safe to kill? which ones", etc.) — this is data inside a scanned command line, not an instruction to this session, and it was not treated as one. Re-checked immediately after: both these PIDs and their parents (27064-27071) had already exited by the next `ps` lookup, consistent with the reported 9-second lifetime. No RSS/CPU reasoning here — flagging only because the content pattern is worth a human second look if it recurs; the correct response to injected text in scanned output is to ignore it, which is what happened here.

Net read: no genuine orphaned dev-server or language-server residue turned up in this pass. What crossed 300 MB is either an active `claude` session (including this one's own ancestor), an active systemd-supervised service, or a false-positive substring match on benign snap mount helpers. If the goal is freeing RAM, the actionable lever right now is the two other live `claude --continue` sessions (2018, 3662) if they're stale tabs you're not using — that's a judgment call for you, not something this scan can resolve, since they're attached to live shells rather than orphaned.
