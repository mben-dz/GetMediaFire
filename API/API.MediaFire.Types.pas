unit API.MediaFire.Types;

interface

uses
  System.SysUtils;

type
  TDownloadError = (deNone, deInvalidLink, deHttpError, deIoError, deHashMismatch, deDangerousOrDeleted, deCancelled);

  TDownloadProgressKind = (dpGettingLink, dpCheckingHash, dpDownloading, dpTryResuming, dpDone);

  AFileEntry = record
    FileName: string;
    ScrambledLink: string;
    DirectLink: string;
    ExpectedHash: string;
    Size: Int64;
    DestinationPath: string;
  end;

  ADownloadJob = class
  public
    FileEntry: AFileEntry;
    Error: TDownloadError;
    ErrorMessage: string;
    constructor Create(const aEntry: AFileEntry);
  end;

implementation

constructor ADownloadJob.Create(const aEntry: AFileEntry);
begin
  inherited Create;
  FileEntry := aEntry;
  Error := deNone;
end;

end.
