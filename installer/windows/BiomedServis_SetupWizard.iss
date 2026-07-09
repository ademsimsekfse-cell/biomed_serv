#ifndef MyAppName
#define MyAppName "Biomed Servis"
#endif

#ifndef MyAppPublisher
#define MyAppPublisher "Fejox"
#endif

#ifndef MyAppVersion
#define MyAppVersion "1.0.0"
#endif

#ifndef MyAppExeName
#define MyAppExeName "biomed_serv.exe"
#endif

#ifndef MyAppAssocName
#define MyAppAssocName "Biomed Servis Desktop Merkez"
#endif

#ifndef MyAppOutputBase
#define MyAppOutputBase "BiomedServis_Setup"
#endif

[Setup]
AppId={{E53D6AF3-2D2A-4DB3-A43B-40B1B8F8B4D7}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Biomed Servis
DefaultGroupName={#MyAppName}
UsePreviousAppDir=yes
UsePreviousLanguage=yes
UsePreviousTasks=yes
DisableProgramGroupPage=yes
AllowNoIcons=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
Compression=lzma2/ultra64
SolidCompression=yes
PrivilegesRequired=admin
ChangesAssociations=no
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
AppMutex=biomed_serv_single_instance
CloseApplications=yes
CloseApplicationsFilter=biomed_serv.exe
RestartApplications=no
DirExistsWarning=yes
SetupLogging=yes
OutputDir=Output
OutputBaseFilename={#MyAppOutputBase}
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppAssocName}
VersionInfoProductName={#MyAppName}
InfoAfterFile=SETUP_NOTES.txt

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[Tasks]
Name: "desktopicon"; Description: "Masaustune kisayol olustur"; GroupDescription: "Ek secenekler:"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "SETUP_NOTES.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Biomed Servis Yerel API"""; Flags: runhidden waituntilterminated; StatusMsg: "Eski yerel ağ izni temizleniyor..."
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Biomed Servis Yerel API TCP"""; Flags: runhidden waituntilterminated; StatusMsg: "Eski TCP izni temizleniyor..."
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Biomed Servis Otomatik Kesif UDP"""; Flags: runhidden waituntilterminated; StatusMsg: "Eski keşif izni temizleniyor..."
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""Biomed Servis Yerel API TCP"" dir=in action=allow protocol=TCP localport=8787 remoteip=localsubnet profile=any program=""{app}\{#MyAppExeName}"" enable=yes"; Flags: runhidden waituntilterminated; StatusMsg: "Yerel API izni ekleniyor..."
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""Biomed Servis Otomatik Kesif UDP"" dir=in action=allow protocol=UDP localport=8788 remoteip=localsubnet profile=any program=""{app}\{#MyAppExeName}"" enable=yes"; Flags: runhidden waituntilterminated; StatusMsg: "Otomatik merkez keşif izni ekleniyor..."
Filename: "{app}\{#MyAppExeName}"; Description: "{#MyAppName} uygulamasini baslat"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Biomed Servis Yerel API"""; Flags: runhidden waituntilterminated; RunOnceId: "RemoveBiomedServisFirewallRule"
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Biomed Servis Yerel API TCP"""; Flags: runhidden waituntilterminated; RunOnceId: "RemoveBiomedServisTcpFirewallRule"
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Biomed Servis Otomatik Kesif UDP"""; Flags: runhidden waituntilterminated; RunOnceId: "RemoveBiomedServisUdpFirewallRule"
