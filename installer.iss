; ============================================================
; Electrical Store - Inno Setup Installer Configuration
; Prerequisites:
;   1) flutter build windows --release
;   2) Compile this script with Inno Setup Compiler (ISCC)
; Or run: powershell -ExecutionPolicy Bypass -File build_installer.ps1
; ============================================================

#define MyAppName "Electrical Store"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Osama"
#define MyAppExeName "electrical_store.exe"
#define MyAppURL ""

; Path to the Flutter release build output (relative to this .iss file)
#define BuildDir SourcePath + "\build\windows\x64\runner\Release"

[Setup]
AppId={{E8A1B2C3-D4E5-F6A7-B8C9-D0E1F2A3B4C5}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=installer_output
OutputBaseFilename=ElectricalStore_Setup_{#MyAppVersion}
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
AllowNoIcons=yes
CloseApplications=yes
RestartApplications=no

; Minimum Windows version (Windows 10)
MinVersion=10.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main executable
Source: "{#BuildDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; All plugin / runtime DLLs (sqlite, flutter, printing, etc.)
Source: "{#BuildDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion

; Data folder (app.so, icudtl.dat, flutter_assets)
Source: "{#BuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; Do NOT ship d.db — database is created under Documents\electrical_store

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; App data lives under Documents (see database_helper.dart)
Type: filesandordirs; Name: "{userdocs}\electrical_store"
Type: files; Name: "{app}\*.db"
Type: files; Name: "{app}\*.db-wal"
Type: files; Name: "{app}\*.db-shm"
