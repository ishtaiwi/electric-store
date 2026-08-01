# Build Windows Release + compile Inno Setup installer
# Usage: powershell -ExecutionPolicy Bypass -File build_installer.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "==> Checking secrets..." -ForegroundColor Cyan
$secretsPath = "lib\core\config\supabase_secrets.dart"
if (-not (Test-Path $secretsPath)) {
  if (Test-Path "supabase\generate_secrets.py") {
    Write-Host "Generating supabase_secrets.dart from .env..."
    python supabase\generate_secrets.py
  } else {
    throw "Missing lib\core\config\supabase_secrets.dart - create it before release."
  }
}

Write-Host "==> flutter pub get" -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }

Write-Host "==> flutter build windows --release" -ForegroundColor Cyan
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "Flutter release build failed" }

$exe = "build\windows\x64\runner\Release\electrical_store.exe"
if (-not (Test-Path $exe)) { throw "Missing $exe" }

$dllCount = @(Get-ChildItem "build\windows\x64\runner\Release\*.dll" -ErrorAction SilentlyContinue).Count
Write-Host ("Release OK: {0} ({1} DLLs)" -f $exe, $dllCount) -ForegroundColor Green

$dataDir = "build\windows\x64\runner\Release\data"
if (-not (Test-Path "$dataDir\app.so") -and -not (Test-Path "$dataDir\flutter_assets")) {
  throw "Release data folder incomplete: $dataDir"
}

$isccCandidates = @(
  (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
  (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe"),
  (Join-Path $env:LocalAppData "Programs\Inno Setup 6\ISCC.exe")
)
$iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $iscc) {
  Write-Host "Inno Setup Compiler (ISCC.exe) not found." -ForegroundColor Yellow
  Write-Host "Install Inno Setup 6, then compile installer.iss - or re-run this script."
  Write-Host "Release folder is ready: build\windows\x64\runner\Release"
  exit 0
}

Write-Host "==> Compiling installer.iss with $iscc" -ForegroundColor Cyan
& $iscc "installer.iss"
if ($LASTEXITCODE -ne 0) { throw "ISCC failed" }

$setup = Get-ChildItem "installer_output\ElectricalStore_Setup_*.exe" -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if (-not $setup) { throw "Installer exe not found in installer_output" }

Write-Host ("Installer ready: {0}" -f $setup.FullName) -ForegroundColor Green
