@echo off
setlocal

echo ==========================================
echo  Building PolyGlotDoc AI for Windows
echo ==========================================

set "ROOT_DIR=%~dp0..\.."
set "FLUTTER_DIR=%ROOT_DIR%\frontend_flutter"
set "DIST_DIR=%ROOT_DIR%\dist\windows"

if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"

cd /d "%FLUTTER_DIR%"
echo Running Flutter build windows --release...
call flutter build windows --release
if errorlevel 1 (
    echo Error during Flutter build!
    exit /b %errorlevel%
)

echo Windows build completed successfully!

REM Check for Inno Setup compiler
set "ISCC_EXE="
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" set "ISCC_EXE=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if exist "C:\Program Files\Inno Setup 6\ISCC.exe" set "ISCC_EXE=C:\Program Files\Inno Setup 6\ISCC.exe"

if defined ISCC_EXE (
    echo Compiling Setup Installer with Inno Setup...
    "%ISCC_EXE%" "%ROOT_DIR%\packaging\windows\installer.iss"
    echo Setup installer generated in %DIST_DIR%!
) else (
    echo To build the setup installer, compile packaging\windows\installer.iss with InnoSetup.
)

endlocal
