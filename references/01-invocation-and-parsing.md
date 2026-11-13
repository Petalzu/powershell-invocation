# Invocation and parsing

Use this reference for quoting or process-boundary problems. Examples assume a verified PowerShell 7.x / Core caller; the [entrypoint](../SKILL.md) covers ordinary calls.

## Arguments without extra parsing

Run known names directly. A quoted path needs `&`; a bare quoted path only produces a string.

```powershell
& 'C:\Program Files\Example\tool.exe' --version
```

Use arrays for dynamically assembled native arguments and hashtables for complex named cmdlet parameters. Simple fixed calls do not need either.

```powershell
$nativeArgs = @('--no-pager', '-C', $repoPath, 'status', '--short')
git.exe @nativeArgs
```

- Keep the executable separate from its arguments. `& 'git --version'` tries to find a command with that entire name.
- A variable containing `&`, `;`, or `$()` stays data during direct argument passing. `Invoke-Expression`, `cmd /c`, or `sh -c` may interpret it again as code. Validate the target's own option/expression semantics too.
- Invoke scripts with `& '.\scripts\task.ps1' -Name $name`. Dot-source only when definitions must enter the caller's scope.
- `& { ... }` scopes PowerShell variables; it does not restore CWD, environment variables, or Console settings.
- Use task-specific variable names, not `$args`, `$input`, `$PID`, `$Host`, or `$HOME`; names are case-insensitive.

## Quoting by layer

| Form | Meaning |
|---|---|
| `'fixed text'` | Literal; represent an apostrophe as `''` |
| `"text $name"` | Expands variables and `$()`; use intentionally |
| `"${name}:suffix"` | Braces separate the variable from a colon |
| `"$($item.Name)"` | Member access inside an interpolated string |
| `'C:\temp'` | Backslash is literal, not a PowerShell escape |
| Backtick | PowerShell escape character; prefer natural continuation over trailing backticks |

Use straight quotes. JSON serialization and PowerShell quoting solve different problems. For example, a raw JSON string uses doubled backslashes:

```json
{"command": "Get-Content -LiteralPath 'C:\\data\\config[1].json' -Raw"}
```

After JSON decoding, PowerShell receives single backslashes. Let the SDK serialize tool arguments; do not manually re-escape or HTML-escape them. JSON serialization does not make interpolated shell data safe.

For a small Python stdin probe:

```powershell
@'
import sys
print(sys.version_info.major)
'@ | python.exe -X utf8 -
```

Put a newline immediately after `@'`; place the closing `'@` at column 1. Single-quoted here-strings keep child-language source literal. PowerShell has no Bash `<<EOF` heredoc or `<` input redirection. For substantial code, create a file with an editing tool. When stdin carries source, application data needs arguments, a separate file, or a different protocol. See [encoding](./03-encoding-and-data.md) only when a text boundary needs configuration.

## Child PowerShell only when needed

In an existing 7.x shell, direct script invocation is sufficient unless isolation or a separate process is required. For a clean child, use the verified engine from `$PSHOME`:

```powershell
& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -NonInteractive -File '.\scripts\task.ps1' -InputPath $inputPath
```

- Engine options precede `-File`; script arguments follow the script path. Do not rely on file associations or an unspecified runner default.
- `-NoProfile` prevents profile loading, not environment inheritance. `-NonInteractive` prevents PowerShell prompts, not every native program's prompts.
- Pass complex collections through a defined JSON/file/stdin protocol; a native CLI boundary does not preserve PowerShell object types. PowerShell 7 supports explicit switch values such as `-All:$false`, but arbitrary boolean strings still depend on parameter binding.
- Keep `-Command` for short fixed source; PowerShell single quotes protect against parent expansion, but cmd single quotes do not. Data belongs in script parameters.
- Typed ScriptBlocks work only with callers that can supply that type. From other shells, a quoted `{ ... }` may display a ScriptBlock instead of running it.
- `-Command -` / `-File -` parse stdin statement by statement; a malformed statement can be skipped. Prefer a script file for functions or control flow.
- `-EncodedCommand` requires Base64 of **UTF-16LE** source. Use only for a demonstrated quoting constraint; it expands the payload and provides no confidentiality. Do not use it to hide long commands.
- `-CommandWithArgs` is generally available in 7.5, experimental in 7.4. Check support before using it.
- Do not add `-ExecutionPolicy Bypass`, `-Verb RunAs`, or `-NoExit` by default. See [exit propagation](./04-errors-output-and-processes.md#native-exit-codes) when a specific native code must cross the child boundary.

## Native argv differences

PowerShell 7.3+ has `$PSNativeCommandArgumentPassing`: `Windows`, `Standard`, or `Legacy`. Windows normally uses `Windows`, which falls back to Legacy parsing for some applications and batch/script entry points.

- Empty strings, embedded quotes, and trailing backslashes can differ in 7.0–7.2 or Legacy mode. Inspect the actual mode only when these cases matter; do not globally change it for ordinary arguments.
- Diagnose with the [argv probe](../scripts/argv_probe.py), using synthetic arguments and comparing count, order, and values. Avoid guessing additional quotes.
- For unsupported cases, use the program's file/stdin/response-file protocol or modern .NET `ProcessStartInfo.ArgumentList`. That API preserves individual values; `Start-Process -ArgumentList` joins them into one string.
- Native applications decide what `--` means. PowerShell `--%` is only for verified static Windows command lines: it prevents normal variable expansion, still expands `%ENV%`, and passes subsequent redirection symbols as arguments until a pipeline or newline.

## Batch setup and other callers

Batch environment setup and its dependent command must share one cmd process:

```powershell
& $env:ComSpec /d /c 'call "C:\Build Tools\setup.bat" >nul && cd /d "C:\repo" && tool.exe --version'
```

Use verified paths. `/d` disables AutoRun; `/c` exits after execution. The quoted payload uses cmd rules, so never concatenate untrusted values into it. Child environment changes do not flow back to PowerShell. Keep destructive filesystem operations in PowerShell end-to-end.

From Python, Node, or .NET, pass a verified absolute 7.x executable and individual arguments with shell parsing disabled:

| Caller | Relevant boundary |
|---|---|
| Python `subprocess.run(..., shell=False)` | Specify CWD, encoding, timeout, and `check=True` when nonzero means failure. `run` kills/waits for its direct child on timeout; `Popen.communicate(timeout=...)` does not. Neither guarantees descendant cleanup. |
| Node `spawn` / `execFile` | Consume both streams; handle startup errors and `close`. Batch files may require a controlled cmd boundary. Inherit environment values without duplicate Windows `PATH` / `Path` keys. |
| .NET `ProcessStartInfo` | Use `FileName` plus `ArgumentList.Add()`, not prequoted values or both `Arguments` and `ArgumentList`. See [process handling](./04-errors-output-and-processes.md#processes-and-services). |

Emit data-only JSON for machine interfaces rather than relying on CLIXML or display formatting. Use files/streaming for large output. Do not introduce a custom runner when the existing tool suffices.

Sources: [parsing](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_parsing?view=powershell-7.5), [quoting](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_quoting_rules?view=powershell-7.5), [pwsh](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_pwsh?view=powershell-7.5), and the [version/source record](./07-official-sources.md).
