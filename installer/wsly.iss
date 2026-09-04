; Per-user Inno Setup installer for wsly. Build with scripts/package-release.ps1.

#ifndef AppVersion
  #error AppVersion must be passed to ISCC.
#endif

#ifndef SourceDir
  #error SourceDir must be passed to ISCC.
#endif

#ifndef OutputDir
  #error OutputDir must be passed to ISCC.
#endif

[Setup]
AppId={{D407691B-3AC9-40C7-BD7E-5FD321318A4B}
AppName=wsly
AppVersion={#AppVersion}
AppPublisher=Mihai Valentin
AppPublisherURL=https://github.com/mihai-valentin/wsly
AppSupportURL=https://github.com/mihai-valentin/wsly/issues
DefaultDirName={localappdata}\wsly\bin
DefaultGroupName=wsly
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir={#OutputDir}
OutputBaseFilename=wsly-{#AppVersion}-setup
Compression=lzma2
SolidCompression=yes
UninstallDisplayName=wsly

[Files]
Source: "{#SourceDir}\VERSION"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\wsly.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\wsly.bash"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\wsly-completion.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Code]
const
  ProfileMarker = 'wsly tab completion';

function ProfileLine: String;
begin
  Result := '. ''' + ExpandConstant('{app}\wsly-completion.ps1') + ''' # ' + ProfileMarker;
end;

procedure AddProfileEntry(const ProfilePath: String);
var
  Lines: TStringList;
begin
  ForceDirectories(ExtractFileDir(ProfilePath));
  Lines := TStringList.Create;
  try
    if FileExists(ProfilePath) then
      Lines.LoadFromFile(ProfilePath);
    if Lines.IndexOf(ProfileLine) = -1 then begin
      Lines.Add(ProfileLine);
      Lines.SaveToFile(ProfilePath);
    end;
  finally
    Lines.Free;
  end;
end;

procedure RemoveProfileEntry(const ProfilePath: String);
var
  Lines: TStringList;
  Index: Integer;
begin
  if not FileExists(ProfilePath) then
    exit;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(ProfilePath);
    for Index := Lines.Count - 1 downto 0 do
      if Pos(ProfileMarker, Lines[Index]) > 0 then
        Lines.Delete(Index);
    Lines.SaveToFile(ProfilePath);
  finally
    Lines.Free;
  end;
end;

function UserPath: String;
begin
  if not RegQueryStringValue(HKCU, 'Environment', 'Path', Result) then
    Result := '';
end;

procedure WriteUserPath(const Value: String);
begin
  RegWriteExpandStringValue(HKCU, 'Environment', 'Path', Value);
end;

procedure AddToUserPath(const Entry: String);
var
  Entries: TStringList;
  Index: Integer;
  Found: Boolean;
begin
  Entries := TStringList.Create;
  try
    Entries.StrictDelimiter := True;
    Entries.Delimiter := ';';
    Entries.DelimitedText := UserPath;
    Found := False;
    for Index := 0 to Entries.Count - 1 do
      if CompareText(Entries[Index], Entry) = 0 then
        Found := True;
    if not Found then begin
      Entries.Add(Entry);
      WriteUserPath(Entries.DelimitedText);
    end;
  finally
    Entries.Free;
  end;
end;

procedure RemoveFromUserPath(const Entry: String);
var
  Entries: TStringList;
  Index: Integer;
begin
  Entries := TStringList.Create;
  try
    Entries.StrictDelimiter := True;
    Entries.Delimiter := ';';
    Entries.DelimitedText := UserPath;
    for Index := Entries.Count - 1 downto 0 do
      if CompareText(Entries[Index], Entry) = 0 then
        Entries.Delete(Index);
    WriteUserPath(Entries.DelimitedText);
  finally
    Entries.Free;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Documents: String;
begin
  if CurStep = ssPostInstall then begin
    AddToUserPath(ExpandConstant('{app}'));
    Documents := ExpandConstant('{userdocs}');
    AddProfileEntry(AddBackslash(Documents) + 'WindowsPowerShell\profile.ps1');
    AddProfileEntry(AddBackslash(Documents) + 'PowerShell\profile.ps1');
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Documents: String;
begin
  if CurUninstallStep = usPostUninstall then begin
    RemoveFromUserPath(ExpandConstant('{app}'));
    Documents := ExpandConstant('{userdocs}');
    RemoveProfileEntry(AddBackslash(Documents) + 'WindowsPowerShell\profile.ps1');
    RemoveProfileEntry(AddBackslash(Documents) + 'PowerShell\profile.ps1');
  end;
end;
