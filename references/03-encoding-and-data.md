# Encoding, UTF-8, and Data Integrity

Official references: [about_Character_Encoding](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_character_encoding?view=powershell-7.5), [about_Redirection](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_redirection?view=powershell-7.5), [Console.OutputEncoding](https://learn.microsoft.com/en-us/dotnet/api/system.console.outputencoding?view=net-9.0), [chcp](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/chcp), and [Python command line and environment](https://docs.python.org/3/using/cmdline.html#envvar-PYTHONIOENCODING).

## 1. Locate the corruption boundary

| Boundary | Verify | Do not assume |
|---|---|---|
| `.ps1` bytes to PowerShell source | Engine, BOM, actual file encoding | Setting UTF-8 after startup can repair source decoding |
| File bytes and PowerShell strings | `-Encoding`, BOM, consumer contract | Console encoding sets file encoding |
| PowerShell strings to native stdin | `$OutputEncoding`, child decoding | `PYTHONUTF8` changes the parent's emitted bytes |
| Native stdout/stderr to PowerShell strings | Program's actual encoding, host/Console decoding | Every Windows program emits UTF-8 |
| Process output to the agent tool | Capture/decoding settings and redirection mode | Correct display proves correct file bytes |
| Strings to displayed glyphs | Font and terminal rendering | Missing glyphs always indicate corrupt bytes |
| Native binary output to files | Any text decoding/re-encoding stage | `Out-File` preserves arbitrary binary data |

Text already replaced with `?` or Unicode replacement character U+FFFD may have lost information. Preserve original bytes and reread them with the correct encoding; do not repeatedly guess at UTF-8 conversions. Never upload user files to an external transcoding service.

## 2. PowerShell 7.x encoding rules

Only PowerShell 7.x execution is supported. Do not retain older-engine encoding or execution branches.

| Behavior | PowerShell 7.x rule |
|---|---|
| Non-ASCII `.ps1` without BOM | Read as UTF-8 by default; prefer UTF-8 source without BOM |
| Writing with `-Encoding UTF8` | UTF-8 **without BOM** |
| `utf8NoBOM` / `utf8BOM` | Explicitly choose the BOM policy |
| `Out-File` and PowerShell text `>`/`>>` defaults | UTF-8 without BOM; still match the destination's encoding |
| New `Set-Content` file default | UTF-8 without BOM; prefer explicit encoding for data |
| `Get-Content` without BOM | UTF-8; explicitly identify other known encodings |
| `$OutputEncoding` default | Normally UTF-8 without BOM; check host modifications |
| Numeric code page such as `-Encoding 936` | Supported registered code pages; use only when the consumer actually expects them |
| `-Encoding ansi` | 7.4+; not a universal fix for localized environments |
| Direct native stdout `>` preserves bytes | **7.4+**, not every pipeline |

Existing UTF-16/ANSI files and third-party output remain valid data when decoded according to their actual format. Handling them does not require, or authorize, launching an older PowerShell.

## 3. Initialize a UTF-8 text invocation

Only when every participating program agrees on UTF-8:

```powershell
$utf8 = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = $utf8
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
```

- `$OutputEncoding` governs text sent from PowerShell to native applications, not file encoding for `Set-Content`/`Out-File`.
- Console input/output encoding concerns console/native boundaries. It does not force arbitrary older applications to use UTF-8 or necessarily reconfigure already running programs.
- `chcp.com 65001` changes the active console code page, not the entire pipeline. Use it locally only for a real console and a verified program dependency. Do not permanently change locale settings, registry entries, or profiles.
- Console setters can fail in non-console agent hosts. Do not swallow the error and claim success. Use explicitly encoded files, appropriate `ProcessStartInfo` encoding properties, program-specific output options, or fewer redirection layers.
- Save and restore Console encoding and `$OutputEncoding` in shared/persistent sessions. A child scope does not undo Console setters.
- Explicit `-Encoding` is clearer than global defaults. Even a temporary `$PSDefaultParameterValues['Out-File:Encoding']` does not control native byte redirection in 7.4+. Do not globally set `'*:Encoding'` in a user profile.

## 4. Read text and write exact bytes

### Text and JSON

```powershell
$path = 'C:\data\config[1].json'
$jsonText = Get-Content -LiteralPath $path -Raw -Encoding UTF8 -ErrorAction Stop
$config = $jsonText | ConvertFrom-Json -ErrorAction Stop
```

`-Raw` returns one complete string. Default per-line arrays are not the original file text; do not guess at multiline JSON by parsing individual lines.

Explicit UTF-8 without BOM:

```powershell
$text = @{ message = ([string][char]0x4E2D + [string][char]0x6587) } | ConvertTo-Json -Compress
Set-Content -LiteralPath 'C:\data\output.json' -Value $text -Encoding utf8NoBOM -NoNewline -ErrorAction Stop
```

Exact .NET file output; the parent directory must already exist:

```powershell
$path = 'C:\data\output.json'
$text = @{ message = ([string][char]0x4E2D + [string][char]0x6587) } | ConvertTo-Json -Compress
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
```

`WriteAllText` takes a file-system path without wildcard interpretation and overwrites an existing file. Confirm the destination and overwrite intent first. It does not create parent directories. If a final newline is required, include it explicitly instead of relying on an implicit extra line.

### Non-ASCII PowerShell 7.x scripts default to no BOM

```powershell
$scriptText = @'
Write-Output ([string][char]0x4E2D + [string][char]0x6587)
'@
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText('C:\tools\demo.ps1', $scriptText, $utf8NoBom)
```

This example constructs non-ASCII data from code points. PowerShell 7.x also reads actual non-ASCII UTF-8 script text correctly without a BOM; the self-test verifies this with generated source. Use `UTF8Encoding($true)` only for a consumer explicitly requiring a BOM, never as an older-engine compatibility workaround.

### Appending, newlines, and BOM

- Append using the original file encoding. Do not append UTF-8 to a UTF-16LE file. `Out-File -Append`/`>>` do not automatically match the existing encoding.
- `Add-Content` can detect BOMs; still use explicit encoding for known UTF-8 files and verify final bytes. Automatic detection cannot reliably identify every BOM-less legacy format.
- Put a BOM at the file start only once; do not concatenate independently BOM-prefixed fragments.
- Encoding and CRLF/LF are separate concerns. Preserve project line endings and avoid unrelated whole-file rewrites when signatures, hashes, or exact patches matter.
- Verify BOMs from bytes, not appearance. `[IO.File]::ReadAllBytes($path)` can inspect small files; UTF-8 without BOM must not start with `EF BB BF`. Use a stream for a few header bytes of large files.

## 5. JSON, CSV, and object pipelines

```powershell
$rows = @(Get-ChildItem -LiteralPath 'C:\data' -File |
    Select-Object Name, Length, FullName)
ConvertTo-Json -InputObject $rows -Depth 5 -Compress
```

- `ConvertTo-Json` defaults to depth 2. Set an appropriate depth for structured data. Do not serialize entire system objects that may be huge, cyclic, or sensitive.
- `-InputObject $rows` preserves collection shape for zero or one item. PowerShell 7.x also supports `-AsArray` and `ConvertFrom-Json -AsHashtable`; verify their resulting shape against the consumer contract.
- `Format-Table`/`Format-List` produce formatting instructions, not the original data. Use them only at the final human-display stage, never before JSON/CSV serialization.
- For CSV, specify `-NoTypeInformation -Encoding utf8NoBOM`, or write `ConvertTo-Csv` strings using the agreed encoding.
- Keep machine-readable stdout data-only. Use appropriate diagnostic streams, not progress text mixed with JSON. `2>&1` can invalidate a pure JSON output protocol.

## 6. UTF-8 with Python and Node

Python 3.7+ code through stdin, for a fresh-process invocation:

```powershell
$utf8 = [Text.UTF8Encoding]::new($false)
$OutputEncoding = $utf8
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$previous = $env:PYTHONIOENCODING
try {
    $env:PYTHONIOENCODING = 'utf-8'
    @'
print('\u4e2d\u6587 and UTF-8')
'@ | python.exe -X utf8 -
    $code = $LASTEXITCODE
    if ($code -ne 0) { throw "Python failed: $code" }
}
finally {
    $env:PYTHONIOENCODING = $previous
}
```

Here stdin carries **source code**. By the time that code executes, the same input has been consumed; do not expect `sys.stdin.read()` to obtain a second independent data payload. For application data, execute a `.py` file and pipe data, or pass a file path/arguments. In shared sessions, also restore Console encoding and `$OutputEncoding`, not just the Python environment variable.

- `-X utf8`/`PYTHONUTF8=1` enables Python UTF-8 mode. `PYTHONIOENCODING=utf-8` primarily overrides standard streams. Configure before Python starts; neither changes the parent's emitted bytes automatically.
- `PYTHONIOENCODING` has Windows interactive-console exceptions. Redirected pipes/files are the usual agent boundary. `-I`/`-E` can ignore environment configuration; verify actual arguments.
- `python -u` changes buffering, not encoding. Specify `encoding='utf-8'` for Python file I/O too.
- `node.exe -` also accepts a code here-string. Use `fs.readFileSync(path, 'utf8')` for text and Buffer for bytes. Whether `--input-type=module` is required depends on imports and the Node version.
- Put complex/quote-heavy code in files rather than repeatedly guessing nested `python -c` or `node -e` escaping.

## 7. Keep binary data out of ordinary text pipelines

- Prefer native output-file options or byte-stream APIs. Download with `Invoke-WebRequest -OutFile` or `curl.exe --output`, not `... | Out-File archive.zip`.
- In 7.4+, **direct native stdout-to-file redirection** and direct native-to-native pipelines can preserve bytes. Inserting text cmdlets, capturing strings, or merging stderr removes that guarantee.
- Official documentation specifies string treatment when native stderr and stdout are combined with `2>&1`. Do not use the merged stream for binary archives.
- Use `Get-Content -AsByteStream -Raw` or absolute-path `.NET ReadAllBytes/WriteAllBytes`. Do not use an older engine's `-Encoding Byte` syntax.
- Verify size, checksum, or file format. Exit code 0 alone does not prove binary integrity.

