@echo off
setlocal

if "%~1"=="/?" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0configurar-email-local.ps1" -Help
  exit /b %errorlevel%
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0configurar-email-local.ps1" %*
exit /b %errorlevel%
