---
name: powershell-invocation
description: 'PowerShell Invocation Standards. Use when an agent runs, generates, reviews, or troubleshoots PowerShell commands on Windows. PowerShell 7.x / pwsh.exe only; no Windows PowerShell or automatic fallback. Covers shell tools, quoting, escaping, LiteralPath, Unicode paths, UTF-8/BOM, encoding corruption, native arguments, Python/Node, cmd/bat, exit codes, redirection, timeouts, and background process lifecycle. Load before executing PowerShell commands to prevent parsing, encoding, and process-management errors.'
user-invocable: true
disable-model-invocation: false
---

# PowerShell Invocation Standards

For AI agents executing commands through terminals, CLIs, and shell tools. Ensure **valid syntax, faithful arguments, verifiable encoding, reliable error propagation, and controlled process cleanup**, rather than cataloging every cmdlet.

## Mandatory engine policy

**Use PowerShell 7.x only: `pwsh.exe`, `PSEdition = Core`, and major version 7. Never use Windows PowerShell 5.1, `powershell.exe`, the bare `powershell` command, compatibility sessions, or automatic engine fallback. This includes tests, child processes, and third-party runners.**

- Execute directly when the tool is already known to run 7.x. Otherwise, perform a read-only version check before running task commands.
- If the host is not 7.x, select a verified `pwsh.exe` through the tool's supported shell configuration. Do not use an older engine as an outer wrapper. If 7.x is unavailable or cannot be selected, stop and report the blocker; do not downgrade or install software without authorization.
- Pin child PowerShell processes to a verified 7.x executable, not file associations or an unspecified default shell.
- Do not use `Import-Module -UseWindowsPowerShell`, `WinPSCompatSession`, or implicit compatibility processes. A module requiring an older engine is a blocker. Where supported and needed, use session-specific `DisableImplicitWinCompat` configuration without changing global settings.
- Check minor-version requirements for 7.3, 7.4, and 7.5 features. Choose alternatives within 7.x when a feature is missing; never change to an older engine.

Examples use Windows paths. Official documentation was reviewed on 2026-11-07. The locally verified executable is `C:\Program Files\PowerShell\7\pwsh.exe`, version 7.6.9; verify the path and version in other environments.

This skill cannot override host-tool contracts, safety policies, approvals, or user instructions. In particular, `shellId`, `initial_wait`, `mode`, and `detach` are **agent-tool fields, not PowerShell parameters**.

## Execution workflow

### 1. Establish the execution boundary

Identify the actual shell, whether each tool call creates a fresh process, its working directory, output decoding, and whether a timeout stops waiting or terminates execution. Reuse trusted environment information instead of probing repeatedly.

Minimal checks when needed:

```powershell
if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -ne 7) {
    throw 'PowerShell 7.x (Core) is required; no fallback is allowed.'
}
$PSVersionTable | Select-Object PSVersion, PSEdition, Platform
Get-Location
Get-Command -Name pwsh.exe, python.exe, node.exe -ErrorAction SilentlyContinue |
    Select-Object Name, CommandType, Source
```

Do not dump all environment variables, configuration, or credentials. Optional discovery may tolerate missing commands; required execution dependencies must fail explicitly.

### 2. Minimize parsing layers

| Scenario | Preferred method | Boundary |
|---|---|---|
| Tool already runs PowerShell 7.x | Direct cmdlets or PowerShell code | No unnecessary nested `pwsh -Command` |
| Known command name | `Get-ChildItem -LiteralPath $root` | Use full command and parameter names |
| Executable path contains spaces or is in a variable | `& $exe @nativeArgs` | `$exe` contains only the executable path |
| Script in the current directory | `& '.\scripts\task.ps1' -Name $name` | Receive values through script `param()` |
| Definitions needed in the current scope | `. '.\definitions.ps1'` | Dot-source trusted scripts only when necessary |
| Clean child PowerShell | `pwsh.exe -NoLogo -NoProfile -NonInteractive -File $script` | Do not default to `-ExecutionPolicy Bypass` |
| Short, fixed PowerShell code | `pwsh.exe ... -Command 'Get-Date'` | The outer shell parses quoting first |
| PowerShell code crosses multiple layers | Prefer a `.ps1` file, then `-EncodedCommand` | Base64 must encode UTF-16LE, not UTF-8 |
| PowerShell code through stdin | Here-string piped to `pwsh ... -Command -` | Statement-by-statement parsing; prefer files for complex control flow |
| Multiline Python or Node | Single-quoted here-string piped to `python -` or `node -` | Agree on encoding at both ends |
| Batch environment setup required | One `cmd.exe /d /c 'call ... && ...'` | Batch environment changes do not flow back to the parent |
| Separate working directory, output files, or process handle needed | `Start-Process`, or .NET `Process` when necessary | `Start-Process -ArgumentList` does not preserve individual argv boundaries |

Details: [Invocation and parsing](./references/01-invocation-and-parsing.md).

### 3. Protect paths and arguments

1. Prefer absolute Windows file-system paths and `\`. Do not pass URIs, JSON-escaped strings, or Bash paths as native file names.
2. Use single quotes for fixed strings and double quotes only when interpolation is needed. Backslash is not the PowerShell escape character; do not use `\"` to escape PowerShell quotes.
3. Prefer `-LiteralPath` for exact paths where supported. **Quoting prevents shell token splitting; it does not stop `-Path` from interpreting `[]*?`.**
4. Use `Join-Path` for composition, `Test-Path -LiteralPath ... -PathType ...` for existence/type, and `Resolve-Path -LiteralPath` for existing items. None provides authorization or a sandbox.
5. Stop when changing directories fails. Do not ignore a failed `Set-Location` and continue with a destructive command.
6. Separate executable and arguments: `& $exe @nativeArgs`. Do not concatenate input for `Invoke-Expression` or use `& "$exe $arguments"`.
7. Prefer arrays, splatting, parentheses, and real newlines over trailing backtick continuations. Start here-string closing markers in column 1.
8. `--`, `--%`, and quoting are not universal escaping mechanisms; follow the target application's actual protocol.

Details: [Paths and environment](./references/02-paths-and-environment.md).

### 4. Configure encoding at each boundary

PowerShell strings are Unicode. Corruption usually occurs at **source decoding, file bytes, pipes/stdin, native stdout/stderr, tool decoding, or font rendering**.

If the programs involved explicitly use UTF-8, configure the following in the **same invocation**:

```powershell
$utf8 = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = $utf8
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
```

This is not a universal switch. Console APIs may be unavailable in some hosts; diagnose failures rather than swallowing them. A legacy program emitting CP936/OEM bytes will still be corrupted if decoded as UTF-8. These settings do not set file cmdlet `-Encoding` or repair data already decoded incorrectly.

- Write files with explicit `-Encoding utf8NoBOM` or the consumer's agreed encoding. Use `.NET WriteAllText` with `UTF8Encoding($false)` for exact byte output.
- Default script and documentation sources to UTF-8 without BOM. Add a BOM only when the actual data consumer requires it, never to preserve an older PowerShell execution branch.
- Read whole JSON with `Get-Content -LiteralPath ... -Raw -Encoding UTF8`. Do not treat `Format-Table` output as data.
- Set `$env:PYTHONIOENCODING = 'utf-8'` before Python starts, or use `-X utf8` as appropriate. These settings affect Python, not the entire pipeline.
- `chcp 65001` changes the active console code page, not all file, process, and tool encoding behavior.

Required reference: [Encoding and data](./references/03-encoding-and-data.md).

### 5. Check errors and exit codes

```powershell
$ErrorActionPreference = 'Stop'
$exe = (Get-Command -Name git.exe -CommandType Application -ErrorAction Stop).Source
$nativeArgs = @('--version')
& $exe @nativeArgs
$nativeExit = $LASTEXITCODE
if ($nativeExit -ne 0) {
    throw "git failed with exit code $nativeExit"
}
```

- Convert required cmdlet operations to terminating errors with `-ErrorAction Stop` or a locally scoped `$ErrorActionPreference = 'Stop'`.
- Save `$LASTEXITCODE` immediately after native execution. Neither the absence of error text, the presence of stderr, nor a later successful command proves task success.
- `$ErrorActionPreference` alone does not normally turn native nonzero exits into exceptions. PowerShell 7.4+ has `$PSNativeCommandUseErrorActionPreference`, defaulting to `$false`; do not assume a host has left it unchanged.
- Interpret exit codes according to the program. No matches, detected differences, and informational robocopy states are not necessarily execution failures.
- To preserve a native code across a standalone script/process boundary, explicitly `exit $nativeExit`. Reusable functions must not casually terminate their host.
- In 7.x, `&&` and `||` chain **pipelines**, not arbitrary statements. Do not write `command && if (...) {}`.

Details: [Errors, output, and processes](./references/04-errors-output-and-processes.md).

### 6. Manage host state and process lifetime

- Design for **fresh-process calls** by default: prior directory changes, variables, PATH updates, and environment activation may not survive. Put required initialization and execution in the same call.
- Continue reading the original tool handle after the initial wait expires. Do not restart an installation, build, or test merely because the first wait ended.
- Keep bounded work attached and manageable. Use approved persistent-background mechanisms only for services that must outlive the interaction; never bypass restrictions with `Start-Process` or jobs.
- `Start-Job` and a trailing pipeline `&` do not create durable services. Jobs depend on their parent session.
- Verify background readiness with process identity, logs, and a local health check. Stop only owned, verified PIDs or tool handles; never terminate processes by name in bulk.
- `Wait-Process -Timeout`, `Wait-Job -Timeout`, and tool initial waits are not necessarily execution time limits or kill operations.
- Clean up temporary helpers in `finally`. Record the working directory, handle, logs, and stop method for persistent services.

Tool adaptation and templates: [Agent tools and recipes](./references/05-agent-tools-and-recipes.md).

## Load references as needed

| Topic | Reference |
|---|---|
| Strings, command discovery failures, `&`, splatting, JSON escaping, command entry points, batch files | [Invocation and parsing](./references/01-invocation-and-parsing.md) |
| Unicode/spaces/brackets in paths, UNC, relative paths, working directories, environments | [Paths and environment](./references/02-paths-and-environment.md) |
| UTF-8, BOM, CP936, Python, JSON/CSV, binary corruption | [Encoding and data](./references/03-encoding-and-data.md) |
| Uncaught failures, lost exit codes, redirection, truncation, processes, jobs, deadlocks | [Errors and processes](./references/04-errors-output-and-processes.md) |
| Tool lifecycle, builds/tests, stdin scripts, downloads, environment diagnostics | [Tools and recipes](./references/05-agent-tools-and-recipes.md) |
| Root-cause diagnosis, repair order, verification | [Troubleshooting and checklist](./references/06-troubleshooting-and-checklist.md) |
| Official evidence, feature versions, validation scope | [Official sources](./references/07-official-sources.md) |

## Validation and reporting

Report the actual PowerShell version, working directory/executable, relevant encoding, exit code, and observed outcome. Mark untested hosts and versions explicitly.

The offline [self-test](./scripts/Test-PowerShellInvocation.ps1) and [argv probe](./scripts/argv_probe.py) require no package installation. The self-test writes only to its own randomly named temporary directory and removes it afterwards. Python-specific checks are skipped if Python is unavailable. Never pass secrets to the argv probe: it prints its arguments.

```powershell
$test = Join-Path -Path $HOME -ChildPath '.copilot\skills\powershell-invocation\scripts\Test-PowerShellInvocation.ps1'
& $test
```

Run child tests only with a verified `pwsh.exe -NoLogo -NoProfile -NonInteractive -File $test`. The script requires Core and PowerShell 7, checks the exact major version, and never falls back. Unicode fixtures are constructed from code points to preserve non-ASCII test coverage without depending on the source file's encoding.

