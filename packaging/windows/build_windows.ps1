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

Write-Host ">> Packaging ZIP portable archive..." -ForegroundColor Yellow
$ReleaseDir = Join-Path $FlutterDir "build\windows\x64\runner\Release"
$ZipPath = Join-Path $DistDir "PolyGlotDoc_AI_Windows_Portable.zip"

if (Test-Path $ZipPath) { Remove-Item -Force $ZipPath }
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $ZipPath -CompressionLevel Optimal

Write-Host "==========================================" -ForegroundColor Green
Write-Host " Windows Build & ZIP package created: $ZipPath" -ForegroundColor Green
Write-Host " To compile the .exe installer, run InnoSetup on installer.iss" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
