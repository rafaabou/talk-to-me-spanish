@echo off
REM Portable launcher for Windows: double-click RUN.bat
REM Needs only Python 3 from https://www.python.org/downloads/ (works offline).
cd /d "%~dp0"

set APP_NAME=Talk To Me Spanish
set PORT=8002
set WEB_DIR=app\build\web

python --version >nul 2>&1
if errorlevel 1 (
  echo No Python found - trying built-in PowerShell server instead...
  powershell -ExecutionPolicy Bypass -File "%~dp0RUN.ps1" -Port %PORT%
  pause
  exit /b 0
)

if not exist "%WEB_DIR%\index.html" (
  echo ERROR: prebuilt web app not found in %WEB_DIR%
  echo On a machine with Flutter, run:  cd app ^&^& flutter build web --release
  pause
  exit /b 1
)

REM Windows: copy (not symlink) double-nested assets if missing - needs no admin rights
if exist "%WEB_DIR%\assets\assets\audio" if not exist "%WEB_DIR%\assets\audio" (
  echo Fixing audio paths...
  mkdir "%WEB_DIR%\assets\audio" >nul 2>&1
  xcopy "%WEB_DIR%\assets\assets\audio\*.opus" "%WEB_DIR%\assets\audio\" /Q /Y >nul
)
if exist "%WEB_DIR%\assets\assets\course" if not exist "%WEB_DIR%\assets\course" (
  mkdir "%WEB_DIR%\assets\course" >nul 2>&1
  xcopy "%WEB_DIR%\assets\assets\course" "%WEB_DIR%\assets\course\" /Q /Y /E >nul
)

echo Starting %APP_NAME% on http://localhost:%PORT% ...
start "" "http://localhost:%PORT%"
python serve_web.py %PORT% "%WEB_DIR%"
pause
