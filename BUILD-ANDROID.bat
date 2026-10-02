@echo off
chcp 65001 >nul
cd /d "%~dp0"
title RMUTT - Build Android
echo ==== Build Android APK ====
echo.
if not exist android\key.properties (
  echo [1/2] create signing key - set a password of 8+ characters and WRITE IT DOWN
  powershell -NoProfile -ExecutionPolicy Bypass -File create-keystore.ps1
) else (
  echo [1/2] signing key already exists - skip
)
echo.
echo [2/2] build APK - takes 5-15 minutes the first time
powershell -NoProfile -ExecutionPolicy Bypass -File build-apk.ps1 -ApiBaseUrl https://rmutt-energy.tailb292b4.ts.net/api
if exist build\app\outputs\flutter-apk\app-release.apk explorer /select,"%cd%\build\app\outputs\flutter-apk\app-release.apk"
echo.
pause
