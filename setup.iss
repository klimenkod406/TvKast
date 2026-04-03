; Inno Setup — откройте в Inno Setup Compiler и соберите setup.exe

#define MyAppName "Digital Signage"
#define MyAppVersion "1.0.0"

[Setup]
AppId={{B5E8F2A1-4C3D-4E9F-8A1B-2C3D4E5F6078}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\DigitalSignage
DefaultGroupName={#MyAppName}
OutputBaseFilename=DigitalSignage-Setup
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64
DisableProgramGroupPage=yes

[Files]
Source: "*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "node_modules\*,.git\*"

[Icons]
Name: "{group}\{#MyAppName} — установка"; Filename: "{app}\Install.cmd"; WorkingDir: "{app}"
Name: "{group}\{#MyAppName} — запуск"; Filename: "{app}\Start.cmd"; WorkingDir: "{app}"
Name: "{commondesktop}\{#MyAppName} — установка"; Filename: "{app}\Install.cmd"; WorkingDir: "{app}"

[Run]
Filename: "{app}\Install.cmd"; Description: "Запустить мастер установки сейчас"; Flags: postinstall shellexec skipifsilent
