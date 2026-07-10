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

Signal order (TERM → wait → KILL) is a constraint in SKILL.md; it applies at every threshold.
