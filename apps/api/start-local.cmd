@echo off
setlocal

set "ROOT=%USERPROFILE%\Downloads"
if not defined NODE_HOME set "NODE_HOME=%ROOT%\tools\node-v24.20.0-win-x64"
if not defined MYSQL_HOME set "MYSQL_HOME=%ROOT%\tools\mysql-8.4.9-winx64\bin"

pushd "%~dp0"

set "NODE_ENV=development"
set "HABILITACAO_MANUAL_LOCAL=true"
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

if exist "%NODE_HOME%\node.exe" set "PATH=%NODE_HOME%;%PATH%"
if exist "%MYSQL_HOME%\mysql.exe" set "PATH=%MYSQL_HOME%;%PATH%"
node -e "const [major,minor]=process.versions.node.split('.').map(Number);if (!((major===22&&minor>=13)||(major===24&&minor>=15)||major>24))process.exit(1)"
if errorlevel 1 (
  echo ConectaLar API requer Node 22.13+ ou 24.15+. Configure NODE_HOME ou PATH.
  exit /b 1
)

if /I "%~1"=="--no-build" goto start_api

call npm.cmd run build
if errorlevel 1 exit /b %errorlevel%

:start_api
node dist/main.js
