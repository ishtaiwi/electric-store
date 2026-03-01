; ============================================================
; Electrical Store - Inno Setup Installer Configuration
; ============================================================

#define MyAppName "Electrical Store"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Osama"
#define MyAppExeName "electrical_store.exe"
#define MyAppURL ""

; Path to the Flutter release build output
#define BuildDir "build\windows\x64\runner\Release"

[Setup]
AppId={{E8A1B2C3-D4E5-F6A7-B8C9-D0E1F2A3B4C5}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
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
LicenseFile=
InfoBeforeFile=
InfoAfterFile=

; Minimum Windows version (Windows 10)
MinVersion=10.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
; Main executable
Source: "{#BuildDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; DLLs
Source: "{#BuildDir}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\pdfium.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\printing_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\sqlite3.dll"; DestDir: "{app}"; Flags: ignoreversion

; Data folder (app.so, icudtl.dat, flutter_assets)
Source: "{#BuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Clean up database files on uninstall (optional — user data)
Type: filesandordirs; Name: "{userappdata}\electrical_store"
Type: files; Name: "{app}\*.db"
Type: files; Name: "{app}\*.db-wal"
Type: files; Name: "{app}\*.db-shm"

[Code]
// Check if Visual C++ Redistributable is needed
function NeedsVCRedist(): Boolean;
begin
  Result := not FileExists(ExpandConstant('{sys}\vcruntime140.dll'));
end;
