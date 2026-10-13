@echo off
setlocal

if "%~1"=="" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-apk-local.ps1"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-apk-local.ps1" -Ip "%~1"
)

exit /b %errorlevel%
