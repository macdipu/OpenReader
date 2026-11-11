; Inno Setup script for the OpenReader Windows installer.
; Built by .github/workflows/release.yml:
;   iscc /DAppVersion=1.0.11 /DSourceDir=<Release folder> /DOutputDir=release windows\installer\openreader.iss
; Per-user install (no admin rights); registers OpenReader in "Open with" via register-file-types.ps1.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\release"
#endif

[Setup]
AppId={{6D3B7A52-4C1E-4F0B-9A55-0E7B1D2C9F41}
AppName=OpenReader
AppVersion={#AppVersion}
AppPublisher=OpenReader
DefaultDirName={autopf}\OpenReader
DefaultGroupName=OpenReader
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=OpenReader-{#AppVersion}-windows-x64-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\openreader.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked
Name: "openwith"; Description: "Add OpenReader to the ""Open with"" menu for PDF, DOCX, XLSX, PPTX, TXT, MD and CSV files"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\register-file-types.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\OpenReader"; Filename: "{app}\openreader.exe"
Name: "{autodesktop}\OpenReader"; Filename: "{app}\openreader.exe"; Tasks: desktopicon

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\register-file-types.ps1"""; Flags: runhidden; Tasks: openwith
Filename: "{app}\openreader.exe"; Description: "Launch OpenReader"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\register-file-types.ps1"" -Unregister"; Flags: runhidden; RunOnceId: "UnregisterFileTypes"
