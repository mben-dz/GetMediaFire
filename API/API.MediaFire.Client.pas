unit API.MediaFire.Client;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.NetConsts,
  System.JSON,
  System.RegularExpressions,
  System.Generics.Collections,
  System.IOUtils,
//
  API.MediaFire.Types,
  API.Proxy.Provider,
  API.Hashing;

type
  iOnDownloadEvent = interface ['{6A496103-A96A-4D4D-A9E3-243D33B05F5D}']
    function ReceiveData(aProc: TReceiveDataCallback): TReceiveDataEvent;
    procedure iFree;
  end;

  TOndownloadEvent = class(TInterfacedObject, iOnDownloadEvent)
  strict private
    FCallback: TReceiveDataCallback;
    procedure HandleOnReceiveDataEvent(const Sender: TObject;
      AContentLength, AReadCount: Int64; var AAbort: Boolean);
    procedure iFree;
  public
    constructor Create();
    class function New: iOnDownloadEvent;

    function ReceiveData(aProc: TReceiveDataCallback): TReceiveDataEvent;
  end;

  IMediaFireClient = interface
    ['{F4E5D6C7-B8A9-498A-8B7C-6D5E4F3A2B1C}']
    function ParseUrl(const aUrl: string; out aType, aKey: string): Boolean;
    function GetFolderInfo(const aKey: string; out aFolderName: string): Boolean;
    function GetFolderContentFiles(const aKey: string; aChunk: Integer; out aFiles: TArray<AFileEntry>; out aMoreChunks: Boolean): Boolean;
    function GetFolderContentFolders(const aKey: string; aChunk: Integer; out aFolders: TArray<TPair<string, string>>; out aMoreChunks: Boolean): Boolean;
    function GetFileInfo(const aKey: string; out aFileEntry: AFileEntry): Boolean;
    function ResolveDirectLink(const aScrambledUrl: string; out aDirectUrl: string): Boolean;
    function DownloadFile(const aDirectUrl, aDestPath: string; aUseProxy: Boolean;
      aProgressProc: TProc<Int64, Int64>): TDownloadError;
  end;

  TMediaFireClient = class(TInterfacedObject, IMediaFireClient)
  private
    FProxyProvider: IProxyProvider;
//    fOnDownloading: TReceiveDataEvent;
    function CreateClient(aUseProxy: Boolean): THTTPClient;
    function ExtractRegexGroup(const aText, aPattern: string; aGroup: Integer): string;
    function Base64DecodeStr(const aBase64: string): string;
  public
    constructor Create(const aProxyProvider: IProxyProvider);
    function ParseUrl(const aUrl: string; out aType, aKey: string): Boolean;
    function GetFolderInfo(const aKey: string; out aFolderName: string): Boolean;
    function GetFolderContentFiles(const aKey: string; aChunk: Integer; out aFiles: TArray<AFileEntry>; out aMoreChunks: Boolean): Boolean;
    function GetFolderContentFolders(const aKey: string; aChunk: Integer; out aFolders: TArray<TPair<string, string>>; out aMoreChunks: Boolean): Boolean;
    function GetFileInfo(const aKey: string; out aFileEntry: AFileEntry): Boolean;
    function ResolveDirectLink(const aScrambledUrl: string; out aDirectUrl: string): Boolean;
    function DownloadFile(const aDirectUrl, aDestPath: string; aUseProxy: Boolean;
      aProgressProc: TProc<Int64, Int64>): TDownloadError;
  end;

implementation

uses
  System.NetEncoding;

const
  cUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:131.0) Gecko/20100101 Firefox/131.0';

{ TOndownloadEvent }

constructor TOndownloadEvent.Create;
begin
  inherited Create;
  FCallback := nil;
end;

class function TOndownloadEvent.New: iOnDownloadEvent;
begin
  Result := Self.Create;
end;

procedure TOndownloadEvent.HandleOnReceiveDataEvent(const Sender: TObject;
  AContentLength, AReadCount: Int64; var AAbort: Boolean);
begin
  if Assigned(FCallback) then
    FCallback(Sender, AContentLength, AReadCount, AAbort);
end;

procedure TOndownloadEvent.iFree;
begin
  Free;
end;

function TOndownloadEvent.ReceiveData(
  aProc: TReceiveDataCallback): TReceiveDataEvent;
begin
  FCallback := aProc;
  Result := HandleOnReceiveDataEvent;
end;

{ TMediaFireClient }

constructor TMediaFireClient.Create(const aProxyProvider: IProxyProvider);
begin
  FProxyProvider := aProxyProvider;
end;

function TMediaFireClient.CreateClient(aUseProxy: Boolean): THTTPClient;
var
  LProxyUrl: string;
  LUri: TURI;
begin
  Result := THTTPClient.Create;
  Result.UserAgent := cUserAgent;
  Result.AcceptEncoding := 'identity';
  Result.AllowCookies := True;

  if aUseProxy and Assigned(FProxyProvider) and FProxyProvider.HasProxies then
  begin
    if FProxyProvider.GetNextProxy(LProxyUrl) then
    begin
      if not LProxyUrl.StartsWith('http') then
        LProxyUrl := 'http://' + LProxyUrl;
      LUri := TURI.Create(LProxyUrl);
      Result.ProxySettings := TProxySettings.Create(LUri.Host, LUri.Port, LUri.Scheme, LUri.Username, LUri.Password);
    end;
  end;
end;

function TMediaFireClient.ParseUrl(const aUrl: string; out aType, aKey: string): Boolean;
var
  LMatch: TMatch;
begin
  Result := False;
  LMatch := TRegEx.Match(aUrl, 'mediafire\.com/(folder|file|file_premium)/([a-zA-Z0-9]+)');
  if LMatch.Success then
  begin
    aType := LMatch.Groups[1].Value;
    aKey := LMatch.Groups[2].Value;
    Result := True;
  end;
end;

function TMediaFireClient.GetFolderInfo(const aKey: string; out aFolderName: string): Boolean;
var
  LClient: THTTPClient;
  LResp: IHTTPResponse;
  LJson, LRespObj, LFolderInfo: TJSONObject;
begin
  Result := False;
  LClient := CreateClient(True);
  try
    try
      LResp := LClient.Get('https://www.mediafire.com/api/1.4/folder/get_info.php?r=utga&content_type=folder&filter=all&order_by=name&order_direction=asc&chunk=1&version=1.5&folder_key=' + aKey + '&response_format=json');
      if LResp.StatusCode = 200 then
      begin
        LJson := TJSONObject.ParseJSONValue(LResp.ContentAsString) as TJSONObject;
        if Assigned(LJson) then
        try
          LRespObj := LJson.GetValue('response') as TJSONObject;
          if Assigned(LRespObj) then
          begin
            LFolderInfo := LRespObj.GetValue('folder_info') as TJSONObject;
            if Assigned(LFolderInfo) then
            begin
              aFolderName := LFolderInfo.GetValue('name').Value;
              Result := True;
            end;
          end;
        finally
          LJson.Free;
        end;
      end;
    except
    end;
  finally
    LClient.Free;
  end;
end;

function TMediaFireClient.GetFolderContentFiles(const aKey: string; aChunk: Integer; out aFiles: TArray<AFileEntry>; out aMoreChunks: Boolean): Boolean;
var
  LClient: THTTPClient;
  LResp: IHTTPResponse;
  LJson, LRespObj, LContent: TJSONObject;
  LFilesArr: TJSONArray;
  i: Integer;
  LEntry: AFileEntry;
  LFileObj, LLinks: TJSONObject;
begin
  Result := False;
  aMoreChunks := False;
  SetLength(aFiles, 0);
  LClient := CreateClient(True);
  try
    try
      LResp := LClient.Get('https://www.mediafire.com/api/1.4/folder/get_content.php?r=utga&content_type=files&filter=all&order_by=name&order_direction=asc&chunk=' + IntToStr(aChunk) + '&version=1.5&folder_key=' + aKey + '&response_format=json');
      if LResp.StatusCode = 200 then
      begin
        LJson := TJSONObject.ParseJSONValue(LResp.ContentAsString) as TJSONObject;
        if Assigned(LJson) then
        try
          LRespObj := LJson.GetValue('response') as TJSONObject;
          if Assigned(LRespObj) then
          begin
            LContent := LRespObj.GetValue('folder_content') as TJSONObject;
            if Assigned(LContent) then
            begin
              aMoreChunks := (LContent.GetValue('more_chunks').Value = 'yes');
              LFilesArr := LContent.GetValue('files') as TJSONArray;
              if Assigned(LFilesArr) then
              begin
                SetLength(aFiles, LFilesArr.Count);
                for i := 0 to LFilesArr.Count - 1 do
                begin
                  LFileObj := LFilesArr.Items[i] as TJSONObject;
                  LEntry.FileName := LFileObj.GetValue('filename').Value;
                  LEntry.ExpectedHash := LFileObj.GetValue('hash').Value;
                  LEntry.Size := StrToInt64Def(LFileObj.GetValue('size').Value, 0);
                  LLinks := LFileObj.GetValue('links') as TJSONObject;
                  if Assigned(LLinks) and Assigned(LLinks.GetValue('normal_download')) then
                    LEntry.ScrambledLink := LLinks.GetValue('normal_download').Value;
                  aFiles[i] := LEntry;
                end;
                Result := True;
              end;
            end;
          end;
        finally
          LJson.Free;
        end;
      end;
    except
    end;
  finally
    LClient.Free;
  end;
end;

function TMediaFireClient.GetFolderContentFolders(const aKey: string; aChunk: Integer; out aFolders: TArray<TPair<string, string>>; out aMoreChunks: Boolean): Boolean;
var
  LClient: THTTPClient;
  LResp: IHTTPResponse;
  LJson, LRespObj, LContent: TJSONObject;
  LArr: TJSONArray;
  i: Integer;
  LObj: TJSONObject;
begin
  Result := False;
  aMoreChunks := False;
  SetLength(aFolders, 0);
  LClient := CreateClient(True);
  try
    try
      LResp := LClient.Get('https://www.mediafire.com/api/1.4/folder/get_content.php?r=utga&content_type=folders&filter=all&order_by=name&order_direction=asc&chunk=' + IntToStr(aChunk) + '&version=1.5&folder_key=' + aKey + '&response_format=json');
      if LResp.StatusCode = 200 then
      begin
        LJson := TJSONObject.ParseJSONValue(LResp.ContentAsString) as TJSONObject;
        if Assigned(LJson) then
        try
          LRespObj := LJson.GetValue('response') as TJSONObject;
          if Assigned(LRespObj) then
          begin
            LContent := LRespObj.GetValue('folder_content') as TJSONObject;
            if Assigned(LContent) then
            begin
              aMoreChunks := (LContent.GetValue('more_chunks').Value = 'yes');
              LArr := LContent.GetValue('folders') as TJSONArray;
              if Assigned(LArr) then
              begin
                SetLength(aFolders, LArr.Count);
                for i := 0 to LArr.Count - 1 do
                begin
                  LObj := LArr.Items[i] as TJSONObject;
                  aFolders[i] := TPair<string,string>.Create(LObj.GetValue('folderkey').Value, LObj.GetValue('name').Value);
                end;
                Result := True;
              end;
            end;
          end;
        finally
          LJson.Free;
        end;
      end;
    except
    end;
  finally
    LClient.Free;
  end;
end;

function TMediaFireClient.GetFileInfo(const aKey: string; out aFileEntry: AFileEntry): Boolean;
var
  LClient: THTTPClient;
  LResp: IHTTPResponse;
  LJson, LRespObj, LFileObj, LLinks: TJSONObject;
begin
  Result := False;
  LClient := CreateClient(True);
  try
    try
      LResp := LClient.Get('https://www.mediafire.com/api/file/get_info.php?quick_key=' + aKey + '&response_format=json');
      if LResp.StatusCode = 200 then
      begin
        LJson := TJSONObject.ParseJSONValue(LResp.ContentAsString) as TJSONObject;
        if Assigned(LJson) then
        try
          LRespObj := LJson.GetValue('response') as TJSONObject;
          if Assigned(LRespObj) then
          begin
            LFileObj := LRespObj.GetValue('file_info') as TJSONObject;
            if Assigned(LFileObj) then
            begin
              aFileEntry.FileName := LFileObj.GetValue('filename').Value;
              aFileEntry.ExpectedHash := LFileObj.GetValue('hash').Value;
              aFileEntry.Size := StrToInt64Def(LFileObj.GetValue('size').Value, 0);
              LLinks := LFileObj.GetValue('links') as TJSONObject;
              if Assigned(LLinks) and Assigned(LLinks.GetValue('normal_download')) then
                aFileEntry.ScrambledLink := LLinks.GetValue('normal_download').Value;
              Result := True;
            end;
          end;
        finally
          LJson.Free;
        end;
      end;
    except
    end;
  finally
    LClient.Free;
  end;
end;

function TMediaFireClient.ExtractRegexGroup(const aText, aPattern: string; aGroup: Integer): string;
var
  LMatch: TMatch;
begin
  Result := '';
  LMatch := TRegEx.Match(aText, aPattern);
  if LMatch.Success and (LMatch.Groups.Count > aGroup) then
    Result := LMatch.Groups[aGroup].Value;
end;

function TMediaFireClient.Base64DecodeStr(const aBase64: string): string;
begin
  Result := TNetEncoding.Base64.Decode(aBase64);
end;

function TMediaFireClient.ResolveDirectLink(const aScrambledUrl: string; out aDirectUrl: string): Boolean;
var
  LClient: THTTPClient;
  LResp: IHTTPResponse;
  LContentType: string;
  LHtml, LScrambledB64: string;
begin
  Result := False;
  LClient := CreateClient(True);
  try
    try
      LResp := LClient.Get(aScrambledUrl);
      if (LResp.StatusCode >= 400) and (LResp.StatusCode <= 599) then
        Exit;

      LContentType := LResp.HeaderValue['Content-Type'];
      if LContentType.StartsWith('text/html') or LContentType.IsEmpty then
      begin
        LHtml := LResp.ContentAsString;

        // Legacy layout (pre-2025-ish): base64 scrambled url on #downloadButton.
        // Kept as first attempt in case MediaFire ever reverts/A-B tests it.
        LScrambledB64 := ExtractRegexGroup(LHtml, 'id="downloadButton"[^>]*data-scrambled-url="([^"]+)"', 1);
        if LScrambledB64 <> '' then
        begin
          aDirectUrl := Base64DecodeStr(LScrambledB64);
          Result := True;
        end
        else
        begin
          // Current layout: plain href on #downloadButton, attribute order not guaranteed.
          aDirectUrl := ExtractRegexGroup(LHtml, 'id="downloadButton"[^>]*href="([^"]+)"', 1);
          if aDirectUrl = '' then
            aDirectUrl := ExtractRegexGroup(LHtml, 'href="([^"]+)"[^>]*id="downloadButton"', 1);

          // Fallback: some renders use aria-label instead of/alongside id.
          if aDirectUrl = '' then
            aDirectUrl := ExtractRegexGroup(LHtml, 'aria-label="Download file"[^>]*href="([^"]+)"', 1);
          if aDirectUrl = '' then
            aDirectUrl := ExtractRegexGroup(LHtml, 'href="([^"]+)"[^>]*aria-label="Download file"', 1);

          // Most robust fallback: match MediaFire's CDN download host directly.
          // This is the part of the page least likely to change regardless of
          // whatever markup/id/class MediaFire ships around the button next.
          if aDirectUrl = '' then
            aDirectUrl := ExtractRegexGroup(LHtml, 'href="(https?://download\d*\.mediafire\.com/[^"]+)"', 1);

          if aDirectUrl <> '' then
          begin
            aDirectUrl := aDirectUrl.Replace('&amp;', '&');
            Result := True;
          end;
        end;
      end
      else
      begin
        aDirectUrl := aScrambledUrl;
        Result := True;
      end;
    except
    end;
  finally
    LClient.Free;
  end;
end;

function TMediaFireClient.DownloadFile(const aDirectUrl, aDestPath: string; aUseProxy: Boolean;
  aProgressProc: TProc<Int64, Int64>): TDownloadError;
var
  LClient: THTTPClient;
  LResp: IHTTPResponse;
  LFileStream: TFileStream;
  LOnDownloading: iOndownloadEvent;
begin
  Result := deHttpError;
  LClient := CreateClient(aUseProxy);
  try
    LOnDownloading := TOndownloadEvent.New;

    LClient.OnReceiveData :=
      LOnDownloading.ReceiveData(procedure(const Sender: TObject; AContentLength, AReadCount: Int64; var AAbort: Boolean)
      begin
        if Assigned(aProgressProc) then
          aProgressProc(AReadCount, AContentLength);
      end);
    try
      LFileStream := TFileStream.Create(aDestPath, fmCreate or fmShareDenyWrite);
      try
        LResp := LClient.Get(aDirectUrl, LFileStream);
        if (LResp.StatusCode >= 400) and (LResp.StatusCode <= 599) then
          Result := deDangerousOrDeleted
        else if LResp.StatusCode = 200 then
          Result := deNone;
      finally
        LFileStream.Free;
      end;
      if Result <> deNone then
        TFile.Delete(aDestPath);
    except
      on E: Exception do
      begin
        Result := deIoError;
        if TFile.Exists(aDestPath) then
          TFile.Delete(aDestPath);
      end;
    end;
  finally
    LClient.Free;
  end;
end;

end.
