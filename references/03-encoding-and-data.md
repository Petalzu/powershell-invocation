# Encoding and data

PowerShell 7 uses UTF-8 without BOM for ordinary text-file defaults. **Do not add encoding initialization to every invocation.** Configure the boundary whose producer/consumer contract requires it, or diagnose the first point where text changes.

## Find the boundary

| Boundary | Relevant control |
|---|---|
| Script or file bytes -> strings | Actual encoding, BOM, `Get-Content -Encoding` |
| PowerShell text -> native stdin | `$OutputEncoding` and the child's decoder |
| Native stdout/stderr -> strings | Producer encoding and host/Console or Process decoder |
| Process output -> agent display | Tool decoding, then font/rendering |
| Native binary output -> file | Native output-file option or a byte-preserving route |

An existing UTF-16/ANSI file is valid data; preserve its encoding, BOM, and line endings unless conversion is requested. Console settings do not change file encoding. Already-decoded `?` or U+FFFD may mean information was lost: reread original bytes rather than repeatedly transcoding damaged text.

## Apply only the needed setting

| Observed need | Scoped action |
|---|---|
| Python redirected streams must use UTF-8 | Start with `python.exe -X utf8 ...`, or set `$env:PYTHONIOENCODING = 'utf-8'` before startup |
| Non-ASCII PowerShell text sent to UTF-8 native stdin, with a mismatched parent | `$OutputEncoding = [Text.UTF8Encoding]::new($false)` in the same invocation |
| UTF-8 native output decoded using a different Console encoding | Set `[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)` when that is the host's decoding boundary |
| A program reads input using the console code page | Set `[Console]::InputEncoding` to the agreed encoding only when relevant |
| Program emits GBK/CP936 | Prefer its UTF-8 option; otherwise decode stdout and stderr as CP936 before emitting Unicode |

Do not assume `[Console]::OutputEncoding` forces every child to emit UTF-8. For CP936 capture, .NET `ProcessStartInfo.StandardOutputEncoding` and `StandardErrorEncoding` can use `[Text.Encoding]::GetEncoding(936)`; drain both streams concurrently and preserve the exit code. See [process handling](./04-errors-output-and-processes.md#processes-and-services) and the [self-test](../scripts/Test-PowerShellInvocation.ps1).

Console setters can fail in hosts without a console. Use explicit file or Process encoding instead of swallowing that failure. Restore settings actually changed in persistent shared sessions; a child scope does not undo Console/environment changes. `chcp 65001` changes a console code page, not every file, child, or tool decoder. Do not make permanent locale/profile changes as a blanket repair.

### Python and Node

For a small Unicode Python output probe:

```powershell
@'
print('\u4e2d\u6587')
'@ | python.exe -X utf8 -
```

The source above is ASCII and generates non-ASCII output. When investigating stdin corruption, also test actual non-ASCII input rather than only escapes. Check both stdout and stderr. `PYTHONIOENCODING` can override UTF-8 mode for streams, so inspect an existing setting if `-X utf8` alone does not help.

- Python UTF-8 mode requires 3.7+. `-u` controls buffering, not encoding; file I/O should specify its intended encoding separately.
- Environment overrides must be set before startup; `-I` / `-E` may ignore them, and Windows interactive console behavior differs from redirected streams.
- With `python -` / `node -`, stdin carries code; it cannot also be an independent application data stream. Use a script file for that case or for substantial code.
- In Node, use a UTF-8 text read or Buffer according to the data; select module mode only when required by imports.

## Files and structured data

Use editing tools for authored source/configuration/documents. Shell I/O is appropriate for data generation, transformation, and exact-byte checks.

Read whole JSON as one string:

```powershell
Get-Content -LiteralPath '.\config[1].json' -Raw -Encoding UTF8 -ErrorAction Stop |
    ConvertFrom-Json -ErrorAction Stop
```

For generated data with an agreed UTF-8/no-BOM format:

```powershell
$json = ConvertTo-Json -InputObject $rows -Depth 5
Set-Content -LiteralPath '.\result.json' -Value $json -Encoding utf8NoBOM -NoNewline -ErrorAction Stop
```

- In 7.x, `UTF8` means no BOM; `utf8BOM` explicitly adds one. `-Encoding 936` identifies that code page; `ansi` requires 7.4+. Do not guess an encoding from appearance.
- `Set-Content` overwrites; `-NoNewline` suppresses an added newline. For exact bytes, use absolute-path `[IO.File]::WriteAllText($path, $text, $encoding)` or byte APIs; the parent must exist.
- Append using the existing encoding. `>>` / `Out-File -Append` do not automatically match it; BOM detection cannot reliably identify every BOM-less legacy format. Never concatenate BOM-prefixed fragments.
- Preserve CRLF/LF independently of encoding. Inspect bytes when BOM, hashes, or exact output matters; read only a header for large files.
- Build `$rows` as an array and use `ConvertTo-Json -InputObject $rows` to preserve zero/one-item array shape. Choose a sufficient depth; the default is 2.
- Select needed properties before serialization. `Format-Table` / `Format-List` produce display instructions, not data. Keep stdout pure when consumed as JSON; merged diagnostics invalidate that protocol.
- For CSV, use `Export-Csv -NoTypeInformation -Encoding utf8NoBOM` with the intended columns and destination.

## Binary data

Prefer the native program's output-file option, `Invoke-WebRequest -OutFile`, or .NET byte APIs. Use `Get-Content -AsByteStream -Raw` for bytes, not text decoding or the old `-Encoding Byte` form.

PowerShell **7.4+** preserves bytes for direct native stdout-to-file redirection and direct native-to-native pipelines. Inserting text cmdlets, capturing strings, or merging stderr with `2>&1` removes that guarantee. Earlier 7.x needs a native output-file option or explicit byte API. Verify size/hash/format when integrity matters.

Sources: [character encoding](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_character_encoding?view=powershell-7.5), [redirection](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_redirection?view=powershell-7.5), [Python streams](https://docs.python.org/3/using/cmdline.html#envvar-PYTHONIOENCODING), and the [version record](./07-official-sources.md).
