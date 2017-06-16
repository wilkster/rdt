; Script generated by the Inno Setup Script Wizard.
; SEE THE DOCUMENTATION FOR DETAILS ON CREATING INNO SETUP SCRIPT FILES!
; http://www.rkeene.org/devel/kitcreator/kitbuild/nightly/tclkit-cvs_HEAD-win32-i586-xcompile is 8.6 version used
; need to change the icon using the resource tool of IcoFX
;
[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppVersion=0.9.6
OutputBaseFilename=rdtSetup.0.9.7

AppId={{B958811B-3898-470D-A7F4-FB9EFE0DB5E3}}
AppName=Recent Document Tracker (RDT)
SourceDir=C:\Google Drive\Code\rdt
AppPublisher=Tom Wilkason
AppPublisherURL=http://code.google.com/p/recdoctracker/
AppSupportURL=http://code.google.com/p/recdoctracker/
AppUpdatesURL=http://code.google.com/p/recdoctracker/
DefaultDirName={pf}\Recent Document Tracker (RDT)
DefaultGroupName=Recent Document Tracker (RDT)
AllowNoIcons=yes
LicenseFile=Licence.txt
InfoAfterFile=Readme.txt
OutputDir=Output
SetupIconFile=icons\rdt.ico
UninstallIconFile=icons\rdt.ico
Compression=lzma
SolidCompression=yes
UsePreviousAppDir=yes
DirExistsWarning=auto

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
CreateStartupIcon=Start RDT at each Login

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 0,6.1
Name: "startupicon"; Description: "{cm:CreateStartupIcon}"; GroupDescription: "{cm:AdditionalIcons}";

[Files]
Source: "rdt.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "twapi_base.dll"; DestDir: "{app}"; Flags: ignoreversion
;Source: "winico.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "shellicon0.1.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "thread270.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "Readme.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "Licence.txt"; DestDir: "{app}"; Flags: ignoreversion
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{group}\Recent Document Tracker (RDT)"; Filename: "{app}\rdt.exe"
Name: "{group}\{cm:UninstallProgram,Recent Document Tracker (RDT)}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\Recent Document Tracker (RDT)"; Filename: "{app}\rdt.exe"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\Recent Document Tracker (RDT)"; Filename: "{app}\rdt.exe"; Tasks: quicklaunchicon
Name: "{userstartup}\RDT"; Filename: "{app}\rdt.exe"; Tasks: startupicon


[Run]
Filename: "{app}\rdt.exe"; Description: "{cm:LaunchProgram,Recent Document Tracker (RDT)}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
;Type: filesandordirs; Name  (can't get to {user}\.rdt folder, no constant for some reason
; {userappdata} -> app data folder
Type: filesandordirs; Name: "{%USERPROFILE|xxxxxxx}\.rdt";