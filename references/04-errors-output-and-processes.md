# Errors, output, and processes

Choose error handling for the operation. A single final native command needs no wrapper when the tool reliably reports its success/failure. Scripts with dependent steps, special exit codes, or owned resources need explicit handling.

## Cmdlet failures

Use `-ErrorAction Stop` on a required operation so a nonterminating error cannot be followed by misleading success:

```powershell
$content = Get-Content -LiteralPath '.\config.json' -Raw -ErrorAction Stop
$config = $content | ConvertFrom-Json -ErrorAction Stop
```

Use `$ErrorActionPreference = 'Stop'` within a script when most operations need it. Add `catch` only for recovery or useful context, and `finally` for actual cleanup/restoration. Empty catches, `SilentlyContinue` on required work, and catch-then-rethrow wrappers without added value are unhelpful. Strict mode is optional within owned scripts, not global setup.

## Native exit codes

Inspect `$LASTEXITCODE` immediately when the result controls later work:

```powershell
dotnet.exe build
if ($LASTEXITCODE -ne 0) { throw "Build failed: $LASTEXITCODE" }
```

For a standalone script/process that must return the exact native code:

```powershell
python.exe -m pytest -q
exit $LASTEXITCODE
```

- Save `$code = $LASTEXITCODE` immediately if another command will run before it is used. Cmdlets do not generally update it; `$?` can be overwritten by the next command.
- `-Command` can normalize a nonzero result to 1; a normally completed `-File` can return 0 despite an earlier native failure. Explicitly propagate the code at the entry point when required.
- Do not use `exit` casually in reusable functions, dot-sourced files, or a persistent tool session.
- `$ErrorActionPreference` alone does not normally turn native failure into a catchable exception; `-ErrorAction Stop` is not a native CLI option.
- Stderr can contain warnings/progress with exit 0; empty stderr does not prove success.

| Program | Status interpretation |
|---|---|
| Most build/test commands | 0 succeeds; inspect the program's contract for exceptions |
| `rg` | 0 match, 1 no match, 2 error. `--quiet` may hide another error after finding a match |
| `git diff --exit-code` | 0 no differences, 1 differences, other codes errors |
| robocopy | 0–7 usually nonfailure; 8 or higher indicates failure |

On 7.4+, `$PSNativeCommandUseErrorActionPreference` is generally available, defaults false, and can be changed by the host. When enabled with Stop, it can throw before a manual status check. If a task accepts nonzero informational states, disable it **locally for that operation**, not in every invocation:

```powershell
& {
    $PSNativeCommandUseErrorActionPreference = $false
    rg -n --fixed-strings 'needle' '.\src'
    $code = $LASTEXITCODE
    if ($code -gt 1) { throw "Search failed: $code" }
}
```

Earlier 7.x experimental availability varies; inspect capability when needed. A local scope restores this PowerShell preference afterward, but not process environment/Console changes.

## Sequencing and output

- `&&` / `||` chain pipelines based on success. Use them for straightforward zero-success dependencies, such as `dotnet.exe restore && dotnet.exe build --no-restore`.
- They do not join arbitrary statements: `command && if (...)` is invalid. A newline or `;` simply continues regardless of the previous native exit.
- A multi-native pipeline has no general Bash `pipefail` guarantee; check critical stages separately. Do not truncate a running build/test with `Select-Object -First`.
- PowerShell streams are success (1), error (2), warning (3), verbose (4), debug (5), and information (6); progress is separate. `2>&1` merges diagnostics, and `*>` captures redirectable streams.
- Keep machine output as objects/JSON/CSV. Formatting commands, mixed diagnostics, and table-width truncation lose data.
- Capture verbose task output once, then search or tail the saved log. Do not rerun a successful operation to recover truncated output. Suppress progress only when useful, not errors.
- Text redirection overwrites/appends formatted text. Native byte-preserving redirection has [7.4+ restrictions](./03-encoding-and-data.md#binary-data).

## Processes and services

Use the agent tool's lifecycle for builds, tests, and services when available. Direct invocation already handles ordinary streaming CLI work; a custom process wrapper adds complexity.

| Mechanism | Correct use |
|---|---|
| Tool returns a running handle | Read/wait/stop that original handle. Initial wait expiry is not completion or proof of termination |
| `Start-Process` | Asynchronous by default. `-Wait -PassThru` allows checking the returned Process object's `.ExitCode`, not `$LASTEXITCODE` |
| `Start-Process -ArgumentList` | Joins elements into one command-line string. Quote for the target parser; an array does not preserve argv boundaries |
| .NET `ProcessStartInfo.ArgumentList` | Add individual unquoted values; do not also set `.Arguments`. Use `UseShellExecute = $false` for redirection |
| `Wait-Process -Timeout`, `Wait-Job -Timeout`, `.WaitForExit(ms)` | Limit waiting; do not terminate the operation |
| `Start-Job` / trailing pipeline `&` | Jobs depend on their parent session; not durable services across fresh calls |

For a real process-management task:

- Use a confirmed absolute working directory. Set `-WindowStyle Hidden` for noninteractive Windows helpers; do not combine it with `-NoNewWindow`. `Start-Process -Environment` needs 7.4+.
- Read redirected stdout and stderr concurrently or send them to separate files. Waiting before draining, or reading full streams sequentially, can deadlock. Stdin may also need closure. Process exit does not necessarily mean descendants closed all pipe handles.
- Set decoders to the producer's actual encoding. Use file/streaming capture for large output rather than unbounded in-memory collection.
- `Start-Process -Wait` includes descendants; `Wait-Process` targets specified local processes. Check the tool's own process-tree rules.
- Verify readiness with the owned process, logs, and a local health check. A port response might belong to an existing service.
- Stop only saved, verified task-owned handles/PIDs. `Dispose()` releases handles; it does not kill a process. Tree cleanup requires a supported mechanism, not name-based bulk termination.
- Keep bounded work attached. Do not use detachment or jobs to bypass host restrictions. For one-shot jobs, pass inputs explicitly, inspect status/results, and stop/remove only that job.
- Inspect the original operation after a timeout before retrying a mutation. A timeout does not establish failure.

Sources: [automatic variables](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables?view=powershell-7.5), [preferences](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables?view=powershell-7.5), [Start-Process](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process?view=powershell-7.5), and the [source record](./07-official-sources.md).
