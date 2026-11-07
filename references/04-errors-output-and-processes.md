# Errors, Output, and Process Lifecycle

Official references: [about_Try_Catch_Finally](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_try_catch_finally?view=powershell-7.5), [about_Automatic_Variables](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables?view=powershell-7.5), [about_Preference_Variables](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables?view=powershell-7.5), [about_Redirection](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_redirection?view=powershell-7.5), [Start-Process](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process?view=powershell-7.5), and [about_Jobs](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_jobs?view=powershell-7.5).

## 1. Handle two error protocols separately

### PowerShell cmdlets and functions

- A nonterminating error normally writes to the error stream and continues. A plain `try/catch` may not catch it. Use `-ErrorAction Stop` for required operations or set `$ErrorActionPreference = 'Stop'` in a controlled scope.
- `catch` handles terminating errors. Preserve context and rethrow when recovery is impossible. Do not use empty catches, global `Ignore`, or success messages for failures.
- Use `finally` to restore directories/environment and release streams, temporary files, and one-shot processes. Forced host termination/crashes can prevent cleanup, so constrain resource ownership too.
- `Set-StrictMode` finds undefined variables and related mistakes but may change third-party behavior. Enable it only within scripts you own, not globally in shared sessions.
- `$Error[0]` can be stale. Use `$_` inside catch for the current ErrorRecord instead of dumping error history.

```powershell
try {
    $content = Get-Content -LiteralPath 'C:\data\config.json' -Raw -Encoding UTF8 -ErrorAction Stop
    $config = $content | ConvertFrom-Json -ErrorAction Stop
}
catch {
    Write-Warning ("Reading config failed: {0}" -f $_.Exception.Message)
    throw
}
```

### Native executables

```powershell
& {
    $ErrorActionPreference = 'Stop'
    if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
        $PSNativeCommandUseErrorActionPreference = $false
    }
    & git.exe --no-pager --version
    $nativeExit = $LASTEXITCODE
    if ($nativeExit -ne 0) { throw "git failed: $nativeExit" }
}
```

This local template chooses **manual exit-code checking**, avoiding an exception before the code can be saved when the host enables native error handling. Feature detection distinguishes 7.x minor versions; it does not permit an older engine.

- `$LASTEXITCODE` belongs to the most recent native program/relevant script, not every cmdlet. A cmdlet failure may leave it unchanged; do not interpret stale values.
- `$?` is the status of the most recent command/pipeline and can be overwritten by a later successful command. Save it immediately when needed; prefer explicit native-code and exception handling.
- `$ErrorActionPreference = 'Stop'` alone does not normally make native nonzero exits catchable. PowerShell 7.4+ provides stable `$PSNativeCommandUseErrorActionPreference`, default `$false`. When enabled, nonzero exits follow ErrorAction policy; check earlier 7.x/experimental availability separately.
- Native exception mode may be inappropriate for programs using nonzero informational states. Disable it locally and interpret those programs' actual codes.
- Nonempty stderr may be progress/warnings even with exit 0. Empty stderr does not prove success either.
- `-ErrorAction Stop` is not a universal native option. Do not append it to `python.exe` or `git.exe` and expect PowerShell to intercept errors.

### Interpret each program's exit codes

| Program/scenario | Handling |
|---|---|
| Most compilers and test runners | 0 succeeds; other values usually fail. Check the program contract |
| `rg` | 0 means a match, 1 no match, 2 error. `--quiet` may return 0 after a match despite another error; no match is not infrastructure failure |
| `git diff --exit-code` | 0 no differences, 1 differences, other values errors. Whether differences fail the task is a requirement decision |
| robocopy | 0-7 usually do not indicate copy failure; **8 or higher** means at least one failure. Do not use `> 8` |
| Multiple native commands in a pipeline | `$LASTEXITCODE` generally describes the last native command, not a Bash `pipefail` guarantee |

Execute/check critical stages separately or use a runner reporting every result. Do not truncate a build with `Select-Object -First 20` and judge only the final stage.

### Child PowerShell process exit codes

A normally completed `-File` may return 0; an unhandled terminating error usually produces 1. `-Command` often normalizes final failure to 1. At a **standalone entry point**, save a required native code and explicitly `exit $code`. Do not casually use `exit` in reusable functions or dot-sourced files because it can terminate their caller.

## 2. Statements, pipelines, and chains

Official reference: [about_Pipeline_Chain_Operators](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_pipeline_chain_operators?view=powershell-7.5).

- `;`/newlines execute sequentially; they do not mean stop on failure. Add exceptions or explicit conditionals.
- `|` is an object/stream pipeline, not conditional chaining or universally a Bash byte pipe.
- `&&`/`||` chain pipelines in 7.x, including cmdlets, functions, and native programs.
- `command && if (...) { ... }` and `command && $x = ...` are not arbitrary statement chains. Use separate statements and `if`.
- Leading `&` invokes a command; a **trailing pipeline** `&` in 7.x starts a background job. It is not a generic Bash/cmd background symbol.

## 3. Output streams and redirection

| Stream | Meaning | Writer |
|---|---|---|
| 1 | Success/pipeline data | `Write-Output` or expression output |
| 2 | Error | `Write-Error` |
| 3 | Warning | `Write-Warning` |
| 4 | Verbose | `Write-Verbose` |
| 5 | Debug | `Write-Debug` |
| 6 | Information | `Write-Information`, `Write-Host` |
| Nonredirectable progress | Progress display | `Write-Progress` |

- For PowerShell objects, `>`/`>>` use text formatting/file output; 7.x defaults to UTF-8 without BOM. `>` overwrites without prompting.
- `2>&1` merges errors into success, while `*>` captures all redirectable streams. Do not parse merged diagnostics as pure JSON.
- `$null` discards PowerShell output. `nul` is a cmd device-name convention, not a universal cross-layer spelling.
- `Write-Host` and `Out-String` are not stable machine-data interfaces. Emit selected objects or JSON/CSV instead.
- Table width and `Out-File -Width` affect display, not data serialization. Preserve original objects first.
- Locally suppress progress noise with `$ProgressPreference = 'SilentlyContinue'` when appropriate, not actual errors. Use `$PSStyle.OutputRendering = 'PlainText'` only on supporting 7.x versions when ANSI-free presentation is needed.
- Write large output to a task log, then search/read bounded relevant lines. Do not rerun a task because output was truncated. Use program-specific buffering controls, such as Python `-u`, when needed.
- In 7.4+, direct native stdout redirection/native-to-native pipes may preserve bytes. **Merging stderr, adding text cmdlets, or capturing strings** removes that assumption.

## 4. Distinguish `Start-Process` from .NET `Process`

Prefer direct `& $exe @nativeArgs` for ordinary CLI work, streaming output, and immediate `$LASTEXITCODE`. Use `Start-Process` when separate working directories, windows/output files, or a process object are required.

### `Start-Process` boundaries

- It starts asynchronously by default. `-Wait` waits; `-PassThru` returns a Process object whose `.ExitCode` can be checked after completion.
- The exit code belongs to that Process object. Do not treat `$LASTEXITCODE` after startup as the child's result.
- `-Wait` waits for the launched process **and descendants**; `Wait-Process` waits only for specified local processes. Windows can create independent processes, but agent tools may impose additional process-tree cleanup rules.
- `-ArgumentList <string[]>` joins elements with spaces into **one command-line string**, not preserved argv boundaries. Construct quoting according to the target parser; it is not automatic safe argument quoting.
- Set `-WorkingDirectory` to a confirmed absolute file-system directory. Wildcards are unsupported; paths with wildcard-like characters require verification.
- Redirect stdout/stderr to different files. Their encoding is a separate boundary, not controlled by a later `Set-Content -Encoding` option.
- `-Environment` requires 7.4+. Earlier 7.x versions can set/restore environment values in a controlled invocation without switching engines.
- `-Verb RunAs` involves elevation/interaction and is not an automatic permission repair. Do not combine `-NoNewWindow` with `-WindowStyle`.

A fixed Base64 payload avoids complex command-line arguments in this example:

```powershell
if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -ne 7) {
    throw 'PowerShell 7.x (Core) is required; no fallback is allowed.'
}
$engine = Join-Path -Path $PSHOME -ChildPath 'pwsh.exe'
$payload = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes('exit 0'))
$startOptions = @{
    FilePath = $engine
    ArgumentList = @('-NoLogo', '-NoProfile', '-NonInteractive', '-EncodedCommand', $payload)
    WorkingDirectory = $env:TEMP
    Wait = $true
    PassThru = $true
    ErrorAction = 'Stop'
}
$process = Start-Process @startOptions
try {
    if ($process.ExitCode -ne 0) { throw "Child failed: $($process.ExitCode)" }
}
finally {
    $process.Dispose()
}
```

The arguments here contain no spaces and the Base64 payload contains no command syntax. Do not generalize this to arbitrary `-ArgumentList` arrays. Confirm the temporary working directory exists too.

### .NET `ProcessStartInfo.ArgumentList`

Modern .NET in 7.x provides `ArgumentList.Add($value)` for individual unquoted values; do not prequote them or also set `.Arguments`. Child PowerShell processes must still use a verified 7.x executable. Official reference: [ArgumentList](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.processstartinfo.argumentlist?view=net-9.0).

For redirected `.StandardOutput`/`.StandardError`, set `UseShellExecute = $false` and identify the child's actual encoding for text reads. **Do not** wait for exit before draining large output, or synchronously read two potentially full streams one after the other. Use concurrent asynchronous/event reads or separate files. Stdin can also participate in deadlocks. Wait for EOF: process exit does not always mean descendants have closed inherited output handles.

Official deadlock reference: [Process.StandardOutput](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.standardoutput?view=net-9.0). Do not build a complicated Process wrapper for ordinary CLI tasks when the existing tool runner is sufficient.

## 5. Timeouts, jobs, and persistent services

- `Wait-Process -Timeout N` emits a nonterminating timeout error but **does not kill the process**. `.WaitForExit(milliseconds)` returning false does not terminate it either.
- `Wait-Job -Timeout N` is not an execution limit. Check the returned result and `.State`; `Completed` does not automatically prove internal native commands returned 0.
- `Start-Job` children and ThreadJob depend on the host lifetime. Running child jobs terminate with the parent session; do not assume a later fresh call can manage them.
- Pass job inputs explicitly with `param()`/`-ArgumentList`. Do not assume parent-scope variables are available. Deserialized output may lose methods.
- Some embedded hosts lack the child `pwsh` support required by `Start-Job`. Use the permitted runner or direct bounded execution rather than creating an unauthorized persistent service.
- For one-shot jobs: retain the handle, wait with limits, inspect status, receive results, and stop/remove **that job** in cleanup. Do not remove every job in the session.
- Use tool-supported lifecycle management for persistent services. A background request alone does not require detachment. Keep bounded builds/tests attached and stop temporary helpers after verification.
- Check process identity, logs, and local readiness after startup. HTTP 200 alone may come from a preexisting service; correlate the owned process and port.
- Confirm ownership before termination. Use saved PIDs/process handles/tool handles only. `Stop-Process -Id $process.Id` stops that process; use an authorized process-tree-aware tool for descendants. Never use name-based bulk termination.
- `Dispose()` releases .NET handles; **it does not terminate a process**. Stop, wait, and dispose are distinct operations.
- For state-changing commands, inspect the original operation after timeout before retrying commits, deployments, installations, or migrations.

