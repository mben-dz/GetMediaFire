unit API.MediaFire.Resolver;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.IOUtils,
//
  API.MediaFire.Types,
  API.MediaFire.Client,
  API.Console.Reporter,
  API.Naming;

type
  IJobResolver = interface
    ['{12345678-ABCD-EF01-2345-67890ABCDEF0}']
    function ResolveUrls(const aUrls: TArray<string>; const aBaseOutputDir: string): TArray<AFileEntry>;
  end;

  TJobResolver = class(TInterfacedObject, IJobResolver)
  private
    FClient: IMediaFireClient;
    FReporter: IConsoleReporter;
    procedure ResolveFolder(const aKey, aCurrentPath: string; aJobs: TList<AFileEntry>);
  public
    constructor Create(const aClient: IMediaFireClient; const aReporter: IConsoleReporter);
    function ResolveUrls(const aUrls: TArray<string>; const aBaseOutputDir: string): TArray<AFileEntry>;
  end;

implementation

constructor TJobResolver.Create(const aClient: IMediaFireClient; const aReporter: IConsoleReporter);
begin
  FClient := aClient;
  FReporter := aReporter;
end;

procedure TJobResolver.ResolveFolder(const aKey, aCurrentPath: string; aJobs: TList<AFileEntry>);
var
  LChunk: Integer;
  LMoreChunks: Boolean;
  LFiles: TArray<AFileEntry>;
  LFolders: TArray<TPair<string, string>>;
  LFile: AFileEntry;
  LFolder: TPair<string, string>;
  LSubPath: string;
  LNewFile: AFileEntry;
begin
  LChunk := 1;
  repeat
    if FClient.GetFolderContentFiles(aKey, LChunk, LFiles, LMoreChunks) then
    begin
      for LFile in LFiles do
      begin
        FReporter.SpinFetching(LFile.FileName);
        LNewFile := LFile;
        LNewFile.FileName := NormalizeFileOrFolderName(LFile.FileName);
        LNewFile.DestinationPath := TPath.Combine(aCurrentPath, LNewFile.FileName);
        aJobs.Add(LNewFile);
      end;
    end
    else Break;
    Inc(LChunk);
  until not LMoreChunks;

  LChunk := 1;
  repeat
    if FClient.GetFolderContentFolders(aKey, LChunk, LFolders, LMoreChunks) then
    begin
      for LFolder in LFolders do
      begin
        FReporter.SpinFetching(LFolder.Value);
        LSubPath := TPath.Combine(aCurrentPath, NormalizeFileOrFolderName(LFolder.Value));
        if not TDirectory.Exists(LSubPath) then
          TDirectory.CreateDirectory(LSubPath);
        ResolveFolder(LFolder.Key, LSubPath, aJobs);
      end;
    end
    else Break;
    Inc(LChunk);
  until not LMoreChunks;
end;

function TJobResolver.ResolveUrls(const aUrls: TArray<string>; const aBaseOutputDir: string): TArray<AFileEntry>;
var
  LJobs: TList<AFileEntry>;
  LUrl, LType, LKey, LFolderName: string;
  LFileEntry: AFileEntry;
  LTargetDir: string;
begin
  LJobs := TList<AFileEntry>.Create;
  try
    for LUrl in aUrls do
    begin
      if FClient.ParseUrl(LUrl, LType, LKey) then
      begin
        if (LType = 'file') or (LType = 'file_premium') then
        begin
          if FClient.GetFileInfo(LKey, LFileEntry) then
          begin
            FReporter.SpinFetching(LFileEntry.FileName);
            LFileEntry.FileName := NormalizeFileOrFolderName(LFileEntry.FileName);
            LFileEntry.DestinationPath := TPath.Combine(aBaseOutputDir, LFileEntry.FileName);
            LJobs.Add(LFileEntry);
          end;
        end
        else if (LType = 'folder') then
        begin
          if FClient.GetFolderInfo(LKey, LFolderName) then
          begin
            LTargetDir := TPath.Combine(aBaseOutputDir, NormalizeFileOrFolderName(LFolderName));
            if not TDirectory.Exists(LTargetDir) then
              TDirectory.CreateDirectory(LTargetDir);
            ResolveFolder(LKey, LTargetDir, LJobs);
          end;
        end;
      end;
    end;
    Result := LJobs.ToArray;
    FReporter.ClearSpinner;
  finally
    LJobs.Free;
  end;
end;

end.
