$ErrorActionPreference = 'Stop'

$workspace = 'C:\Users\USER\.openclaw\workspace'
$shareApp = Join-Path $workspace 'apps\trading-dashboard-share'
$reportsDir = Join-Path $shareApp 'reports'
$dataPath = Join-Path $shareApp 'dashboard-data.js'

if (!(Test-Path $dataPath)) { throw "dashboard-data.js missing: $dataPath" }
if (!(Test-Path $reportsDir)) { throw "reports dir missing: $reportsDir" }

$text = Get-Content $dataPath -Raw -Encoding UTF8
$matches = [regex]::Matches($text, 'reports/([^"'']+\.pdf)')
$expected = @($matches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)

if ($expected.Count -eq 0) {
  throw 'No PDF report paths found in share dashboard-data.js'
}

$missing = @()
foreach ($name in $expected) {
  $path = Join-Path $reportsDir $name
  if (!(Test-Path $path)) { $missing += $name }
}

if ($missing.Count -gt 0) {
  Write-Output 'Missing report PDFs:'
  $missing | ForEach-Object { Write-Output " - $_" }
  throw "Share validation failed: $($missing.Count) report PDF(s) missing"
}

Write-Output "Share validation OK: $($expected.Count) PDF(s) referenced and present."
