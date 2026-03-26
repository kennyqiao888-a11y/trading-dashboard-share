$ErrorActionPreference = 'Stop'

$workspace = 'C:\Users\USER\.openclaw\workspace'
$sourceApp = Join-Path $workspace 'apps\trading-dashboard'
$shareApp = Join-Path $workspace 'apps\trading-dashboard-share'
$tradingDir = Join-Path $workspace 'trading'
$reportsDir = Join-Path $shareApp 'reports'

New-Item -ItemType Directory -Force -Path $shareApp | Out-Null
New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null

# 1) 先重建主 dashboard 数据
node (Join-Path $sourceApp 'build-dashboard-data.js') | Out-Null

# 2) 同步最新页面结构到 share 版
Copy-Item (Join-Path $sourceApp 'index.html') (Join-Path $shareApp 'index.html') -Force

# 3) 复制最新数据文件到 share 版，并修正 PDF 路径
$srcData = Join-Path $sourceApp 'dashboard-data.js'
$dstData = Join-Path $shareApp 'dashboard-data.js'
$text = [System.IO.File]::ReadAllText($srcData, [System.Text.UTF8Encoding]::new($false))
$text = $text -replace '\.\.\/\.\.\/\.\.\/trading\/','reports/'
$text = $text -replace '\.\.\/\.\.\/trading\/','reports/'
[System.IO.File]::WriteAllText($dstData, $text, [System.Text.UTF8Encoding]::new($false))

# 4) 复制 share 页所需 PDF
Get-ChildItem $tradingDir -Filter '*daily-report-*.pdf' | ForEach-Object {
  Copy-Item $_.FullName (Join-Path $reportsDir $_.Name) -Force
}

# 5) 验证 share 数据源里引用的 PDF 是否都实际存在
powershell -ExecutionPolicy Bypass -File (Join-Path $shareApp 'validate-share.ps1') | Out-Null

# 6) 自动提交并推送到 GitHub（如果有变更）
Push-Location $shareApp
try {
  git add . | Out-Null
  $status = git status --porcelain
  if ($status) {
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    git commit -m "Auto refresh share site $stamp" | Out-Null
    git push origin main | Out-Null
    Write-Output 'share refresh done + pushed'
  } else {
    Write-Output 'share refresh done (no changes)'
  }
  Write-Output $shareApp
}
finally {
  Pop-Location
}
