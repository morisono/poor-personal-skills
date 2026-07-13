param(
  [switch]$Kill,
  [int]$MaxRssMB = 256,
  [int]$RootPid = 0,
  [string]$Pattern = 'node|npm|python|pyright|vite|mcp|claude|hermes|lean-ctx'
)

$procs = Get-CimInstance Win32_Process | ForEach-Object {
  [pscustomobject]@{
    ProcessId = [int]$_.ProcessId
    ParentProcessId = [int]$_.ParentProcessId
    Name = $_.Name
    CommandLine = $_.CommandLine
    WorkingSetMB = [math]::Round(($_.WorkingSetSize / 1MB), 1)
    CreationDate = $_.CreationDate
  }
}

$keep = { param($p) if ($p.ProcessId -eq 0) { return $true }; if ($p.ProcessId -eq 1) { return $true }; if ($RootPid -ne 0 -and ($p.ProcessId -eq $RootPid -or $p.ParentProcessId -eq $RootPid)) { return $true }; if ($p.CommandLine -match '^(bash|sh|zsh|fish|pwsh|powershell)($|\s)') { return $true }; if ($p.CommandLine -match $Pattern) { return $true }; return $false }

$targets = $procs | Where-Object { $_.WorkingSetMB -ge $MaxRssMB -and -not (& $keep $_) } | Sort-Object WorkingSetMB -Descending
$targets | Select-Object ProcessId, ParentProcessId, WorkingSetMB, Name, CommandLine | Format-Table -AutoSize

if (-not $Kill) { return }

foreach ($p in $targets) {
  try { Stop-Process -Id $p.ProcessId -ErrorAction Stop } catch {}
}
Start-Sleep -Seconds 2
foreach ($p in $targets) {
  try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop } catch {}
}
