# Thresholds

Use these as defaults, then adjust to the host.

Dry-run:
- any scan
- any unclassified process tree
- any first pass on a new environment

Warn:
- `MemAvailable` below 1 GiB
- `vmmemWSL` near the configured cap
- duplicate helpers detected

Terminate candidates:
- orphaned helper processes older than the current session
- duplicate dev servers
- stale MCP or indexer workers with no parent chain
- a single runaway process when RSS dominates the session budget

Escalation:
- TERM first
- wait briefly
- KILL only if the process ignores termination
