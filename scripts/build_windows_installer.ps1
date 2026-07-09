param(
  [string]$ProjectRoot = "E:\AndroidStudioProjects\biomed_serv",
  [string]$OutputRoot = "$env:USERPROFILE\Desktop\Output\BiomedServis_Windows_Stable",
  [string]$Configuration = "release"
)

$ErrorActionPreference = "Stop"

function Get-PubspecVersion {
  param([string]$PubspecPath)

  $versionLine = Select-String -Path $PubspecPath -Pattern '^version:\s*([0-9A-Za-z\.\+\-]+)' | Select-Object -First 1
  if (-not $versionLine) {
    throw "pubspec.yaml icinde surum bulunamadi."
  }

  $rawVersion = $versionLine.Matches[0].Groups[1].Value
  return ($rawVersion -split '\+')[0]
}

$pubspecPath = Join-Path $ProjectRoot 'pubspec.yaml'
$installerDir = Join-Path $ProjectRoot 'installer\windows'
$issPath = Join-Path $installerDir 'BiomedServis_SetupWizard.iss'
$installerOutputDir = Join-Path $installerDir 'Output'
$releaseDir = Join-Path $ProjectRoot 'build\windows\x64\runner\Release'
$desktopOutputDir = Join-Path $OutputRoot 'WindowsInstaller'
$portableOutputDir = Join-Path $OutputRoot 'WindowsPortable'

$iscc = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
if (-not (Test-Path $iscc)) {
  throw "Inno Setup compiler bulunamadi: $iscc"
}

$appVersion = Get-PubspecVersion -PubspecPath $pubspecPath

Push-Location $ProjectRoot
try {
  Write-Host "Flutter Windows release build baslatiliyor..."
  flutter build windows --$Configuration

  if (Test-Path $installerOutputDir) {
    Remove-Item -LiteralPath $installerOutputDir -Recurse -Force
  }
  New-Item -ItemType Directory -Path $installerOutputDir | Out-Null

  Write-Host "Inno Setup derlemesi baslatiliyor..."
  & $iscc "/DMyAppVersion=$appVersion" "/DMyAppOutputBase=BiomedServis_Setup" $issPath
}
finally {
  Pop-Location
}

if (Test-Path $OutputRoot) {
  Remove-Item -LiteralPath $OutputRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $desktopOutputDir | Out-Null
New-Item -ItemType Directory -Path $portableOutputDir | Out-Null

$installerFile = Join-Path $installerOutputDir 'BiomedServis_Setup.exe'
if (-not (Test-Path $installerFile)) {
  throw "Installer dosyasi uretilmedi: $installerFile"
}

Copy-Item -LiteralPath $installerFile -Destination (Join-Path $desktopOutputDir 'BiomedServis_Setup.exe')
Copy-Item -LiteralPath $issPath -Destination (Join-Path $OutputRoot 'BiomedServis_SetupWizard.iss')
Copy-Item -LiteralPath (Join-Path $installerDir 'SETUP_NOTES.txt') -Destination (Join-Path $OutputRoot 'SETUP_NOTES.txt')
Copy-Item -Path (Join-Path $releaseDir '*') -Destination $portableOutputDir -Recurse

Write-Host ""
Write-Host "Hazir:"
Write-Host "Installer: $(Join-Path $desktopOutputDir 'BiomedServis_Setup.exe')"
Write-Host "Portable:  $portableOutputDir"
