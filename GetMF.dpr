program GetMF;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Winapi.Windows,
  API.MediaFire.Types in 'API\API.MediaFire.Types.pas',
  API.Naming in 'API\API.Naming.pas',
  API.Hashing in 'API\API.Hashing.pas',
  API.Io.UrlList in 'API\API.Io.UrlList.pas',
  API.Cli.Options in 'API\API.Cli.Options.pas',
  API.Proxy.Provider in 'API\API.Proxy.Provider.pas',
  API.Console.Reporter in 'API\API.Console.Reporter.pas',
  API.MediaFire.Client in 'API\API.MediaFire.Client.pas',
  API.MediaFire.Resolver in 'API\API.MediaFire.Resolver.pas',
  API.Download.Worker in 'API\API.Download.Worker.pas';

var
  LOptions: ACliOptions;
  LProxyProvider: IProxyProvider;
  LReporter: IConsoleReporter;
  LClient: IMediaFireClient;
  LResolver: IJobResolver;
  LWorkerPool: IWorkerPool;
  LJobs: TArray<AFileEntry>;
  LArgs: TArray<string>;
  i: Integer;

function CtrlCHandler(CtrlType: DWORD): BOOL; stdcall;
begin
  if (CtrlType = CTRL_C_EVENT) or (CtrlType = CTRL_BREAK_EVENT) or (CtrlType = CTRL_CLOSE_EVENT) then
  begin
    Writeln;
    Writeln('Exiting ...');
    Halt(0);
  end;
  Result := True;
end;

begin
  try
    SetConsoleCtrlHandler(@CtrlCHandler, True);

    SetLength(LArgs, ParamCount);
    for i := 1 to ParamCount do
      LArgs[i - 1] := ParamStr(i);

    if not TCliParser.ParseArgs(LArgs, LOptions) then
    begin
      if LOptions.ShowHelp then
      begin
        TCliParser.PrintHelp;
        ExitCode := 0;
        Exit;
      end;
      if LOptions.ShowVersion then
      begin
        TCliParser.PrintVersion;
        ExitCode := 0;
        Exit;
      end;

      Writeln('Error: URL(s) or -i/--input file required.');
      TCliParser.PrintHelp;
      ExitCode := 1;
      Exit;
    end;

    LProxyProvider := TProxyProvider.Create(LOptions.ProxyFile);
    LReporter      := TConsoleReporter.Create(LOptions.MaxConcurrent);
    LClient        := TMediaFireClient.Create(LProxyProvider);
    LResolver      := TJobResolver.Create(LClient, LReporter);

    LJobs := LResolver.ResolveUrls(LOptions.Urls, LOptions.OutputDir);
    if Length(LJobs) = 0 then
    begin
      Writeln('No valid downloadable files found.');
      ExitCode := 0;
      Exit;
    end;

    LWorkerPool := TDownloadWorkerPool.Create(LClient, LReporter);
    LWorkerPool.Execute(LJobs, LOptions.MaxConcurrent, LOptions.MaxTries, LOptions.ReverseSort, LOptions.ProxyDownload);

    LReporter.FinalReport;

  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;

end.
