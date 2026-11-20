# Exit codes and processes

## Native exit codes

A final native command can stand alone when the tool reliably reports success/failure. When the distinction matters, read `$LASTEXITCODE` immediately after the executable runs. `$?` is a transient Boolean, stderr can contain progress on success, and a later successful command can mask an earlier failure.

| Command | Interpret the code |
|---|---|
| `rg` | 0 match, 1 no match, 2 error. `--quiet` can mask a later input error once a match is found. |
| `git diff --exit-code` | 0 no differences, 1 differences; treat other codes as errors. |
| `robocopy` | 0-7 nonfailure states; 8 or higher means at least one copy failed. |

For example, to return a *Boolean* for a literal search while still surfacing a missing input, use the pattern below. `-e` accepts a pattern starting with `-`; `--` ends options before the search path. The local preference override is needed only if the host promotes native nonzero codes to errors (generally available in 7.4+).

```powershell
& {
    $PSNativeCommandUseErrorActionPreference = $false
    $null = rg -l -F -e $needle -- $searchPath
    $code = $LASTEXITCODE
    if ($code -notin 0, 1) { throw "rg failed (exit $code)" }
    $code -eq 0
}
```

- For zero-success dependencies, `dotnet.exe restore && dotnet.exe build --no-restore` skips the build on failure. `&&` joins pipelines, not a bare `if` or assignment. A multi-native pipe has no general `pipefail`; check critical stages separately.
- `-ErrorAction Stop` makes required **cmdlet** errors terminating; do not pass it to native programs. For an exact native code across a standalone script/process boundary, use `exit $LASTEXITCODE` immediately after the native command. `pwsh -Command` can normalize nonzero to 1; normal `-File` completion can mask it. Do not `exit` a shared session or dot-sourced utility.

## Processes and services

| Observation | Action |
|---|---|
| Tool returns a running handle or initial wait expires | Poll/read that same handle. Confirm final status before retrying. For truncated build/test output, read the saved log (e.g. `Get-Content -LiteralPath $log -Tail 60`); do not rerun a mutation to recover output. |
| Explicit background launch required | Prefer the tool's managed lifecycle. With `Start-Process`, use `-WindowStyle Hidden` for a noninteractive Windows helper and `-PassThru` to retain the process. After it exits inspect `.ExitCode`, not `$LASTEXITCODE`; `-Wait` waits at launch when appropriate. |
| Redirected child hangs | With `UseShellExecute = $false`, drain stdout **and** stderr concurrently before waiting (or redirect to separate files); close stdin when input is complete. Descendants may keep pipe handles open. |
| Timeout or service readiness is uncertain | A wait timeout does not kill a process; `Dispose()` only releases handles. Verify the owned process and its readiness, not just an open port. Stop only the verified handle/ID, never every process of that name. Jobs in a fresh shell are not durable services. |
