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
    echo Error during build!
    exit /b %errorlevel%
)

echo Windows build completed successfully!
echo Binary located at: %FLUTTER_DIR%\build\windows\x64\runner\Release\
echo To build the setup installer, compile packaging\windows\installer.iss with InnoSetup.
endlocal
