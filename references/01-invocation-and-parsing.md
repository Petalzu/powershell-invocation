# Invocation and Parsing

Use **PowerShell 7.x / Core only**. Never invoke an older engine or automatically fall back. Unless labeled otherwise, examples run in an already verified PowerShell 7.x outer shell. Replace placeholder paths with confirmed real paths, and use a verified `pwsh.exe` for every child PowerShell process.

Official references: [about_Parsing](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_parsing?view=powershell-7.5), [about_Quoting_Rules](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_quoting_rules?view=powershell-7.5), [about_Operators](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_operators?view=powershell-7.5), and [about_Splatting](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_splatting?view=powershell-7.5).

## 1. Identify each parsing layer

A typical boundary is `tool JSON -> PowerShell source -> native argv -> child-language source`. Escape each layer exactly once. Escaping for one layer does not automatically satisfy another layer's rules.

### JSON escaping is not PowerShell escaping

A manually written JSON tool argument needs escaped backslashes:

```json
{
  "command": "Get-Content -LiteralPath 'C:\\Documents\\config[1].json' -Raw -Encoding UTF8"
}
```

The resulting PowerShell source must be:

```powershell
Get-Content -LiteralPath 'C:\Documents\config[1].json' -Raw -Encoding UTF8
```

Let an SDK serialize structured arguments when available; do not repeatedly apply `json.dumps`. Do not HTML/XML-escape ordinary commands into `&amp;` or `&quot;`. Encoded commands reduce some quoting layers but do not make untrusted code safe.

### Minimize nesting

When the tool already runs 7.x, invoke commands directly. Avoid unnecessary cmd/interpreter wrappers, and never use an older PowerShell as an intermediary. Put complex code in a controlled `.ps1`, `.py`, or `.js` file and pass data as arguments; this is easier to verify than nested `-c` strings.

## 2. Strings and special characters

| Form | Rule |
|---|---|
| `'fixed text'` | Verbatim: no `$name` or backtick expansion; represent an internal apostrophe as `''` |
| `"text $name"` | Expands variables and `$()`; use only when interpolation is needed |
| `"${name}:suffix"` | Braces separate a variable from a following colon and prevent scope interpretation |
| `"$($obj.Name)"` | Member access, indexing, and expressions require a subexpression |
| `\` | Not a PowerShell escape character; `'C:\temp'` needs no doubled backslashes |
| Backtick | PowerShell escape character, not Bash backslash or cmd caret |
| ASCII `'` and `"` | Use straight quotes, not typographic quotes or full-width punctuation |
| `& ; | ( ) { } $` and similar characters | May have syntax meaning; keep data in strings/variables rather than inserting it back into source |

```powershell
$label = 'file'
$literal = 'C:\O''Brien\Documents & backup\config[1].json'
"${label}: $literal"
```

An `&` or `;` inside a variable is not reinterpreted as syntax during direct argument passing. Passing that value to `Invoke-Expression`, `cmd /c`, or `sh -c` introduces another interpreter and may turn it into code. Argument arrays remain necessary, but also validate the target application's option, expression, and script semantics.

## 3. Direct calls, `&`, and dot-sourcing

```powershell
Get-ChildItem -LiteralPath 'C:\Documents' -File
& 'C:\Program Files\Example\tool.exe' '--version'
& '.\scripts\build.ps1' -Configuration Release
```

- A quoted path by itself produces a string. Add `&` to execute the quoted command path.
- Give `&` a command name/path or ScriptBlock, not an entire command line. Incorrect: `& 'git --version'`. Correct: `& 'git.exe' '--version'`.
- Normal script invocation uses a separate script/child scope. `& { ... }` can limit preference-variable changes, but **does not restore** process environment variables, working directories, or Console encoding.
- Dot-sourcing `. '.\definitions.ps1'` loads variables, functions, and aliases into the current scope. Do not dot-source a build script merely to make it run.
- Never use `Invoke-Expression`/`iex` to fix quoting or path failures. Resolve dynamic command names from trusted sources or allowlists and pass input as arguments.

### Separate arguments and use splatting

```powershell
$exe = (Get-Command -Name git.exe -CommandType Application -ErrorAction Stop).Source
$nativeArgs = @('--no-pager', '-C', 'C:\repo with spaces', 'status', '--short')
& $exe @nativeArgs
$code = $LASTEXITCODE
if ($code -ne 0) { throw "git failed: $code" }
```

Use hashtables for named PowerShell parameters and ordered string arrays for native arguments. Do not combine all argv values into a single array element.

```powershell
$options = @{
    LiteralPath = 'C:\Documents\config[1].json'
    Raw = $true
    Encoding = 'UTF8'
    ErrorAction = 'Stop'
}
Get-Content @options
```

Do not reuse automatic variables such as `$args`, `$input`, `$PID`, or `$Host` for custom state. Names are case-insensitive, so `$pid` also refers to read-only `$PID`.

## 4. Child PowerShell entry points

Official reference: [about_Pwsh](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_pwsh?view=powershell-7.5). From verified 7.x, prefer the `pwsh.exe` in the same `$PSHOME`. From Python, Node, or cmd, use a previously verified absolute 7.x executable path rather than a file association or unspecified default shell.

### `-File`: the reliable default

```powershell
if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -ne 7) {
    throw 'PowerShell 7.x (Core) is required; no fallback is allowed.'
}
$engine = Join-Path -Path $PSHOME -ChildPath 'pwsh.exe'
$script = 'C:\tools\task.ps1'
& $engine -NoLogo -NoProfile -NonInteractive -File $script -InputPath 'C:\Documents\input[1].txt'
$code = $LASTEXITCODE
if ($code -ne 0) { throw "task.ps1 failed: $code" }
```

- Put engine options before `-File`; everything after it is the script path and script arguments.
- `-NoProfile` avoids profile aliases, output, and automatic directory changes. It does not remove inherited environment variables or all system configuration.
- `-NonInteractive` rejects PowerShell interaction, but **does not guarantee native children will not prompt**. Use their own noninteractive options.
- Complex parameters such as `[string[]]` do not necessarily retain their object shape across a native CLI boundary. Use a JSON data file or a defined stdin protocol and decode it inside the script.
- PowerShell 7.x supports explicit switch values such as `-All:$false`. Still check the outer caller's argument rules, and do not generalize switch behavior to arbitrary `[bool]` string binding.
- Explicitly handle/propagate a build exit code in the script entry point. A normally completed `-File` process returning 0 does not prove every intermediate command succeeded.
- Do not default to `-NoExit`, `-ExecutionPolicy Bypass`, or `-Verb RunAs`.

### `-Command`: short, fixed, auditable code only

```powershell
$engine = Join-Path -Path $PSHOME -ChildPath 'pwsh.exe'
& $engine -NoLogo -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()'
if ($LASTEXITCODE -ne 0) { throw 'Version query failed' }
```

Here the outer shell is PowerShell, so single quotes prevent premature parent expansion. In **cmd**, single quotes do not provide that protection. Replace the example path with the verified engine path:

```cmd
"C:\Program Files\PowerShell\7\pwsh.exe" -NoLogo -NoProfile -NonInteractive -Command "$PSVersionTable.PSVersion.ToString()"
```

- The command string and following text are interpreted as PowerShell source. Never interpolate untrusted data into it.
- A typed ScriptBlock parameter is recognized only when the caller can supply that type, such as another PowerShell host. From cmd, `"{ Get-Date }"` may display a ScriptBlock instead of executing its body.
- A PowerShell caller may receive CLIXML/deserialized results. For stable machine interfaces, explicitly emit JSON and keep diagnostics out of the data stream.
- `-Command` may normalize a nonzero final result to 1. Preserve a specific native code by saving it immediately and explicitly executing `exit $code`.

### `-EncodedCommand`: quoting transport, not encryption

```powershell
$engine = Join-Path -Path $PSHOME -ChildPath 'pwsh.exe'
$source = 'Write-Output ([char]0x4E2D + [string][char]0x6587)'
$payload = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($source))
& $engine -NoLogo -NoProfile -NonInteractive -EncodedCommand $payload
if ($LASTEXITCODE -ne 0) { throw 'Encoded command failed' }
```

`[Text.Encoding]::Unicode` means **UTF-16LE** here; do not substitute UTF-8. Base64 provides neither confidentiality nor trust. Keep the original source auditable and secrets out of command lines/logs. Prefer script files rather than encoding every command.

### stdin: `-Command -` / `-File -`

```powershell
$engine = Join-Path -Path $PSHOME -ChildPath 'pwsh.exe'
@'
$ErrorActionPreference = 'Stop'
Write-Output 'stdin command'
exit 0
'@ | & $engine -NoLogo -NoProfile -NonInteractive -Command -
$code = $LASTEXITCODE
if ($code -ne 0) { throw "stdin command failed: $code" }
```

The documented stdin modes parse and execute one statement at a time. A malformed statement may be skipped, and a final successful command can mask an earlier failure. Multiline blocks, blank lines, and overall exit semantics are harder to audit. Use a real `.ps1` for functions, complex `try/finally`, or multiple control-flow blocks; stdin is not fully equivalent to executing a script file. Agree on stdin encoding at both ends.

`-CommandWithArgs` became generally available in 7.5 after being experimental in 7.4. It separates command source from `$args`; use it only when supported, not as a universal 7.x template.

## 5. Here-strings and multiline code

```powershell
$code = @'
import sys
print(sys.argv[1])
'@
$code | python.exe -X utf8 - 'a path with spaces'
$codeExit = $LASTEXITCODE
if ($codeExit -ne 0) { throw "Python failed: $codeExit" }
```

- Follow `@'` or `@"` immediately with a newline. Start the closing `'@` or `"@` marker in column 1; a pipeline may follow the closing marker.
- Prefer single-quoted here-strings so `$name`, `$(...)`, backslashes, and quotes belong to the child language, not PowerShell interpolation.
- For non-ASCII payloads, configure `$OutputEncoding` and the other relevant boundaries as described in the encoding reference.
- Do not use Bash heredocs such as `python - <<'PY'` or `cat <<EOF`. PowerShell does not implement that syntax, and `<` is not Bash-style input redirection.
- Whitespace after a trailing backtick breaks continuation. Prefer parameter hashtables, arrays, parentheses, or pipeline continuation. Do not paste shell prompts or Markdown fences into commands.

## 6. Native arguments across 7.x versions and modes

PowerShell 7.3 introduced `$PSNativeCommandArgumentPassing`: `Legacy`, `Standard`, and `Windows`. Windows defaults to `Windows`; other platforms default to `Standard`. A host can change the value.

- `Standard`/`Windows` preserve many embedded-quote and empty-string cases. PowerShell 7.0-7.2 and `Legacy` mode do not provide identical behavior. `Legacy` is an argument-passing mode inside 7.x, not permission to launch an older engine.
- `Windows` uses Legacy argument passing for certain older applications and `.bat`/`.cmd`/script extensions. Lists differ by version; consult the target-version documentation rather than assuming all `.exe` files use Standard rules.
- Adding more quotes is not a general repair. First verify argument count/order/values with an argv probe: empty strings, embedded quotes, spaces, Unicode, and trailing backslashes. Earlier 7.x versions can use data files, stdin, or a supported response-file protocol.
- Backslash is not a PowerShell escape character, but some Windows argv parsers treat backslashes before quotes specially. Avoid manually constructing command lines, especially paths containing spaces and ending in `\`; do not indiscriminately double every slash.
- Modern .NET `ProcessStartInfo.ArgumentList` escapes individually added values. It is not `Start-Process -ArgumentList`, and it does not remove the target interpreter's syntax or option-injection concerns.

### `--` and `--%`

- `--` ends PowerShell cmdlet parameter parsing; expressions such as `$value` still follow applicable expansion rules. Native support and semantics belong to the target program; this is not a universal injection defense.
- `--%` stops PowerShell parsing for Windows native commands until a newline or pipeline. It does not support dynamic `$var`/`$(...)`, still expands `%ENV%`, and does not provide generic `%%` escaping. A following `>` is passed as an argument, not PowerShell redirection.
- Do not use `--%` to fix cmdlet paths, dynamic user input, or cross-platform calls. Reserve it for static, specifically verified Windows command lines.

## 7. `cmd.exe` and batch-file boundaries

Official reference: [cmd](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/cmd). Names such as `dir`, `set`, `where`, and `echo` may be PowerShell aliases rather than cmd commands. Specify native executable extensions when needed, such as `where.exe` and `curl.exe`.

```powershell
& $env:ComSpec /d /c 'call "C:\Build Tools\setup.bat" >nul && cd /d "C:\repo" && tool.exe --version'
$code = $LASTEXITCODE
if ($code -ne 0) { throw "cmd toolchain failed: $code" }
```

- `/d` disables cmd AutoRun and `/c` exits after execution. Do not use `/k` and leave an unwanted interpreter running.
- Batch setup and its dependent command must run in the **same cmd process**. Running setup.bat once and cl/link in a later PowerShell call does not preserve PATH/LIB/INCLUDE.
- `&&`, `%VAR%`, `cd /d`, and `>nul` in the quoted payload are cmd syntax, not interchangeable PowerShell syntax.
- Verify cmd quoting separately. Do not interpolate untrusted input into `/c`, even if PowerShell originally held it in single quotes. Parentheses, `&`, `%`, and `!` can trigger another interpretation.
- npm and similar entry points may be `.ps1`/`.cmd` shims. For execution-policy failures, inspect `Get-Command -All npm`, verify the actual entry point, and select a trusted appropriate executable; do not lower policy without diagnosis.

## 8. Launch PowerShell from Python, Node, or .NET

Specify the verified 7.x engine, argv array, working directory, stdin protocol or closure, timeout, encoding, and result checks. Arrays remove one caller-shell parsing layer, but `-Command` remains PowerShell code. Pass user data through script parameters or JSON files instead of injecting it into code.

### Python `subprocess.run`, not a `shell=True` command string

```python
import subprocess

source = (
    '[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false); '
    'Write-Output ([char]0x4E2D + [string][char]0x6587)'
)
result = subprocess.run(
    [r'C:\Program Files\PowerShell\7\pwsh.exe',
     '-NoLogo', '-NoProfile', '-NonInteractive', '-Command', source],
    shell=False,
    cwd=r'C:\tools',
    stdin=subprocess.DEVNULL,
    capture_output=True,
    text=True,
    encoding='utf-8',
    errors='strict',
    timeout=30,
    check=True,
)
print(result.stdout, end='')
```

Paths are placeholders and require verification. `encoding='utf-8'` controls Python-side decoding; the child must actually emit UTF-8. For potentially huge output, use log files or streaming instead of unbounded `capture_output`.

On timeout, `subprocess.run` kills and waits for the **direct child**; it does not guarantee cleanup of every Windows descendant. `Popen.communicate(timeout=...)` does not itself kill the child on timeout; the caller must perform the required kill/wait. These are not the same semantics as PowerShell `Wait-Process`. When customizing `env`, inherit the existing environment and change only necessary keys.

### Node `spawnSync` or asynchronous `spawn`

```javascript
const { spawnSync } = require('node:child_process');
const result = spawnSync(
  'C:\\Program Files\\PowerShell\\7\\pwsh.exe',
  ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command', 'Write-Output 42'],
  { shell: false, cwd: 'C:\\tools', encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'], timeout: 30000, maxBuffer: 1024 * 1024 }
);
if (result.error) throw result.error;
if (result.status !== 0) throw new Error(`PowerShell failed: ${result.status}`);
process.stdout.write(result.stdout);
```

- `spawn`/`execFile` avoid a shell by default and are preferable to concatenating dynamic values into `exec`. Windows `.bat`/`.cmd` files are not ordinary executables for every `execFile` use; a controlled cmd boundary may be necessary.
- With asynchronous `spawn`, consume stdout/stderr and handle `error` for startup failures and `close` for completion after streams close. An `exit` event alone does not prove all output has been collected.
- Inherit `process.env` when overriding environment values. Avoid duplicate Windows keys such as both `PATH` and `Path`, and never log the entire environment.
- `timeout`, AbortSignal, and `.kill()` provide platform-dependent descendant-process behavior. Follow tool permissions, and do not bypass the agent lifecycle with detached/unref tricks.

### .NET invocation

Use modern .NET `ProcessStartInfo.FileName` and `ArgumentList.Add()`, `UseShellExecute = false`, and explicit `WorkingDirectory`, `StandardOutputEncoding`, and `StandardErrorEncoding` when required. Choose either `.Arguments` or `.ArgumentList`, not both.

Drain redirected stdout/stderr concurrently to avoid buffering deadlocks. A hosted SDK/runspace must also be verified as 7.x/Core; never load an older-engine compatibility session for module support. Hosting a runspace is a separate architecture, not the external-process CLI, and does not justify introducing an SDK for a single command.

Official references: [Python subprocess](https://docs.python.org/3/library/subprocess.html), [Node child_process](https://nodejs.org/api/child_process.html), and [.NET ArgumentList](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.processstartinfo.argumentlist?view=net-9.0).

