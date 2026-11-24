; Galax-z for Windows as one setup program: Inno Setup 6 (https://jrsoftware.org/isinfo.php), made by build.ps1 -Installer.
;
; It installs for the person running it, with no administrator: %LOCALAPPDATA%\Programs\Galax-z, a Start menu entry, and an
; uninstaller in Settings › Apps. What Galax-z keeps is never touched by either: %LOCALAPPDATA%\Galax-z (settings, TE's OS read off
; your OP-Z) and Documents\Galax-z (backups). build.ps1 passes Version, Source (the packaged folder), Out, Name and Arch.

#ifndef Version
  #define Version "1.0"
#endif
#ifndef Arch
  #define Arch "x64"
#endif

[Setup]
; the same id for every version: a newer setup updates the one installed
AppId={{6A1C2E7F-3B5D-4C8A-9E21-7D0F4B6A9C35}
AppName=Galax-z
AppVersion={#Version}
AppVerName=Galax-z {#Version}
AppPublisher=Galax-z
AppPublisherURL=https://github.com/Luisga521/Galax-z
AppSupportURL=https://github.com/Luisga521/Galax-z/issues
VersionInfoVersion={#Version}
VersionInfoDescription=Galax-z for Windows setup
DefaultDirName={autopf}\Galax-z
DefaultGroupName=Galax-z
DisableProgramGroupPage=yes
; per person, no administrator ({autopf} is then %LOCALAPPDATA%\Programs); the dialog lets someone choose all users instead
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
#if Arch == "arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif
MinVersion=10.0
SourceDir={#Source}
OutputDir={#Out}
OutputBaseFilename={#Name}
SetupIconFile=Galax-z.ico
UninstallDisplayIcon={app}\Galax-z.exe
UninstallDisplayName=Galax-z
LicenseFile=LICENSE
InfoBeforeFile=DISCLAIMER.md
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Galax-z running: asked to close first (it refuses while it writes to an OP-Z), started again afterwards
AppMutex=Galax-z.App
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; the program, Swift's runtime beside it, the resource bundles, the notices
Source: "*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Galax-z"; Filename: "{app}\Galax-z.exe"; IconFilename: "{app}\Galax-z.ico"
Name: "{group}\Galax-z (demo OP-Z)"; Filename: "{app}\Galax-z.exe"; Parameters: "--demo"; IconFilename: "{app}\Galax-z.ico"
Name: "{group}\Uninstall Galax-z"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Galax-z"; Filename: "{app}\Galax-z.exe"; IconFilename: "{app}\Galax-z.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\Galax-z.exe"; Description: "{cm:LaunchProgram,Galax-z}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; only what the setup put there; your settings, TE's OS and your backups stay
Type: dirifempty; Name: "{app}"
