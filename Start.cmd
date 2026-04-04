@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
cd /d "%~dp0"
title Digital Signage Server
if not exist "%~dp0INSTALL_OK" (
  echo Snachala vypolnite ustanovku: zapustite Install.cmd
  echo.
  pause
  exit /b 1
)
node "%~dp0src\server.js"
if errorlevel 1 pause
