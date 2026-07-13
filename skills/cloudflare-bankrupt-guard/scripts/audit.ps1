param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Path = @('.'),
  [switch]$Strict
)

function Test-TextFile([string]$FilePath) {
  $ext = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
  return $ext -in @('.js','.ts','.tsx','.jsx','.py','.sh','.ps1','.json','.yaml','.yml','.toml','.md','.env')
}

$major = 0

foreach ($p in $Path) {
  if (Test-Path -LiteralPath $p -PathType Container) {
    Get-ChildItem -LiteralPath $p -File -Recurse | ForEach-Object {
      if (-not (Test-TextFile $_.FullName)) { return }
      $content = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue
      if ($null -eq $content) { return }

      if ($content -match '(?i)fetch\(|axios\.|requests\.|urllib|curl .*deepseek|direct.*deepseek') {
        Write-Host "[major] possible direct model access: $($_.FullName)"
        $major++
      }

      if ($content -match '(?i)max_tokens|max completion|max_output|max_output_tokens|temperature|top_p') {
        return
      }
      Write-Host "[minor] no obvious output bound found: $($_.FullName)"
    }
  } elseif (Test-Path -LiteralPath $p -PathType Leaf) {
    if (-not (Test-TextFile $p)) { continue }
    $content = Get-Content -LiteralPath $p -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content) { continue }
    if ($content -match '(?i)fetch\(|axios\.|requests\.|urllib|curl .*deepseek|direct.*deepseek') {
      Write-Host "[major] possible direct model access: $p"
      $major++
    }
    if ($content -notmatch '(?i)max_tokens|max completion|max_output|max_output_tokens|temperature|top_p') {
      Write-Host "[minor] no obvious output bound found: $p"
    }
  }
}

if ($Strict -and $major -gt 0) {
  exit 1
}
