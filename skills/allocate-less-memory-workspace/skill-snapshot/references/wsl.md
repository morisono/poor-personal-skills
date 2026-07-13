# WSL memory model

WSL2 fails by VM pressure, not by a single process metric. The useful signals are `MemAvailable`, swap presence, `vmmemWSL` growth, and orphaned helper processes that survive after the root session is gone.

Interpretation rules:
- `Swap: 0B` makes memory pressure non-resilient.
- `MemAvailable` below a few hundred MiB is already risky for multi-tool agent sessions.
- `Committed_AS` above `CommitLimit` is a warning sign, not proof by itself.
- `vmmemWSL` reflects the VM envelope; per-process RSS explains the contributors.

Failure pattern:
- the agent appears frozen
- a new terminal shows WSL service errors
- `wsl --shutdown` restores the VM

Operational response:
- reduce resident helpers
- add swap before lowering the memory cap further
- keep the current session tree attached until cleanup completes
