# Teigi distribution build script.
#
# Generates artifacts under build/outputdir:
#   release.zip             - app only
#   release-ffmpeg.zip      - app with bundled ffmpeg (extracted from PATH)
#   installer.exe           - Inno Setup installer with 3 ffmpeg options:
#                             1) no embed (use PATH)
#                             2) embed bundled ffmpeg (from PATH at build time)
#                             3) download latest ffmpeg from official site during install
#   release.msix            - optional MSIX (use -IncludeMsix)
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools\build_dist.ps1

param(
  [switch]$IncludeMsix
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path $root 'build\outputdir'
$releaseSrc = Join-Path $root 'build\windows\x64\runner\Release'
$ffmpegSrc = Join-Path $out 'ffmpeg-src'   # 供 installer 内嵌的 ffmpeg 源

# ---- [1/6] build release ----
Write-Host '==> [1/6] flutter build windows --release' -ForegroundColor Cyan
Push-Location $root
flutter build windows --release
$buildCode = $LASTEXITCODE
Pop-Location
if ($buildCode -ne 0) { throw 'flutter build --release failed' }

# ---- prepare dirs ----
New-Item -ItemType Directory -Force -Path $out | Out-Null
$relDir = Join-Path $out 'release'
$ffDir = Join-Path $out 'release-ffmpeg'
Remove-Item $relDir, $ffDir, $ffmpegSrc -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path (Join-Path $relDir 'Teigi') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $ffDir 'Teigi') | Out-Null

Copy-Item "$releaseSrc\*" (Join-Path $relDir 'Teigi') -Recurse -Force
Copy-Item "$releaseSrc\*" (Join-Path $ffDir 'Teigi') -Recurse -Force

# ---- [2/6] extract ffmpeg from PATH ----
Write-Host '==> [2/6] extracting ffmpeg from PATH' -ForegroundColor Cyan
$ffmpeg = (where.exe ffmpeg 2>$null | Select-Object -First 1)
$pathVersion = 'PATH'
$bundledVersion = 'bundled'
if ($ffmpeg) {
  $ffSrcDir = Split-Path $ffmpeg
  $ffDest = Join-Path (Join-Path $ffDir 'Teigi\data') 'ffmpeg'
  New-Item -ItemType Directory -Force -Path $ffDest | Out-Null
  New-Item -ItemType Directory -Force -Path $ffmpegSrc | Out-Null
  Copy-Item $ffmpeg -Destination $ffDest -Force
  Copy-Item $ffmpeg -Destination $ffmpegSrc -Force
  Get-ChildItem $ffSrcDir -Filter '*.dll' -ErrorAction SilentlyContinue |
    ForEach-Object {
      Copy-Item $_.FullName -Destination $ffDest -Force
      Copy-Item $_.FullName -Destination $ffmpegSrc -Force
    }
  # ffmpeg 版本号
  $verLine = & $ffmpeg -version 2>&1 | Select-Object -First 1
  $m = [regex]::Match("$verLine", 'version\s+(\S+)')
  if ($m.Success) {
    $pathVersion = $m.Groups[1].Value
    $bundledVersion = $pathVersion
  }
  Write-Host "embedded ffmpeg: $ffmpeg ($pathVersion)" -ForegroundColor Green
} else {
  Write-Warning 'ffmpeg not found in PATH; release-ffmpeg.zip and embedded option will be empty'
}

# 联网获取项的版本号占位。gyan.dev 没有公开 API、且不同来源的版本号体系
# （gyan.dev / BtbN）不一致；安装时直接从 gyan.dev 下载最新版，文案中不再
# 展示具体版本号。
$latestVersion = 'latest'
Write-Host "versions -> PATH: $pathVersion | bundled: $bundledVersion | latest: (gyan.dev at install time)" -ForegroundColor Cyan

# ---- [3/6] zip ----
Write-Host '==> [3/6] creating zip archives' -ForegroundColor Cyan
Compress-Archive -Path "$relDir\*" -DestinationPath (Join-Path $out 'release.zip') -Force
Compress-Archive -Path "$ffDir\*" -DestinationPath (Join-Path $out 'release-ffmpeg.zip') -Force

# ---- [4/6] Inno Setup installer ----
Write-Host '==> [4/6] building installer.exe (Inno Setup)' -ForegroundColor Cyan
$iscc = @(
  'C:\Program Files\Inno Setup 7\ISCC.exe',
  'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
  'C:\Program Files (x86)\Inno Setup 5\ISCC.exe'
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($iscc) {
  $issPath = Join-Path $PSScriptRoot 'teigi_installer.iss'
  # 确保 .iss 为 UTF-8 BOM，避免中文被 ISCC 误读。
  $issContent = Get-Content -Raw -Encoding UTF8 $issPath
  [System.IO.File]::WriteAllText($issPath, $issContent, (New-Object System.Text.UTF8Encoding $true))
  # 传递给 .iss 的版本号 /D 定义。
  $defines = @(
    "/DMyPathVersion=$pathVersion",
    "/DBundledVersion=$bundledVersion",
    "/DLatestVersion=$latestVersion"
  )
  & $iscc $defines $issPath
  $setup = Join-Path $out 'TeigiSetup.exe'
  if (Test-Path $setup) {
    Copy-Item $setup (Join-Path $out 'installer.exe') -Force
    Write-Host 'created installer.exe' -ForegroundColor Green
  } else {
    Write-Warning 'Inno Setup did not produce TeigiSetup.exe'
  }
} else {
  Write-Warning 'Inno Setup not found; skipped installer.exe'
}

# ---- [5/6] MSIX (optional) ----
if ($IncludeMsix) {
  Write-Host '==> [5/6] building MSIX' -ForegroundColor Cyan
  Push-Location $root
  try {
    dart run msix:create
  } catch {
    Write-Warning 'msix:create failed'
  }
  Pop-Location
  $msix = Get-ChildItem "$releaseSrc\*.msix" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($msix) {
    Copy-Item $msix.FullName (Join-Path $out 'release.msix') -Force
    Write-Host 'created release.msix' -ForegroundColor Green
  } else {
    Write-Warning 'no msix output found'
  }
} else {
  Write-Host '==> [5/6] skipped MSIX (use -IncludeMsix)' -ForegroundColor DarkGray
}

# ---- [6/6] summary ----
Write-Host ''
Write-Host "Done! Artifacts in: $out" -ForegroundColor Green
Get-ChildItem $out -File | Select-Object Name, @{N='MB';E={[math]::Round($_.Length/1MB,1)}} | Format-Table -AutoSize
