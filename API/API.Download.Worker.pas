unit API.Download.Worker;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.Generics.Defaults, System.Threading, System.SyncObjs, 
  System.IOUtils, System.Math, API.MediaFire.Types, API.MediaFire.Client, API.Console.Reporter, API.Hashing;

type
  IWorkerPool = interface
    ['{7890ABCD-EF01-2345-6789-0ABCDEF01234}']
    procedure Execute(const aJobs: TArray<AFileEntry>; aMaxConcurrent, aMaxTries: Integer; aReverse: Boolean; aProxyDownload: Boolean);
  end;

  TDownloadWorkerPool = class(TInterfacedObject, IWorkerPool)
  private
    FClient: IMediaFireClient;
    FReporter: IConsoleReporter;
    FJobQueue: TThreadedQueue<AFileEntry>;
  public
    constructor Create(const aClient: IMediaFireClient; const aReporter: IConsoleReporter);
    procedure Execute(const aJobs: TArray<AFileEntry>; aMaxConcurrent, aMaxTries: Integer; aReverse: Boolean; aProxyDownload: Boolean);
  end;

implementation

const
  cRetryDelaySeconds = 2;

constructor TDownloadWorkerPool.Create(const aClient: IMediaFireClient; const aReporter: IConsoleReporter);
begin
  FClient := aClient;
  FReporter := aReporter;
end;

procedure TDownloadWorkerPool.Execute(const aJobs: TArray<AFileEntry>; aMaxConcurrent, aMaxTries: Integer; aReverse: Boolean; aProxyDownload: Boolean);
var
  LSortedJobs: TArray<AFileEntry>;
  LTasks: TArray<ITask>;
  i: Integer;
  LWorkerId: Integer;
begin
  if Length(aJobs) = 0 then Exit;

  LSortedJobs := Copy(aJobs, 0, Length(aJobs));
  if aReverse then
  begin
    TArray.Sort<AFileEntry>(LSortedJobs, TComparer<AFileEntry>.Construct(
      function(const L, R: AFileEntry): Integer
      begin
        Result := R.Size - L.Size;
      end));
  end;

  FJobQueue := TThreadedQueue<AFileEntry>.Create(10000, 0);
  try
    for i := 0 to Length(LSortedJobs) - 1 do
      FJobQueue.PushItem(LSortedJobs[i]);

    FReporter.StartDownloads(Length(LSortedJobs));

    SetLength(LTasks, Min(aMaxConcurrent, Length(LSortedJobs)));
    for i := 0 to Length(LTasks) - 1 do
    begin
      LWorkerId := i + 1;
      LTasks[i] := TTask.Run(procedure
        var
          LJob: AFileEntry;
          LTries: Integer;
          LSuccess: Boolean;
          LDirectUrl: string;
          LErr: TDownloadError;
          LHash: string;
        begin
          while FJobQueue.PopItem(LJob) = wrSignaled do
          begin
            LSuccess := False;
            LErr := deNone;
            FReporter.UpdateWorkerStatus(LWorkerId, LJob.FileName + ' [HASH]');
            
            if TFile.Exists(LJob.DestinationPath) then
            begin
              LHash := Sha256HexOfFile(LJob.DestinationPath);
              if SameText(LHash, LJob.ExpectedHash) then
              begin
                LSuccess := True;
                FReporter.JobSuccess(LJob.FileName);
                Continue;
              end
              else
                TFile.Delete(LJob.DestinationPath);
            end;

            for LTries := 1 to aMaxTries do
            begin
              FReporter.UpdateWorkerStatus(LWorkerId, LJob.FileName + ' [GET LINK]');
              if FClient.ResolveDirectLink(LJob.ScrambledLink, LDirectUrl) then
              begin
                FReporter.UpdateWorkerStatus(LWorkerId, LJob.FileName + ' [DL]');
                LErr := FClient.DownloadFile(LDirectUrl, LJob.DestinationPath, aProxyDownload,
                  procedure(aRead, aTotal: Int64)
                  begin
                  end);
                
                if LErr = deNone then
                begin
                  LSuccess := True;
                  Break;
                end;
              end
              else
              begin
                LErr := deInvalidLink;
              end;
              
              if LErr = deDangerousOrDeleted then Break;

              Sleep(cRetryDelaySeconds * 1000);
            end;

            if LSuccess then
              FReporter.JobSuccess(LJob.FileName)
            else
              FReporter.JobFailed(LJob.FileName, 'Exhausted retries or fatal error', LJob.ScrambledLink);
          end;
        end);
    end;

    TTask.WaitForAll(LTasks);
  finally
    FJobQueue.Free;
  end;
end;

end.
