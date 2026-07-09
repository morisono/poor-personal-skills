<#
.SYNOPSIS
clean.ps1 — reclaim space from reproducible data only. Dry-run by default.
.PARAMETER Apply
Actually delete. Without it, only reports what would happen.
.PARAMETER Targets
Subset of: temp, recyclebin, update, npm, pip, docker. Default: all.
.NOTES
Never touches user documents. WinSxS/component-store cleanup is intentionally
excluded — run DISM manually per references/cleanup-targets.md.
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [string[]]$Targets = @('temp', 'recyclebin', 'update', 'npm', 'pip', 'docker')
)

$ErrorActionPreference = 'Continue'

function Invoke-Step {
    param([string]$Label, [scriptblock]$Action)
    if ($Apply) {
        Write-Host ">> $Label"
        & $Action
    } else {
        Write-Host "would: $Label"
    }
}

function Get-DirSizeMB {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    $bytes = (Get-ChildItem $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
        Measure-Object Length -Sum).Sum
    [math]::Round($bytes / 1MB, 1)
}

if (-not $Apply) { Write-Host "DRY RUN — pass -Apply to execute.`n" }
$freeBefore = (Get-PSDrive C).Free

if ($Targets -contains 'temp') {
    foreach ($d in @($env:TEMP, "$env:WINDIR\Temp")) {
        Write-Host "[temp] $d : $(Get-DirSizeMB $d) MB"
        Invoke-Step "clear $d" {
            Get-ChildItem $d -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

if ($Targets -contains 'recyclebin') {
    Invoke-Step "empty Recycle Bin" { Clear-RecycleBin -Force -ErrorAction SilentlyContinue }
}

if ($Targets -contains 'update') {
    $wu = "$env:WINDIR\SoftwareDistribution\Download"
    Write-Host "[update] $wu : $(Get-DirSizeMB $wu) MB"
    Invoke-Step "clear Windows Update download cache" {
        Stop-Service wuauserv -Force
        Get-ChildItem $wu -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Start-Service wuauserv
    }
}

if ($Targets -contains 'npm' -and (Get-Command npm -ErrorAction SilentlyContinue)) {
    Invoke-Step "npm cache clean --force" { npm cache clean --force }
}

if ($Targets -contains 'pip' -and (Get-Command pip -ErrorAction SilentlyContinue)) {
    Invoke-Step "pip cache purge" { pip cache purge }
}

if ($Targets -contains 'docker' -and (Get-Command docker -ErrorAction SilentlyContinue)) {
    docker system df
    # No -a: keeps tagged images. Volumes untouched — they may hold unique data.
    Invoke-Step "docker system prune -f" { docker system prune -f }
    Invoke-Step "docker builder prune -f" { docker builder prune -f }
}

if ($Apply) {
    $freed = ((Get-PSDrive C).Free - $freeBefore) / 1MB
    Write-Host ("`nFreed ~{0:N0} MB on C:" -f $freed)
} else {
    Write-Host "`nNothing was deleted. Review the list, then rerun with -Apply."
}
