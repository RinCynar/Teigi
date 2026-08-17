# Teigi distribution build script.
#
# Artifacts under build/outputdir:
#   windows-x64-release.zip
#   windows-arm64-release.zip
#   windows-x64-ffmpeg-release.zip
#   windows-arm64-ffmpeg-release.zip
#   windows-x64-installer.exe
#   windows-arm64-installer.exe
#
# This Flutter SDK (3.44) has no --target-platform on `flutter build windows`.
# It always compiles for the host CPU:
#   x64 host   -> windows-x64
#   arm64 host -> windows-arm64
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools\build_dist.ps1
#   powershell -ExecutionPolicy Bypass -File tools\build_dist.ps1 -Arch x64

param(
  [ValidateSet('x64', 'arm64', 'all')]
  [string]$Arch = 'all'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path $root 'build\outputdir'
$issPath = Join-Path $PSScriptRoot 'teigi_installer.iss'

function Get-HostWindowsArch {
  $proc = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture
  if ($proc -eq [System.Runtime.InteropServices.Architecture]::Arm64) { return 'arm64' }
  return 'x64'
}

function Get-FfmpegFromPath {
  $exe = (where.exe ffmpeg 2>$null | Select-Object -First 1)
  if (-not $exe) { return $null }
  $dir = Split-Path $exe
  $verLine = & $exe -version 2>&1 | Select-Object -First 1
  $m = [regex]::Match("$verLine", 'version\s+(\S+)')
  return [pscustomobject]@{
    Exe     = $exe
    Dir     = $dir
    Version = $(if ($m.Success) { $m.Groups[1].Value } else { 'PATH' })
  }
}

function Copy-FfmpegBundle {
  param($Ffmpeg, [string]$DestDir)
  New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
  Copy-Item $Ffmpeg.Exe -Destination $DestDir -Force
  Get-ChildItem $Ffmpeg.Dir -Filter '*.dll' -ErrorAction SilentlyContinue |
    ForEach-Object { Copy-Item $_.FullName -Destination $DestDir -Force }
}

function Find-ReleaseDir {
  param([string]$ArchName)
  $candidates = @(
    (Join-Path $root "build\windows\$ArchName\runner\Release"),
    (Join-Path $root 'build\windows\runner\Release')
  )
  foreach ($c in $candidates) {
    if (Test-Path (Join-Path $c 'teigi.exe')) { return $c }
  }
  return $null
}

function Find-ISCC {
  @(
    'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
    'C:\Program Files\Inno Setup 7\ISCC.exe',
    'C:\Program Files (x86)\Inno Setup 5\ISCC.exe'
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}

function Build-HostArch {
  param([string]$Name, $Ffmpeg)

  Write-Host "==> building windows-$Name  (flutter build windows --release)" -ForegroundColor Cyan

  Push-Location $root
  try {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
      throw 'flutter build windows --release failed'
    }
  } finally {
    Pop-Location
  }

  $releaseSrc = Find-ReleaseDir -ArchName $Name
  if (-not $releaseSrc) {
    throw "Release output not found for $Name (looked under build/windows/$Name/runner/Release)"
  }

  $stage = Join-Path $out "staging\$Name"
  $relDir = Join-Path $stage 'release'
  $ffDir = Join-Path $stage 'release-ffmpeg'
  $ffmpegSrc = Join-Path $stage 'ffmpeg-src'
  Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path (Join-Path $relDir 'Teigi') | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $ffDir 'Teigi') | Out-Null

  Copy-Item "$releaseSrc\*" (Join-Path $relDir 'Teigi') -Recurse -Force
  Copy-Item "$releaseSrc\*" (Join-Path $ffDir 'Teigi') -Recurse -Force

  if ($Ffmpeg) {
    Copy-FfmpegBundle -Ffmpeg $Ffmpeg -DestDir (Join-Path $ffDir 'Teigi\data\ffmpeg')
    Copy-FfmpegBundle -Ffmpeg $Ffmpeg -DestDir $ffmpegSrc
  } else {
    Write-Warning "ffmpeg not in PATH; windows-$Name-ffmpeg-release.zip will not contain an engine"
  }

  $plainZip = Join-Path $out "windows-$Name-release.zip"
  $ffZip = Join-Path $out "windows-$Name-ffmpeg-release.zip"
  if (Test-Path $plainZip) { Remove-Item $plainZip -Force }
  if (Test-Path $ffZip) { Remove-Item $ffZip -Force }
  Compress-Archive -Path "$relDir\*" -DestinationPath $plainZip
  Compress-Archive -Path "$ffDir\*" -DestinationPath $ffZip
  Write-Host "created $(Split-Path $plainZip -Leaf) and $(Split-Path $ffZip -Leaf)" -ForegroundColor Green

  $iscc = Find-ISCC
  if (-not $iscc) {
    Write-Warning "Inno Setup not found; skipped windows-$Name-installer.exe"
    return
  }

  # PowerShell's UTF-8 reader preserves a BOM as U+FEFF in the returned string.
  # Remove every leading BOM before writing exactly one UTF-8 BOM; otherwise
  # Inno Setup interprets the extra BOM characters as text before the first
  # preprocessor directive and fails with "Text is not inside a section".
  $issContent = Get-Content -Raw -Encoding UTF8 $issPath
  $issContent = $issContent.TrimStart([char]0xFEFF)
  [System.IO.File]::WriteAllText(
    $issPath,
    $issContent,
    (New-Object System.Text.UTF8Encoding $true)
  )

  $pathVersion = if ($Ffmpeg) { $Ffmpeg.Version } else { 'PATH' }
  $defines = @(
    "/DTargetArch=$Name",
    "/DOutputName=windows-$Name-installer",
    "/DReleaseDir=$relDir",
    "/DFfmpegSrc=$ffmpegSrc",
    "/DMyPathVersion=$pathVersion",
    "/DBundledVersion=$pathVersion",
    '/DLatestVersion=latest'
  )
  & $iscc $defines $issPath
  if ($LASTEXITCODE -ne 0) {
    throw "ISCC failed for windows-$Name-installer.exe"
  }
  $installer = Join-Path $out "windows-$Name-installer.exe"
  if (Test-Path $installer) {
    Write-Host "created windows-$Name-installer.exe" -ForegroundColor Green
  } else {
    Write-Warning "Inno Setup did not produce windows-$Name-installer.exe"
  }
}

New-Item -ItemType Directory -Force -Path $out | Out-Null

$hostArch = Get-HostWindowsArch
Write-Host "Host Windows arch: $hostArch" -ForegroundColor Cyan
Write-Host 'Flutter 3.44 builds Windows only for the host CPU (no --target-platform).' -ForegroundColor DarkGray

$ffmpeg = Get-FfmpegFromPath
if ($ffmpeg) {
  Write-Host "PATH ffmpeg: $($ffmpeg.Exe) ($($ffmpeg.Version))" -ForegroundColor Green
} else {
  Write-Warning 'ffmpeg not found in PATH'
}

$wanted = if ($Arch -eq 'all') { @('x64', 'arm64') } else { @($Arch) }
$failed = @()
$built = @()

foreach ($name in $wanted) {
  if ($name -ne $hostArch) {
    Write-Warning "skip windows-$name : this PC is $hostArch. Flutter cannot cross-compile Windows $name from here."
    Write-Warning "Run this script on a Windows $name machine (or CI runner) to produce windows-$name-* artifacts."
    $failed += $name
    continue
  }
  try {
    Build-HostArch -Name $name -Ffmpeg $ffmpeg
    $built += $name
  } catch {
    Write-Warning "windows-$name failed: $_"
    # The application ZIPs are created before Inno Setup runs. Keep the
    # architecture counted as built when only the optional installer failed;
    # otherwise the script ends with the misleading "No architecture was
    # built" error even though usable ZIP artifacts exist.
    $plainZip = Join-Path $out "windows-$name-release.zip"
    $ffZip = Join-Path $out "windows-$name-ffmpeg-release.zip"
    if ((Test-Path $plainZip) -or (Test-Path $ffZip)) {
      $built += $name
      Write-Warning "windows-$name ZIP artifacts were created, but the installer failed."
    } else {
      $failed += $name
    }
  }
}

Write-Host ''
Write-Host "Done! Artifacts in: $out" -ForegroundColor Green
Get-ChildItem $out -File -ErrorAction SilentlyContinue |
  Select-Object Name, @{N = 'MB'; E = { [math]::Round($_.Length / 1MB, 1) } } |
  Format-Table -AutoSize

if ($built.Count -eq 0) {
  throw 'No architecture was built.'
}
if ($failed.Count -gt 0) {
  Write-Warning ("Not produced: " + ($failed -join ', '))
}
