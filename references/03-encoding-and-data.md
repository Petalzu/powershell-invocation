# Encoding and data

## Text changed: find the first bad conversion

PowerShell 7 normally writes text files as UTF-8 without BOM. That says nothing about what a child emits or how a tool decodes it. Compare original bytes with decoded text at the failing boundary. If a decoder already replaced characters with `?` or U+FFFD, start again from the bytes.

| Where it changes | What to change |
|---|---|
| File to string, or while appending | Read/write the file's actual encoding (`Get-Content -Encoding 936` for known CP936). Preserve BOM and newlines independently; `>>` need not match the file's encoding. |
| PowerShell text to native stdin | Match `$OutputEncoding` to the child's decoder in that invocation. Test actual non-ASCII input, not just source containing Unicode escapes. |
| Native stdout/stderr to strings | Prefer the child's documented UTF-8 option. For a known legacy producer, set both `ProcessStartInfo.StandardOutputEncoding` and `.StandardErrorEncoding` before launch (e.g. `[Text.Encoding]::GetEncoding(936)`). Drain both streams concurrently. |
| Correct file but garbled display | Check the tool decoder, then the font. `[Console]::OutputEncoding` helps only where that console is the decoder; `chcp` does not convert files. Restore changed settings in shared sessions. |

For redirected Python 3.7+ streams, `-X utf8` enables UTF-8 mode; an existing `PYTHONIOENCODING` can override stream encoding. `-u` changes buffering, not encoding.

## JSON is invalid or its shape changes

Read one JSON document as one string:

```powershell
Get-Content -LiteralPath '.\config[1].json' -Raw -ErrorAction Stop |
    ConvertFrom-Json -ErrorAction Stop
```

If the consumer expects an array even for zero or one result, collect the original objects first and pass the array as **one input**. Piping it into `ConvertTo-Json` enumerates it. Set depth to the schema, and keep stdout free of formatting, progress messages and merged diagnostics.

```powershell
$rows = @(Get-ChildItem -LiteralPath $dir -File -ErrorAction Stop | Select-Object Name,Length)
ConvertTo-Json -InputObject $rows -Depth 3 -Compress
```

For a file, choose the consumer's encoding; `Set-Content -NoNewline` avoids an extra trailing newline. For CSV, select columns before `Export-Csv`, not after `Format-Table`.

## Binary data

Use the program's output-file option or a byte API (e.g. `[IO.File]::ReadAllBytes($absolutePath)`). In **7.4+**, direct native stdout redirection to a file or piping directly to another native program preserves bytes. A text cmdlet, string capture, or `2>&1` breaks that guarantee. On earlier 7.x, use a byte-safe file interface. Verify size or hash, not the text preview.
