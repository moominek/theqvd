; Script generated by the Inno Setup Script Wizard.
; SEE THE DOCUMENTATION FOR DETAILS ON CREATING INNO SETUP SCRIPT FILES!

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={{DD625C30-A6B1-4C48-A3C2-19B39771028F}
AppName=QVD Client
AppVerName=QVD Client
AppPublisher=QindelGroup
AppPublisherURL=http://qvd.qindel.com/
AppSupportURL=http://qvd.qindel.com/
AppUpdatesURL=http://qvd.qindel.com/
DefaultDirName={pf}\QVD
DefaultGroupName=QVD Client
DisableProgramGroupPage=yes
OutputBaseFilename=setup
Compression=lzma
SolidCompression=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\ext\qvd-client.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "installer\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{group}\QVD Client"; Filename: "{app}\qvd-client.exe"
Name: "{commondesktop}\QVD Client"; Filename: "{app}\qvd-client.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\qvd-client.exe"; Description: "{cm:LaunchProgram,QVD}"; Flags: nowait postinstall skipifsilent

