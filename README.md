# Trading Dashboard Share

这是给外部分享用的股票模拟盘静态站点。

## 文件
- `index.html`：公开分享页
- `dashboard-data.js`：分享页读取的数据
- `reports/`：可公开访问的日报 PDF 副本
- `refresh-share.ps1`：从本地主 trading 数据同步 share 站点的脚本

## 用法
在 PowerShell 里运行：

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\USER\.openclaw\workspace\apps\trading-dashboard-share\refresh-share.ps1
```

运行后会：
1. 更新 `dashboard-data.js`
2. 复制最新日报 PDF 到 `reports/`
3. 保持 `index.html` 可直接部署到静态托管平台

## 适合部署到
- Cloudflare Pages
- Netlify
- GitHub Pages
