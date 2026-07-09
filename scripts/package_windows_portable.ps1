param(
  [string]$OutputRoot = "dist"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseDir = Join-Path $repoRoot "build\windows\x64\runner\Release"
$portableDir = Join-Path $repoRoot "$OutputRoot\BiomedServis_Portable"
$dataDir = Join-Path $portableDir "BiomedServis_Data"
$workspaceDir = Join-Path $dataDir "Workspace"
$backupDir = Join-Path $workspaceDir "Backups"

Push-Location $repoRoot
try {
  flutter build windows --release

  if (Test-Path $portableDir) {
    Remove-Item -LiteralPath $portableDir -Recurse -Force
  }
  New-Item -ItemType Directory -Path $portableDir | Out-Null
  Copy-Item -Path (Join-Path $releaseDir "*") -Destination $portableDir -Recurse -Force

  New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

  @"
Biomed Servis Portable Paket

Bu paket kurulum gerektirmeden calisir.

Kullanim:
1. BiomedServis_Portable klasorunu herhangi bir bilgisayara veya USB diske kopyalayin.
2. biomed_serv.exe dosyasini calistirin.
3. Ilk kurulumda calisma yolu olarak varsayilan BiomedServis_Data\Workspace yolunu kullanabilirsiniz.
4. Yedekler BiomedServis_Data\Workspace\Backups klasorune Excel ve CSV iceren ZIP olarak kaydedilir.

Onemli:
- BiomedServis_Data klasoru veritabani ve yedekleri tasir.
- USB ile tasirken bu klasoru uygulama dosyalariyla birlikte tutun.
- Uygulama klasoru yazilabilir degilse uygulama kullanici Belgeler alanina gecer.
"@ | Set-Content -LiteralPath (Join-Path $portableDir "BiomedServis_Portable_Notlari.txt") -Encoding UTF8

  Write-Host "Portable paket hazir: $portableDir"
}
finally {
  Pop-Location
}
