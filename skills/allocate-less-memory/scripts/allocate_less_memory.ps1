# Scan (default) or trim stale memory-heavy dev helpers.
# Candidate rule: matches -Pattern AND (WorkingSet >= -MaxRssMB OR parent gone);
# non-matching processes qualify only when both big AND parent gone.
# Protected always: PID 0/4, this process, shells, -RootPid and its whole tree.
param(
  [switch]$Kill,
  [int]$MaxRssMB = 256,
  [int]$RootPid = 0,
  # Trailing guard stops substring hits, e.g. "node" inside the "nodev" mount flag.
  [string]$Pattern = '(node|npm|python|pyright|vite|mcp|claude|hermes|lean-ctx)([^a-z]|$)'
)

$procs = Get-CimInstance Win32_Process | ForEach-Object {
  [pscustomobject]@{
    ProcessId       = [int]$_.ProcessId
    ParentProcessId = [int]$_.ParentProcessId
    Name            = $_.Name
    CommandLine     = $_.CommandLine
    WorkingSetMB    = [math]::Round(($_.WorkingSetSize / 1MB), 1)
  }
}

$alive = @{}
foreach ($p in $procs) { $alive[$p.ProcessId] = $true }

# Full descendant tree of RootPid is protected, not just direct children.
$tree = @{}
if ($RootPid -ne 0) {
  $tree[$RootPid] = $true
  do {
    $grew = $false
    foreach ($p in $procs) {
      if (-not $tree.ContainsKey($p.ProcessId) -and $tree.ContainsKey($p.ParentProcessId)) {
        $tree[$p.ProcessId] = $true
        $grew = $true
      }
    }
  } while ($grew)
}

$targets = foreach ($p in $procs) {
  if ($p.ProcessId -in 0, 4, $PID) { continue }
  if ($tree.ContainsKey($p.ProcessId)) { continue }
  $cmd = if ($p.CommandLine) { $p.CommandLine } else { $p.Name }
  if ($cmd -match '(^|\\|/|\s)(bash|sh|zsh|fish|pwsh|powershell)(\.exe)?($|\s)') { continue }
  $big = $p.WorkingSetMB -ge $MaxRssMB
  $orphan = -not $alive.ContainsKey($p.ParentProcessId)
  $isHelper = $cmd -match $Pattern
  if (($isHelper -and ($big -or $orphan)) -or (-not $isHelper -and $big -and $orphan)) { $p }
}
$targets = @($targets | Sort-Object WorkingSetMB -Descending)

$targets | Select-Object ProcessId, ParentProcessId, WorkingSetMB, Name, CommandLine | Format-Table -AutoSize

if (-not $Kill) { return }

foreach ($p in $targets) {
  try { Stop-Process -Id $p.ProcessId -ErrorAction Stop } catch {}
}
Start-Sleep -Seconds 2
foreach ($p in $targets) {
  try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop } catch {}
}
