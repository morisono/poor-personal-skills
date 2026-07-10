# Process-tree cleanup rules

Goal: remove residue, not active work.

Kill order:
- orphaned children whose parent is gone
- duplicate helper instances with the same command line
- stale dev servers with no attached job tree
- confirmed runaway processes with the highest RSS first

Keep alive by default:
- the interactive shell
- the current agent root
- editor hosts still tied to the current session
- system services and network daemons

Signals that strengthen a kill decision:
- parent is `1` and the command matches a helper/server pattern
- RSS is high and the process has aged without CPU progress
- there are duplicate copies of the same helper
- the owning session already exited

Signals that weaken a kill decision:
- shared service sockets
- a process tree that still contains the active editor or current agent
- a build that is actively consuming CPU
