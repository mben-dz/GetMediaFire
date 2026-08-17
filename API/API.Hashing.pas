unit API.Hashing;

interface

uses
  System.Hash,
  System.SysUtils,
  System.Classes;

function Sha256HexOfFile(const aFilePath: string): string;

implementation

function Sha256HexOfFile(const aFilePath: string): string;
var
  LStream: TFileStream;
begin
  Result := '';
  if not FileExists(aFilePath) then
    Exit;
  LStream := TFileStream.Create(aFilePath, fmOpenRead or fmShareDenyWrite);
  try
    Result := THashSHA2.GetHashString(LStream, THashSHA2.TSHA2Version.SHA256);
  finally
    LStream.Free;
  end;
end;

end.
