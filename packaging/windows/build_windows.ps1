# PowerShell script to build and package PolyGlotDoc AI for Windows
$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Building PolyGlotDoc AI for Windows       " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$FlutterDir = Join-Path $RootDir "frontend_flutter"
$DistDir = Join-Path $RootDir "dist\windows"

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

Set-Location $FlutterDir
Write-Host ">> Compiling Flutter Windows release..." -ForegroundColor Yellow
flutter build windows --release

Write-Host ">> Locating Release files..." -ForegroundColor Yellow
$ReleaseDir = Join-Path $FlutterDir "build\windows\x64\runner\Release"
if (-not (Test-Path $ReleaseDir)) {
    $ReleaseDir = Join-Path $FlutterDir "build\windows\runner\Release"
}

if (-not (Test-Path $ReleaseDir)) {
    Write-Error "Could not find build output directory: $ReleaseDir"
    exit 1
}

Write-Host ">> Packaging ZIP portable archive..." -ForegroundColor Yellow
$ZipPath = Join-Path $DistDir "PolyGlotDoc_AI_Windows_Portable.zip"
if (Test-Path $ZipPath) { Remove-Item -Force $ZipPath }
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $ZipPath -CompressionLevel Optimal

Write-Host ">> Checking for Inno Setup compiler (iscc)..." -ForegroundColor Yellow
$isccPaths = @(
    "iscc",
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "C:\ProgramData\chocolatey\bin\iscc.exe"
)

$isccFound = $null
foreach ($p in $isccPaths) {
    if (Get-Command $p -ErrorAction SilentlyContinue) {
        $isccFound = $p
        break
    }
    if (Test-Path $p) {
        $isccFound = $p
        break
    }
}

if ($isccFound) {
    Write-Host ">> Found Inno Setup at $isccFound. Compiling Windows Setup Installer..." -ForegroundColor Green
    $issScript = Join-Path $RootDir "packaging\windows\installer.iss"
    & $isccFound $issScript
    Write-Host ">> Inno Setup installer generated successfully in $DistDir!" -ForegroundColor Green
} else {
    Write-Host ">> Notice: Inno Setup compiler (ISCC) not found in PATH or standard dirs. Portable ZIP created." -ForegroundColor Yellow
}

Write-Host "==========================================" -ForegroundColor Green
Write-Host " Windows build and packages generated in: $DistDir" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
