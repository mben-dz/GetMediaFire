unit API.Proxy.Provider;

interface

uses
  System.SysUtils,
  System.SyncObjs,
//
  API.Io.UrlList;

type
  IProxyProvider = interface
    ['{6E7F8C4A-5D2B-4A9E-8C9B-7D8E9F0A1B2C}']
    function GetNextProxy(out aProxyUrl: string): Boolean;
    function HasProxies: Boolean;
  end;

  TProxyProvider = class(TInterfacedObject, IProxyProvider)
  private
    FProxies: TArray<string>;
    FIndex: Integer;
    FLock: TCriticalSection;
  public
    constructor Create(const aProxyFile: string);
    destructor Destroy; override;
    function GetNextProxy(out aProxyUrl: string): Boolean;
    function HasProxies: Boolean;
  end;

implementation

constructor TProxyProvider.Create(const aProxyFile: string);
begin
  FLock := TCriticalSection.Create;
  FIndex := 0;
  if aProxyFile <> '' then
    FProxies := LoadLinesFromFile(aProxyFile)
  else
    FProxies := [];
end;

destructor TProxyProvider.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TProxyProvider.HasProxies: Boolean;
begin
  Result := Length(FProxies) > 0;
end;

function TProxyProvider.GetNextProxy(out aProxyUrl: string): Boolean;
begin
  Result := False;
  if Length(FProxies) = 0 then Exit;
  
  FLock.Acquire;
  try
    aProxyUrl := FProxies[FIndex];
    FIndex := (FIndex + 1) mod Length(FProxies);
    Result := True;
  finally
    FLock.Release;
  end;
end;

end.
