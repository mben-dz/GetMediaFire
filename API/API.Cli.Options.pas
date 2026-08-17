unit API.Cli.Options;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
//
  API.Io.UrlList;

type
  ACliOptions = record
    Urls: TArray<string>;
    InputFile: string;
    OutputDir: string;
    MaxConcurrent: Integer;
    MaxTries: Integer;
    ReverseSort: Boolean;
    ProxyFile: string;
    ProxyDownload: Boolean;
    ShowHelp: Boolean;
    ShowVersion: Boolean;
  end;

  TCliParser = class
  public
    class function ParseArgs(const aArgs: TArray<string>; out aOptions: ACliOptions): Boolean;
    class procedure PrintHelp;
    class procedure PrintVersion;
  end;

implementation

class procedure TCliParser.PrintHelp;
begin
  Writeln('mfdl [OPTIONS] <URLS>...');
  Writeln('');
  Writeln('Arguments:');
  Writeln('  <URLS>...              One or more MediaFire folder or file URLs');
  Writeln('');
  Writeln('Options:');
  Writeln('  -i, --input <FILE>       File containing URLs');
  Writeln('  -o, --output <OUTPUT>    Output directory [default: .]');
  Writeln('  -m, --max <MAX>          Max concurrent downloads (1-100) [default: 10]');
  Writeln('  -t, --tries <TRIES>      Max retries per download (1-10) [default: 1]');
  Writeln('  -r, --reverse            Download largest files first');
  Writeln('  -p, --proxy <FILE>       File with list of proxies');
  Writeln('      --proxy-download     Use the proxy list for the actual file download too');
  Writeln('  -h, --help               Print help');
  Writeln('  -V, --version            Print version');
end;

class procedure TCliParser.PrintVersion;
begin
  Writeln('mfdl version 1.0.0');
end;

class function TCliParser.ParseArgs(const aArgs: TArray<string>; out aOptions: ACliOptions): Boolean;
var
  i: Integer;
  LUrls: TList<string>;
  aArg: string;
  LFileUrls: TArray<string>;
  u: string;
begin
  Result := True;
  aOptions.OutputDir := '.';
  aOptions.MaxConcurrent := 10;
  aOptions.MaxTries := 1;
  aOptions.ReverseSort := False;
  aOptions.ProxyDownload := False;
  aOptions.ShowHelp := False;
  aOptions.ShowVersion := False;

  LUrls := TList<string>.Create;
  try
    i := 0;
    while i < Length(aArgs) do
    begin
      aArg := aArgs[i];
      if (aArg = '-h') or (aArg = '--help') then
      begin
        aOptions.ShowHelp := True;
        Exit;
      end
      else if (aArg = '-V') or (aArg = '--version') then
      begin
        aOptions.ShowVersion := True;
        Exit;
      end
      else if (aArg = '-i') or (aArg = '--input') then
      begin
        Inc(i);
        if i < Length(aArgs) then aOptions.InputFile := aArgs[i];
      end
      else if (aArg = '-o') or (aArg = '--output') then
      begin
        Inc(i);
        if i < Length(aArgs) then aOptions.OutputDir := aArgs[i];
      end
      else if (aArg = '-m') or (aArg = '--max') then
      begin
        Inc(i);
        if i < Length(aArgs) then aOptions.MaxConcurrent := StrToIntDef(aArgs[i], 10);
      end
      else if (aArg = '-t') or (aArg = '--tries') then
      begin
        Inc(i);
        if i < Length(aArgs) then aOptions.MaxTries := StrToIntDef(aArgs[i], 1);
      end
      else if (aArg = '-r') or (aArg = '--reverse') then
      begin
        aOptions.ReverseSort := True;
      end
      else if (aArg = '-p') or (aArg = '--proxy') then
      begin
        Inc(i);
        if i < Length(aArgs) then aOptions.ProxyFile := aArgs[i];
      end
      else if (aArg = '--proxy-download') then
      begin
        aOptions.ProxyDownload := True;
      end
      else if not aArg.StartsWith('-') then
      begin
        LUrls.Add(aArg);
      end;
      Inc(i);
    end;

    if aOptions.InputFile <> '' then
    begin
      LFileUrls := LoadLinesFromFile(aOptions.InputFile);
      for u in LFileUrls do
        if not LUrls.Contains(u) then LUrls.Add(u);
    end;

    aOptions.Urls := LUrls.ToArray;

    if (Length(aOptions.Urls) = 0) then
    begin
      Result := False;
    end;
  finally
    LUrls.Free;
  end;
end;

end.
