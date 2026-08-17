unit API.Console.Reporter;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  Winapi.Windows,
//
  API.MediaFire.Types;

type
  IConsoleReporter = interface
    ['{A1B2C3D4-E5F6-4A5B-8C7D-9E0F1A2B3C4D}']
    procedure SpinFetching(const aName: string);
    procedure ClearSpinner;
    procedure StartDownloads(aTotalFiles: Integer);
    procedure UpdateWorkerStatus(aWorkerId: Integer; const aStatus: string; aProgress: Integer = -1; aTotal: Integer = -1);
    procedure JobSuccess(const aFileName: string);
    procedure JobFailed(const aFileName, aErrorMsg, aLink: string);
    procedure FinalReport;
  end;

  TConsoleReporter = class(TInterfacedObject, IConsoleReporter)
  private
    FLock: TCriticalSection;
    FSpinnerChars: array[0..3] of Char;
    FSpinnerIndex: Integer;
    FStdOut: THandle;
    FTotalFiles: Integer;
    FCompletedFiles: Integer;
    FFailedFiles: Integer;
    FWorkerLines: TArray<string>;
    FFailedJobs: TArray<string>;
    procedure WriteColor(const aText: string; aColor: Word);
    procedure DrawBars;
  public
    constructor Create(aWorkers: Integer);
    destructor Destroy; override;
    procedure SpinFetching(const aName: string);
    procedure ClearSpinner;
    procedure StartDownloads(aTotalFiles: Integer);
    procedure UpdateWorkerStatus(aWorkerId: Integer; const aStatus: string; aProgress: Integer = -1; aTotal: Integer = -1);
    procedure JobSuccess(const aFileName: string);
    procedure JobFailed(const aFileName, aErrorMsg, aLink: string);
    procedure FinalReport;
  end;

implementation

uses System.Math;

constructor TConsoleReporter.Create(aWorkers: Integer);
begin
  FLock := TCriticalSection.Create;
  FSpinnerChars[0] := '|';
  FSpinnerChars[1] := '/';
  FSpinnerChars[2] := '-';
  FSpinnerChars[3] := '\';
  FSpinnerIndex := 0;
  FStdOut := GetStdHandle(STD_OUTPUT_HANDLE);
  SetLength(FWorkerLines, aWorkers);
end;

destructor TConsoleReporter.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TConsoleReporter.WriteColor(const aText: string; aColor: Word);
var
  LOldColor: CONSOLE_SCREEN_BUFFER_INFO;
begin
  GetConsoleScreenBufferInfo(FStdOut, LOldColor);
  SetConsoleTextAttribute(FStdOut, aColor);
  Write(aText);
  SetConsoleTextAttribute(FStdOut, LOldColor.wAttributes);
end;

procedure TConsoleReporter.SpinFetching(const aName: string);
begin
  FLock.Acquire;
  try
    FSpinnerIndex := (FSpinnerIndex + 1) mod 4;
    Write(#13, FSpinnerChars[FSpinnerIndex], ' Fetching data ', #183, ' ', aName, '                     ');
  finally
    FLock.Release;
  end;
end;

procedure TConsoleReporter.ClearSpinner;
begin
  FLock.Acquire;
  try
    Write(#13, StringOfChar(' ', 80), #13);
  finally
    FLock.Release;
  end;
end;

procedure TConsoleReporter.StartDownloads(aTotalFiles: Integer);
begin
  FTotalFiles := aTotalFiles;
  FCompletedFiles := 0;
  FFailedFiles := 0;
end;

procedure TConsoleReporter.DrawBars;
var
  i: Integer;
  LPercent: Double;
begin
  if FTotalFiles = 0 then Exit;
  LPercent := ((FCompletedFiles + FFailedFiles) / FTotalFiles) * 100;
  Write(#13, '[');
  for i := 1 to 10 do
    if LPercent >= (i * 10) then Write('#') else Write('-');
  Write('] ', FCompletedFiles + FFailedFiles, '/', FTotalFiles, ' (', Trunc(LPercent), '%) ', #183, ' Downloading ', #183, ' Failed: ', FFailedFiles, '        ');
end;

procedure TConsoleReporter.UpdateWorkerStatus(aWorkerId: Integer; const aStatus: string; aProgress: Integer = -1; aTotal: Integer = -1);
begin
  FLock.Acquire;
  try
    DrawBars;
  finally
    FLock.Release;
  end;
end;

procedure TConsoleReporter.JobSuccess(const aFileName: string);
begin
  FLock.Acquire;
  try
    Inc(FCompletedFiles);
    DrawBars;
  finally
    FLock.Release;
  end;
end;

procedure TConsoleReporter.JobFailed(const aFileName, aErrorMsg, aLink: string);
begin
  FLock.Acquire;
  try
    Inc(FFailedFiles);
    SetLength(FFailedJobs, Length(FFailedJobs) + 1);
    FFailedJobs[High(FFailedJobs)] := aFileName + ' ' + #183 + ' ' + aErrorMsg + ' ' + #183 + ' ' + aLink;
    DrawBars;
  finally
    FLock.Release;
  end;
end;

procedure TConsoleReporter.FinalReport;
var
  LJob: string;
begin
  FLock.Acquire;
  try
    Writeln;
    Writeln('Completed: ', FCompletedFiles, ' | Failed: ', FFailedFiles);
    if Length(FFailedJobs) > 0 then
    begin
      WriteColor('Failed downloads:', FOREGROUND_RED or FOREGROUND_INTENSITY);
      Writeln;
      for LJob in FFailedJobs do
      begin
        WriteColor(LJob, FOREGROUND_RED);
        Writeln;
      end;
    end;
  finally
    FLock.Release;
  end;
end;

end.
