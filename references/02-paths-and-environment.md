# Paths, Working Directories, and Environment

Official references: [about_Path_Syntax](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_path_syntax?view=powershell-7.5), [Get-Location notes](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-location?view=powershell-7.5#notes), [Join-Path](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/join-path?view=powershell-7.5), [Test-Path](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/test-path?view=powershell-7.5), [about_Environment_Variables](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_environment_variables?view=powershell-7.5), and [about_Command_Precedence](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_command_precedence?view=powershell-7.5).

## 1. Distinguish path types

| Type | Example | Caution |
|---|---|---|
| Absolute Windows path | `C:\repo\src\main.py` | Preferred for tool calls and .NET file APIs |
| Relative to the working directory | `.\src\main.py` | Know the actual CWD for every invocation |
| Root of the current drive | `\repo\src` | Depends on the current drive |
| Drive-relative path | `C:src\main.py` | Not `C:\src\main.py`; avoid it |
| UNC | `\\server\share\repo\main.py` | Check permissions/network access; cmd has working-directory limitations |
| Extended-length path | `\\?\C:\very-long-path` | Not a universal fix; support depends on API, application, and file system |
| PowerShell provider path | `HKLM:\Software`, `Env:\Path` | Not ordinary file paths for native file tools |
| File URI | `file:///C:/repo/main.py` | Use only with URI-aware interfaces, not `-LiteralPath` |
| WSL/Bash path | `/mnt/c/repo` | Valid only in the corresponding subsystem |

PowerShell cmdlets on Windows generally accept `/` as a separator, but native applications may interpret it as an option. Use native `\` separators for Windows commands. URL/Markdown formatting must not change actual command paths; do not claim PowerShell itself never supports `/`.

## 2. Quoting, wildcards, and `-LiteralPath`

```powershell
$file = 'C:\Documents & reports\config[1].json'
if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
    throw "Expected file not found: $file"
}
Get-Content -LiteralPath $file -Raw -Encoding UTF8 -ErrorAction Stop
```

- Single quotes prevent interpolation; `-LiteralPath` prevents provider wildcard interpretation of `[]*?`. They solve different problems.
- Prefer `-LiteralPath` for supported commands such as `Get-Item`, `Get-ChildItem`, `Get-Content`, `Set-Content`, and `Remove-Item`. Do not invent that parameter for `New-Item` or `Start-Process`.
- To create exact names containing brackets, use confirmed **absolute file-system paths** with `.NET Directory.CreateDirectory` or `File.WriteAllText`, and control overwriting. Do not rename unrelated files to work around parsing.
- When pattern matching is intentional, use explicit `-Path`/`-Filter`, narrow the scope, and define extension/recursion rules. Never let an unintended `*` broaden a deletion.
- `-Force` does not fix escaping, elevate permissions, or replace authorization. `-ErrorAction SilentlyContinue` does not repair a path.
- `Test-Path` returning true proves only current existence/type, not permissions or freedom from later races. Handle real I/O errors too.
- Reject null/blank paths before deletion, overwriting, or moving. Never turn an empty target into the current directory.

## 3. Compose, resolve, and create separately

```powershell
$root = 'C:\repo'
$inputFile = Join-Path -Path $root -ChildPath 'data\input[1].json'
$outputFile = Join-Path -Path $root -ChildPath 'out\result.json'
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    throw "Directory not found: $root"
}
$resolvedRoot = (Resolve-Path -LiteralPath $root -ErrorAction Stop).ProviderPath
```

- `Join-Path` uses provider separators; it neither checks the final file nor confines input to a trusted root. Validate `..`, absolute paths, symbolic links, and junctions separately.
- Resolve existing items only. For a new output file, resolve its parent and combine it with the intended name instead of requiring the nonexistent file to resolve.
- `Join-Path -Resolve` expands/checks paths; do not apply it to missing outputs.
- `.NET Path.Combine`/`GetFullPath` are not PowerShell provider parsers. They do not expand `~`, `$env:...`, or registry providers.
- Tilde expansion depends on the PowerShell parsing context and is not guaranteed for values passed to native programs. Build explicit absolute paths from `$HOME`/`$env:USERPROFILE` and `Join-Path`.
- Give .NET methods actual absolute file-system paths: runspace `Get-Location` can differ from `[Environment]::CurrentDirectory`.
- Use `\\?\` paths only with verified supporting APIs. The official file-system provider documentation requires `-LiteralPath` for Win32 namespace paths; never use the prefix to bypass policies or access control.

## 4. Set the working directory explicitly and stop on failure

```powershell
$ErrorActionPreference = 'Stop'
$root = 'C:\repo with spaces'
Push-Location -LiteralPath $root -ErrorAction Stop
try {
    & git.exe --no-pager status --short
    $code = $LASTEXITCODE
    if ($code -ne 0) { throw "git status failed: $code" }
}
finally {
    Pop-Location
}
```

- Confirm the root before running relative scripts, reading configuration, locating packages, or writing outputs.
- A fresh-process call may use `Set-Location -LiteralPath $root -ErrorAction Stop`. Prefer push/`finally`/pop in shared or persistent sessions.
- Push successfully before entering the try block; a failed push must not pop someone else's location stack.
- Do not use cmd syntax such as `cd /d` in PowerShell. Use full `Set-Location -LiteralPath` syntax.
- In a real script, use `$PSScriptRoot` for adjacent resources rather than assuming the launch CWD is the script directory. Inline commands may not have a useful `$PSScriptRoot`.

```powershell
# Use inside an actual .ps1 file.
$settings = Join-Path -Path $PSScriptRoot -ChildPath 'settings.json'
Get-Content -LiteralPath $settings -Raw -Encoding UTF8 -ErrorAction Stop
```

## 5. Command discovery and aliases

PowerShell entry points must be verified 7.x executables. Never use `powershell.exe`, bare `powershell`, file associations, or an unverified runner default. If the current tool is not 7.x, change its supported shell configuration first; otherwise stop rather than wrapping or falling back.

```powershell
Get-Command -Name python, python.exe, npm, curl -All -ErrorAction SilentlyContinue |
    Select-Object Name, CommandType, Source, Definition
```

- Aliases, functions, cmdlets, and external files have precedence rules. Use an explicit extension or verified absolute path when a particular native implementation is required.
- A program in the current directory is not automatically callable by bare name. Use `.\script.ps1` or an absolute path rather than adding `.` to PATH.
- Verify the implementation instead of guessing from its name. Profiles, aliases, or functions may shadow names. Use `curl.exe` for curl; its parameters are not those of `Invoke-WebRequest`.
- `where` may resolve to `Where-Object`; use `Get-Command` or explicit `where.exe` to locate executables.
- `ModuleName\CommandName` can disambiguate cmdlets. Distinguish a missing module from an unsupported parameter before installing anything.
- Keep modules in 7.x/Core. Do not use `Import-Module -UseWindowsPowerShell`, `WinPSCompatSession`, or `-SkipEditionCheck` to force incompatible modules. Discovery/import may implicitly create an older-engine process: verify Core support, and use permitted session-specific `DisableImplicitWinCompat` configuration when strict prevention is needed. Do not change global configuration automatically.

## 6. Environment variables, virtual environments, and batch setup

```powershell
$oldValue = $env:EXAMPLE_TOOL_MODE
try {
    $env:EXAMPLE_TOOL_MODE = 'ci'
    & 'C:\repo\.venv\Scripts\python.exe' -X utf8 -c 'import sys; print(sys.executable)'
    $code = $LASTEXITCODE
    if ($code -ne 0) { throw "Python probe failed: $code" }
}
finally {
    $env:EXAMPLE_TOOL_MODE = $oldValue
}
```

- `$env:NAME = 'value'` changes the current process environment inherited by later children. A child cannot update its parent's environment.
- Do not use Bash `NAME=value command` or cmd `set NAME=value` syntax. Environment values are strings, not native booleans.
- PowerShell 7.5+ can preserve an empty-string environment value. Earlier 7.x versions may treat it as deletion. Respect the distinction when restoring state.
- In persistent sessions, change only necessary values and restore them in `finally`. Initialize each fresh process explicitly; do not edit user/machine environment or profiles unless requested.
- Prefer directly invoking `.venv\Scripts\python.exe`, or a repository-approved `conda run`/environment entry point, over activation that a later tool call may forget.
- `Activate.ps1` changes the current session. `activate.bat` changes only its cmd process. Keep `vcvars64.bat`/`VsDevCmd.bat` setup and compilation in one cmd invocation.
- Windows PATH uses `;`; use `[IO.Path]::PathSeparator` where portability matters. Do not accidentally replace the existing PATH.

## 7. Execution policy is not the first repair

Official reference: [about_Execution_Policies](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.5).

For blocked scripts, first inspect `Get-ExecutionPolicy -List`, the actual entry point, provenance, and required engine. Distinguish signatures/download markings, policy, file permissions, and missing executables.

- Do not make `Set-ExecutionPolicy Unrestricted`, `Bypass`, or `Unblock-File` a standard prerequisite.
- Execution policy is not a security boundary, but organizational rules and tool approvals still apply.
- Process-scoped settings are not permanent changes and do not override Group Policy. Any required adjustment needs explicit authorization and minimal scope.
- Do not inspect, alter, or disable security software or elevate automatically. Keep changes within task authorization.

