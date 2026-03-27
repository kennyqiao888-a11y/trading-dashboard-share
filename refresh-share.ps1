$ErrorActionPreference = 'Stop'

$workspace = 'C:\Users\USER\.openclaw\workspace'
$sourceApp = Join-Path $workspace 'apps\trading-dashboard'
$shareApp = Join-Path $workspace 'apps\trading-dashboard-share'
$tradingDir = Join-Path $workspace 'trading'
$reportsDir = Join-Path $shareApp 'reports'

New-Item -ItemType Directory -Force -Path $shareApp | Out-Null
New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null

# 1) 严格重建主 dashboard 数据；失败即中止
node (Join-Path $sourceApp 'build-dashboard-data.js')
if ($LASTEXITCODE -ne 0) {
  throw "build-dashboard-data.js failed with exit code $LASTEXITCODE"
}

# 2) 同步页面结构
Copy-Item (Join-Path $sourceApp 'index.html') (Join-Path $shareApp 'index.html') -Force

# 3) 复制数据文件到 share 版，并修正 PDF 路径
$srcData = Join-Path $sourceApp 'dashboard-data.js'
$dstData = Join-Path $shareApp 'dashboard-data.js'
$text = [System.IO.File]::ReadAllText($srcData, [System.Text.UTF8Encoding]::new($false))
$text = $text -replace '\.\./\.\./trading/','reports/'
[System.IO.File]::WriteAllText($dstData, $text, [System.Text.UTF8Encoding]::new($false))

# 4) 仅复制 share dashboard-data.js 实际引用到的 PDF，并清掉陈旧文件
$matches = [regex]::Matches($text, 'reports/([^"'']+\.pdf)')
$expected = @($matches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
if ($expected.Count -eq 0) {
  throw 'No PDF references found in share dashboard-data.js after rewrite'
}

Get-ChildItem $reportsDir -File -Filter *.pdf | ForEach-Object {
  if ($expected -notcontains $_.Name) {
    Remove-Item $_.FullName -Force
  }
}

foreach ($name in $expected) {
  $srcPdf = Join-Path $tradingDir $name
  if (!(Test-Path $srcPdf)) {
    throw "Referenced PDF missing in trading dir: $name"
  }
  if ((Get-Item $srcPdf).Length -le 0) {
    throw "Referenced PDF is empty in trading dir: $name"
  }
  Copy-Item $srcPdf (Join-Path $reportsDir $name) -Force
}

# 5) 严格校验 share 与 source 一致
powershell -ExecutionPolicy Bypass -File (Join-Path $shareApp 'validate-share.ps1')
if ($LASTEXITCODE -ne 0) {
  throw "validate-share.ps1 failed with exit code $LASTEXITCODE"
}

# 6) 自动提交并推送到 GitHub（如果有变更）
Push-Location $shareApp
try {
  git add .
  $status = git status --porcelain
  if ($status) {
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    git commit -m "Auto refresh share site $stamp"
    git push origin main
    Write-Output 'share refresh done + pushed'
  } else {
    Write-Output 'share refresh done (no changes)'
  }
  Write-Output $shareApp
}
finally {
  Pop-Location
}
