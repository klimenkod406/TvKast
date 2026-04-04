@echo off
cd /d "%~dp0"
title Digital Signage Server
if not exist "%~dp0INSTALL_OK" (
    echo Please run Install.cmd first
    echo.
    pause
    exit /b 1
)
node "%~dp0src\server.js"
if errorlevel 1 pause
