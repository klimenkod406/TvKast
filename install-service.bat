@echo off
set APP_DIR=%ProgramFiles%\DigitalSignage
set NODE_EXE=%ProgramFiles%\nodejs\node.exe
set NSSM=%APP_DIR%\service\nssm.exe

%NSSM% install DigitalSignage "%NODE_EXE%" "%APP_DIR%\src\server.js"
%NSSM% set DigitalSignage DisplayName "Digital Signage Server"
%NSSM% set DigitalSignage Start SERVICE_AUTO_START
%NSSM% set DigitalSignage DependOnService postgresql-x64-14
%NSSM% start DigitalSignage
