unit API.Io.UrlList;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.IOUtils;

function LoadLinesFromFile(const aFilePath: string): TArray<string>;

implementation

function LoadLinesFromFile(const aFilePath: string): TArray<string>;
var
  LLines: TStringList;
  LList: TList<string>;
  LLine: string;
  LTrimmed: string;
begin
  Result := [];
  if not TFile.Exists(aFilePath) then
    Exit;
  
  LLines := TStringList.Create;
  LList := TList<string>.Create;
  try
    LLines.LoadFromFile(aFilePath);
    for LLine in LLines do
    begin
      LTrimmed := Trim(LLine);
      if (LTrimmed <> '') and (not LTrimmed.StartsWith('#')) then
      begin
        if not LList.Contains(LTrimmed) then
          LList.Add(LTrimmed);
      end;
    end;
    Result := LList.ToArray;
  finally
    LLines.Free;
    LList.Free;
  end;
end;

end.
