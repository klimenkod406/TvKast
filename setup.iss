; Inno Setup Script — Digital Signage Unified Installer
; Откройте в Inno Setup Compiler и скомпилируйте setup.exe

#define MyAppName "Digital Signage"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "TvKast"
#define MyAppURL "http://localhost:3000"

[Setup]
AppId={{B5E8F2A1-4C3D-4E9F-8A1B-2C3D4E5F6078}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\DigitalSignage
DefaultGroupName={#MyAppName}
OutputDir=installer-output
OutputBaseFilename=DigitalSignage-Setup-v{#MyAppVersion}
Compression=lzma2/max
SolidCompression=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64
DisableProgramGroupPage=yes
WizardStyle=modern
WizardImageFile=
WizardSmallImageFile=
SetupIconFile=
UninstallDisplayIcon={app}\src\server.js

; Поддержка Unicode/кириллицы
SignedUninstaller=yes

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Files]
; Все файлы проекта (исключая node_modules и .git)
Source: "*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "node_modules\*,.git\*,installer-output\*,*.log,INSTALL_OK"

[Icons]
Name: "{group}\{#MyAppName} — Установка"; Filename: "{app}\Install.ps1"; WorkingDir: "{app}"; IconFilename: "{sys}\shell32.dll"; IconIndex: 14
Name: "{group}\{#MyAppName} — Запуск сервера"; Filename: "{app}\node.exe"; Parameters: """{app}\src\server.js"""; WorkingDir: "{app}"
Name: "{group}\{#MyAppName} — Админ-панель (браузер)"; Filename: "http://localhost:3000/admin/login.html"; IconFilename: "{sys}\shell32.dll"; IconIndex: 14
Name: "{group}\{#MyAppName} — Лог установки"; Filename: "{%TEMP}\DigitalSignage-Setup.log"
Name: "{commondesktop}\{#MyAppName} — Запуск"; Filename: "{app}\node.exe"; Parameters: """{app}\src\server.js"""; WorkingDir: "{app}"
Name: "{commondesktop}\{#MyAppName} — Документация"; Filename: "{app}\README.md"; IconFilename: "{sys}\shell32.dll"; IconIndex: 14

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Install.ps1"""; Description: "Запустить мастер установки"; Flags: postinstall shellexec skipifsilent nowait; WorkingDir: "{app}"

[Code]
function InitializeSetup(): Boolean;
var
  NodeResult: Integer;
  NodeOutput: String;
begin
  Result := True;

  // Проверяем Node.js
  if not Exec('cmd.exe', '/c node -v', '', SW_HIDE, ewWaitUntilTerminated, NodeResult) then
  begin
    MsgBox('Node.js не найден! Пожалуйста, установите Node.js 18+ с https://nodejs.org/', mbError, MB_OK);
    Result := False;
    Exit;
  end;

  // Проверяем PostgreSQL
  try
    if not RegKeyExists(HKLM, 'SOFTWARE\PostgreSQL\Installations') then
    begin
      if MsgBox('PostgreSQL не обнаружен. Продолжить установку? (PostgreSQL нужно установить отдельно)', mbConfirmation, MB_YESNO) = IDNO then
      begin
        Result := False;
        Exit;
      end;
    end;
  except
    // Игнорируем ошибки реестра
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // Создаём каталог media
    ForceDir(ExpandConstant('{app}\media\original'));
    ForceDir(ExpandConstant('{app}\media\converted'));
    ForceDir(ExpandConstant('{app}\media\metadata'));
    ForceDir(ExpandConstant('{app}\logs'));
  end;
end;
