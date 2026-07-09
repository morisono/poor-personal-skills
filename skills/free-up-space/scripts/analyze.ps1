<#
.SYNOPSIS
analyze.ps1 — report drive usage and top disk consumers on Windows. Read-only.
.PARAMETER Path
Root to scan. Defaults to the user profile.
.PARAMETER Top
Entries per section. Default 15.
.EXAMPLE
pwsh scripts/analyze.ps1 -Path C:\Users\me -Top 20
#>
[CmdletBinding()]
param(
    [string]$Path = $env:USERPROFILE,
    [int]$Top = 15
)

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "== Drives =="
Get-PSDrive -PSProvider FileSystem | Where-Object Used |
    Select-Object Name,
        @{n='UsedGB';  e={[math]::Round($_.Used  / 1GB, 1)}},
        @{n='FreeGB';  e={[math]::Round($_.Free  / 1GB, 1)}},
        @{n='Free%';   e={[math]::Round(100 * $_.Free / ($_.Used + $_.Free), 1)}} |
    Format-Table -AutoSize

Write-Host "== Largest directories under $Path (depth 2) =="
Get-ChildItem -Path $Path -Directory -Depth 1 -Force | ForEach-Object {
    $bytes = (Get-ChildItem $_.FullName -Recurse -File -Force | Measure-Object Length -Sum).Sum
    [pscustomobject]@{ SizeMB = [math]::Round($bytes / 1MB, 1); Dir = $_.FullName }
} | Sort-Object SizeMB -Descending | Select-Object -First $Top | Format-Table -AutoSize

Write-Host "== Largest files under $Path (>100 MB) =="
Get-ChildItem -Path $Path -Recurse -File -Force |
    Where-Object Length -gt 100MB |
    Sort-Object Length -Descending | Select-Object -First $Top |
    Select-Object @{n='SizeMB'; e={[math]::Round($_.Length / 1MB, 1)}}, FullName |
    Format-Table -AutoSize

Write-Host "== Known cache locations =="
$cacheDirs = @(
    "$env:TEMP",
    "$env:WINDIR\Temp",
    "$env:WINDIR\SoftwareDistribution\Download",
    "$env:LOCALAPPDATA\npm-cache",
    "$env:LOCALAPPDATA\pip\cache",
    "$env:LOCALAPPDATA\Temp",
    "$env:USERPROFILE\.gradle\caches",
    "$env:USERPROFILE\.m2\repository"
)
foreach ($d in $cacheDirs) {
    if (-not (Test-Path $d)) { continue }
    $bytes = (Get-ChildItem $d -Recurse -File -Force | Measure-Object Length -Sum).Sum
    '{0,10:N1} MB  {1}' -f ($bytes / 1MB), $d
}

# WSL vhdx files never shrink on their own — surface them.
$vhdx = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Recurse -Filter ext4.vhdx -Force
if ($vhdx) {
    Write-Host "`n== WSL virtual disks (compact separately, see cleanup-targets.md) =="
    $vhdx | Select-Object @{n='SizeGB'; e={[math]::Round($_.Length / 1GB, 1)}}, FullName |
        Format-Table -AutoSize
}

if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Host "== Docker =="
    docker system df
}
