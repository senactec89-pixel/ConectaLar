@echo off
setlocal

set "ROOT=%USERPROFILE%\Downloads"
set "NODE_HOME=%ROOT%\tools\node-v24.20.0-win-x64"
set "MYSQL_HOME=%ROOT%\tools\mysql-8.4.9-winx64\bin"
set "PATH=%NODE_HOME%;%MYSQL_HOME%;%PATH%"

set "NODE_ENV=development"
set "HOST=0.0.0.0"
set "PORT=3012"
set "DB_HOST=127.0.0.1"
set "DB_PORT=3307"
set "DB_USER=conectalar_app"
set "DB_PASSWORD=ConectaLarDev123!"
set "DB_NAME=conectalar_dev"
set "AUTH_TOKEN_SECRET=local-dev-secret-change-before-production-123456"

if exist "%~dp0.env.local" (
  for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%~dp0.env.local") do (
    if not "%%A"=="" set "%%A=%%~B"
  )
)

if /I "%~1"=="--no-build" goto start_api

call npm.cmd run build
if errorlevel 1 exit /b %errorlevel%

:start_api
node dist/main.js
