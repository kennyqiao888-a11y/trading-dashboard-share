$ErrorActionPreference = 'Stop'

$workspace = 'C:\Users\USER\.openclaw\workspace'
$sourceApp = Join-Path $workspace 'apps\trading-dashboard'
$shareApp = Join-Path $workspace 'apps\trading-dashboard-share'
$reportsDir = Join-Path $shareApp 'reports'
$shareDataPath = Join-Path $shareApp 'dashboard-data.js'
$sourceDataPath = Join-Path $sourceApp 'dashboard-data.js'

if (!(Test-Path $sourceDataPath)) { throw "source dashboard-data.js missing: $sourceDataPath" }
if (!(Test-Path $shareDataPath)) { throw "share dashboard-data.js missing: $shareDataPath" }
if (!(Test-Path $reportsDir)) { throw "reports dir missing: $reportsDir" }

$sourceText = Get-Content $sourceDataPath -Raw -Encoding UTF8
$shareText = Get-Content $shareDataPath -Raw -Encoding UTF8

$sourceRefs = @([regex]::Matches($sourceText, '\.\./\.\./trading/([^"'']+\.pdf)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
$shareRefs = @([regex]::Matches($shareText, 'reports/([^"'']+\.pdf)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)

if ($sourceRefs.Count -eq 0) { throw 'No PDF report paths found in source dashboard-data.js' }
if ($shareRefs.Count -eq 0) { throw 'No PDF report paths found in share dashboard-data.js' }

$diff = Compare-Object -ReferenceObject $sourceRefs -DifferenceObject $shareRefs
if ($diff) {
  Write-Output 'Reference mismatch between source/share dashboard-data.js:'
  $diff | ForEach-Object { Write-Output " - $($_.SideIndicator) $($_.InputObject)" }
  throw 'Share validation failed: source/share PDF references differ'
}

$missing = @()
foreach ($name in $shareRefs) {
  $path = Join-Path $reportsDir $name
  if (!(Test-Path $path)) {
    $missing += $name
    continue
  }
  if ((Get-Item $path).Length -le 0) { $missing += "$name (empty)" }
}
if ($missing.Count -gt 0) {
  Write-Output 'Missing or empty report PDFs:'
  $missing | ForEach-Object { Write-Output " - $_" }
  throw "Share validation failed: $($missing.Count) report PDF(s) missing or empty"
}

# Share data must preserve latest integrity date from source
$ledgerDates = @([regex]::Matches($sourceText, '"ledgerDate":\s*"(\d{4}-\d{2}-\d{2})"') | ForEach-Object { $_.Groups[1].Value })
if ($ledgerDates.Count -lt 2) { throw 'Source dashboard-data.js missing integrity ledgerDate markers' }
foreach ($date in $ledgerDates) {
  if ($shareText -notmatch [regex]::Escape('"ledgerDate": "' + $date + '"')) {
    throw "Share validation failed: ledgerDate $date missing from share dashboard-data.js"
  }
}

Write-Output "Share validation OK: $($shareRefs.Count) PDF(s) referenced, present, and aligned with source dashboard-data.js."
