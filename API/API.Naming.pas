unit API.Naming;

interface

uses
  System.SysUtils;

function NormalizeFileOrFolderName(const aName: string): string;

implementation

function NormalizeFileOrFolderName(const aName: string): string;
var
  i: Integer;
  c: Char;
begin
  Result := '';
  for i := 1 to Length(aName) do
  begin
    c := aName[i];
    if CharInSet(c, ['a'..'z', 'A'..'Z', '0'..'9', '-', '_', '.', ' ']) then
      Result := Result + c
    else
      Result := Result + '-';
  end;
end;

end.
