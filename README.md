# GetMF

A fast, concurrent MediaFire folder/file downloader for Windows, written in Delphi.

Point it at one or more MediaFire folder or file links, and it will crawl every file inside, resolve real download URLs, and pull them down in parallel — with retries, proxy support, and a live progress bar.

```
[##########] 61/61 (100%) · Downloading · Failed: 0
Completed: 61 | Failed: 0
```

---

## Features

- 🔗 **Folders and single files** — pass a `mediafire.com/folder/...` link and every file inside is discovered and queued automatically, or pass individual `mediafire.com/file/...` links directly.
- ⚡ **Concurrent downloads** — configurable worker pool (default 10 at once) for fast bulk downloads.
- 🔁 **Automatic retries** — failed downloads are retried up to a configurable number of times before being marked failed.
- 🌐 **Proxy support** — rotate through a list of proxies for metadata requests, and optionally for the file downloads themselves.
- 📊 **Live progress bar** — real-time percentage, completed/failed counts, and a summary of exactly which files failed and why.
- 📁 **Batch input** — feed it a text file full of links instead of typing them all on the command line.
- 🗂 **Largest-first mode** — optionally download the biggest files first, useful when you want to prioritize the slow ones.

---

## Installation

1. Grab `GetMF.exe` (or build it yourself — see [Building from source](#building-from-source)).
2. Drop it anywhere on your `PATH`, or just run it from the folder you downloaded it to.

No installer, no dependencies — it's a single self-contained console `.exe`.

---

## Quick start

Download every file in a MediaFire folder into the current directory:

```
GetMF "https://www.mediafire.com/folder/jybi7uj5j91le/R340"
```

Download a single file:

```
GetMF "https://www.mediafire.com/file/xxxxxxxxxxxxx/example.zip"
```

Download several links at once into a specific folder:

```
GetMF -o D:\Downloads\Mirrors "https://www.mediafire.com/folder/aaa/A" "https://www.mediafire.com/file/bbb/b.zip"
```

---

## Usage

```
GetMF [OPTIONS] <URLS>...
```

### Arguments

| Argument | Description |
|---|---|
| `<URLS>...` | One or more MediaFire folder or file URLs |

### Options

| Flag | Description | Default |
|---|---|---|
| `-i, --input <FILE>` | Text file containing URLs (one per line) — merged with any URLs on the command line | — |
| `-o, --output <OUTPUT>` | Output directory | `.` (current folder) |
| `-m, --max <MAX>` | Max concurrent downloads (1–100) | `10` |
| `-t, --tries <TRIES>` | Max retry attempts per file (1–10) | `1` |
| `-r, --reverse` | Download largest files first | off |
| `-p, --proxy <FILE>` | File with a list of proxies (one per line), used for folder/file metadata lookups | — |
| `--proxy-download` | Also route the actual file downloads through the proxy list, not just metadata lookups | off |
| `-h, --help` | Print help | — |
| `-V, --version` | Print version | — |

---

## Examples

**Bulk download from a list of links saved in a file:**

```
GetMF -i links.txt -o D:\Downloads
```

`links.txt`:
```
https://www.mediafire.com/folder/jybi7uj5j91le/R340
https://www.mediafire.com/file/abc123/movie.mp4
```

**Download faster with more concurrent workers:**

```
GetMF -m 25 "https://www.mediafire.com/folder/jybi7uj5j91le/R340"
```

**Retry flaky files up to 5 times before giving up:**

```
GetMF -t 5 "https://www.mediafire.com/folder/jybi7uj5j91le/R340"
```

**Route everything through a proxy list (metadata + downloads):**

```
GetMF -p proxies.txt --proxy-download "https://www.mediafire.com/folder/jybi7uj5j91le/R340"
```

`proxies.txt`:
```
http://user:pass@10.0.0.1:8080
http://10.0.0.2:3128
```

**Grab the biggest files in a folder first:**

```
GetMF -r "https://www.mediafire.com/folder/jybi7uj5j91le/R340"
```

---

## How it works

1. **Resolve** — each URL you provide is inspected: folders are crawled recursively for every file they contain; single-file links are used as-is. This produces a flat job list of files with their destination paths.
2. **Download** — a pool of concurrent workers pulls jobs off the queue, resolves each file's real (non-scrambled) download link, and streams it to disk with live progress.
3. **Retry** — if a download fails (network error, dead link, etc.), it's retried up to `--tries` times before being marked as failed.
4. **Report** — once everything finishes, a summary is printed with completed/failed counts and, for any failures, the filename, error, and original link — so you can retry just the failed ones if needed.

---

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success — help/version printed, or all resolvable files processed |
| `1` | Error — no valid URLs given, or an unhandled exception occurred |

---

## Building from source

Requires **Delphi** (tested with recent RAD Studio versions) — no third-party component packages needed, only the Delphi RTL.

1. Clone/copy the project, keeping the `API\` subfolder alongside `GetMF.dpr`.
2. Open `GetMF.dpr` in the Delphi IDE, or build from the command line with `msbuild` / `dcc32` / `dcc64`.
3. Build in `Release` configuration for a standalone `GetMF.exe`.

### Project layout

```
GetMF.dpr                     Entry point / CLI wiring
API/
  API.Cli.Options.pas          Argument parsing, --help/--version text
  API.Console.Reporter.pas     Progress bar, spinner, final summary
  API.Download.Worker.pas      Concurrent download worker pool
  API.Hashing.pas              File hashing utilities
  API.Io.UrlList.pas           Reading URL/proxy lists from file
  API.MediaFire.Client.pas     MediaFire HTTP client (folder/file metadata, direct-link resolution)
  API.MediaFire.Resolver.pas   Turns input URLs into a flat list of download jobs
  API.MediaFire.Types.pas      Shared types (file entries, error codes, etc.)
  API.Naming.pas                Destination filename/path handling
  API.Proxy.Provider.pas       Proxy rotation
```

---

## Notes

- GetMF resolves MediaFire's real download link directly from the file page each time — no scraping tricks that depend on unstable page internals beyond what's necessary to find the link, so it keeps working across MediaFire's routine markup changes.
- Files that already exist at the destination with a matching size/hash are skipped rather than re-downloaded (where applicable).
- Press `Ctrl+C` at any time to stop cleanly — in-progress downloads are abandoned but already-completed files are kept.

---

## Disclaimer

GetMF is an independent tool and is not affiliated with, endorsed by, or supported by MediaFire. Only use it to download content you have the right to access.

