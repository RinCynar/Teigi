; Teigi Inno Setup installer script (English only).
; Invoked by tools\build_dist.ps1; normalized to UTF-8 BOM before compile.
#define MyAppName "Teigi"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "RinCynar"
#define MyAppURL "https://teigi.rincynar.top"
#define MyAppExeName "teigi.exe"
; Paths relative to this file (tools/).
#define ReleaseDir "..\build\outputdir\release"
#define FfmpegSrc "..\build\outputdir\ffmpeg-src"
; Version numbers injected by build_dist.ps1 via /D; fallbacks below.
#ifndef MyPathVersion
  #define MyPathVersion "PATH"
#endif
#ifndef BundledVersion
  #define BundledVersion "bundled"
#endif
#ifndef LatestVersion
  #define LatestVersion "latest"
#endif

[Setup]
AppId={{8F7C0D2E-4A1B-4C5D-9E3F-7A2B6C8D0E1F}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
; Keep the "Select Destination Location" page visible for custom install directory.
DisableDirPage=no
; Allow user to change install directory (defaults to Program Files\Teigi).
DisableProgramGroupPage=yes
; English only: skip language selection dialog.
ShowLanguageDialog=no
OutputDir=..\build\outputdir
OutputBaseFilename=TeigiSetup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
; The installer downloads and extracts a .zip (gyan.dev ffmpeg) at install time,
; so the extraction engine must support .zip. "auto" would select "basic" (7z only).
ArchiveExtraction=full

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#ReleaseDir}\Teigi\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
#ifexist "..\build\outputdir\ffmpeg-src\ffmpeg.exe"
Source: "{#FfmpegSrc}\*"; DestDir: "{app}\data\ffmpeg"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: ShouldEmbedBundled
#endif

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

; The ffmpeg engine deployed into {app}\data\ffmpeg may have been created by the
; "download latest" PowerShell step (not tracked in the uninstall log), so remove
; the whole directory unconditionally during uninstall.
[UninstallDelete]
Type: filesandordirs; Name: "{app}\data\ffmpeg"

[Code]
var
  FFmpegPage: TWizardPage;
  rbNoEmbed: TNewRadioButton;
  rbEmbedBundled: TNewRadioButton;
  rbDownloadLatest: TNewRadioButton;
  // Progress UIs for the "download latest ffmpeg" option.
  DownloadPage: TDownloadWizardPage;
  ExtractPage: TExtractionWizardPage;

procedure InitializeWizard;
var
  lbl: TNewStaticText;
  L, CursorY, RadioW, RadioH, Gap: Integer;
begin
  // ffmpeg configuration page is inserted after directory selection and before task selection,
  // so they see the install location before choosing how to handle ffmpeg.
  FFmpegPage := CreateCustomPage(wpSelectDir,
    'ffmpeg Engine',
    'Choose how to handle ffmpeg');

  L := ScaleX(16);
  RadioW := FFmpegPage.SurfaceWidth - ScaleX(32);
  RadioH := ScaleY(52);
  Gap := ScaleY(6);

  lbl := TNewStaticText.Create(FFmpegPage);
  lbl.Parent := FFmpegPage.Surface;
  lbl.Left := L;
  lbl.Top := ScaleY(12);
  lbl.Width := RadioW;
  lbl.AutoSize := False;
  lbl.Height := ScaleY(20);
  lbl.WordWrap := True;
  lbl.Caption := 'Please choose how to install ffmpeg:';

  CursorY := lbl.Top + lbl.Height + ScaleY(10);

  rbNoEmbed := TNewRadioButton.Create(FFmpegPage);
  rbNoEmbed.Parent := FFmpegPage.Surface;
  rbNoEmbed.SetBounds(L + ScaleX(8), CursorY, RadioW - ScaleX(8), RadioH);
  rbNoEmbed.Caption := 'Do not embed ffmpeg (use the one in system PATH)' + #13#10 +
                        'Detected version: {#MyPathVersion}';
  rbNoEmbed.Checked := True;

  CursorY := CursorY + RadioH + Gap;

  rbEmbedBundled := TNewRadioButton.Create(FFmpegPage);
  rbEmbedBundled.Parent := FFmpegPage.Surface;
  rbEmbedBundled.SetBounds(L + ScaleX(8), CursorY, RadioW - ScaleX(8), RadioH);
  rbEmbedBundled.Caption := 'Embed the bundled ffmpeg' + #13#10 +
                            'Detected version: {#BundledVersion}';

  CursorY := CursorY + RadioH + Gap;

  rbDownloadLatest := TNewRadioButton.Create(FFmpegPage);
  rbDownloadLatest.Parent := FFmpegPage.Surface;
  rbDownloadLatest.SetBounds(L + ScaleX(8), CursorY, RadioW - ScaleX(8), RadioH);
  rbDownloadLatest.Caption := 'Download the latest ffmpeg from gyan.dev (during install, requires network)';

  // Progress UIs for the "download latest" flow. Created once here.
  DownloadPage := CreateDownloadPage('Downloading ffmpeg',
    'Please wait while Setup downloads the latest ffmpeg build from gyan.dev.', nil);
  ExtractPage := CreateExtractionPage('Extracting ffmpeg',
    'Please wait while Setup extracts the ffmpeg engine.', nil);
end;

function ShouldEmbedBundled: Boolean;
begin
  Result := rbEmbedBundled.Checked;
end;

// Download ffmpeg (with a visible progress dialog) right before installation starts,
// instead of blocking inside ssPostInstall with no UI feedback.
function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if (CurPageID = wpReady) and rbDownloadLatest.Checked then
  begin
    if not FileExists(ExpandConstant('{tmp}\ffmpeg-latest.zip')) then
    begin
      DownloadPage.Show;
      try
        DownloadPage.Add('https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip',
                         'ffmpeg-latest.zip', '');
        try
          DownloadPage.Download;
        except
          Result := False; // abort installation
          if not DownloadPage.AbortedByUser then
            MsgBox('Failed to download the latest ffmpeg. Please check your network connection and try again, or choose another ffmpeg option.', mbError, MB_OK);
        end;
      finally
        DownloadPage.Hide;
      end;
    end;
  end;
end;

function ExtractFfmpeg: Boolean;
var
  ZipPath, ExtractDir, AppFfmpeg, Script, Tmp: String;
  ResultCode: Integer;
begin
  Result := False;
  ZipPath := ExpandConstant('{tmp}\ffmpeg-latest.zip');
  ExtractDir := ExpandConstant('{tmp}\ffmpeg-extract');
  AppFfmpeg := ExpandConstant('{app}\data\ffmpeg');
  if not FileExists(ZipPath) then Exit;
  // 1) Extract the archive with a visible progress page (keep inner paths).
  try
    ExtractPage.Show;
    try
      ExtractPage.Add(ZipPath, ExtractDir, True);
      ExtractPage.Extract;
    finally
      ExtractPage.Hide;
    end;
  except
    Exit;
  end;
  // 2) Deploy ffmpeg.exe + DLLs from the extracted folder into {app}\data\ffmpeg.
  Tmp := ExpandConstant('{tmp}\deploy_ffmpeg.ps1');
  Script :=
    '$src=Get-ChildItem -Path $args[0] -Recurse -Filter ffmpeg.exe | Select-Object -First 1;' + #13#10 +
    'if (-not $src) { exit 1 };' + #13#10 +
    'New-Item -ItemType Directory -Force -Path $args[1] | Out-Null;' + #13#10 +
    'Copy-Item $src.FullName $args[1] -Force;' + #13#10 +
    'Get-ChildItem (Split-Path $src.FullName) -Filter *.dll | Copy-Item -Destination $args[1] -Force;' + #13#10 +
    'exit 0';
  SaveStringToFile(Tmp, Script, False);
  if Exec('powershell.exe',
      '-NoProfile -ExecutionPolicy Bypass -File "' + Tmp + '" "' + ExtractDir + '" "' + AppFfmpeg + '"',
      '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    Result := (ResultCode = 0);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep = ssPostInstall) and rbDownloadLatest.Checked then
  begin
    if not ExtractFfmpeg then
      MsgBox('Failed to deploy the downloaded ffmpeg. Please configure it manually after install.', mbError, MB_OK);
  end;
end;