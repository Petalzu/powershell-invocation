# Paths and environment

Use the tool's working-directory field and direct arguments for ordinary calls. Read this reference for ambiguous paths, persistent state, or discovery failures.

## Paths

| Path | Interpretation |
|---|---|
| `C:\repo\src\main.py` | Absolute Windows filesystem path |
| `.\src\main.py` | Relative to the confirmed working directory |
| `C:src\main.py` or `\src\main.py` | Drive-relative or current-drive dependent; avoid ambiguity |
| `\\server\share\repo\main.py` | UNC; native application and cmd support varies |
| `\\?\C:\long-path\...` | Extended path; support depends on API/application, not a universal fix |
| `HKLM:\Software`, `file:///C:/repo`, `/mnt/c/repo` | Provider, URI, or WSL path; not interchangeable native filenames |

PowerShell on Windows usually accepts `/`, but native programs may interpret it as an option. Prefer `\` in Windows commands. Use actual absolute filesystem paths with .NET file APIs: runspace CWD can differ from `[Environment]::CurrentDirectory`, and .NET does not expand `~` or PowerShell variables.

```powershell
Get-Content -LiteralPath 'C:\reports & data\config[1].json' -Raw -ErrorAction Stop
```

- Quoting prevents interpolation/splitting; `-LiteralPath` prevents wildcard interpretation. Do not invent that parameter for commands such as `New-Item` or `Start-Process`.
- Use `-Path` / `-Filter` when matching is intentional. Scope recursive work before applying a wildcard.
- `Join-Path` composes a path; it does not validate or confine it. `Resolve-Path -LiteralPath` resolves existing items. For a new file, resolve the parent first if needed.
- Use `Test-Path -LiteralPath ... -PathType Leaf` or `Container` only when existence/type changes the next action. A read usually needs only `Get-Content ... -ErrorAction Stop`, not a separate existence probe.
- For exact names unsupported by a cmdlet's path parameters, use an appropriate literal .NET API with a confirmed absolute path and overwrite intent.
- Before recursive deletion/moving, reject blank targets and verify resolved absolute paths remain inside the intended root, including symlink/junction targets. Use native PowerShell operations with `-LiteralPath`, not paths forwarded into another shell.
- `-Force` and `SilentlyContinue` do not repair paths, grant access, or establish authorization.

## Working directory and state

A fresh call with no working-directory field can set its directory once:

```powershell
Set-Location -LiteralPath 'C:\repo with spaces' -ErrorAction Stop
git.exe status --short
```

A persistent caller that temporarily changes location needs restoration:

```powershell
Push-Location -LiteralPath $repoPath -ErrorAction Stop
try {
    git.exe status --short
    if ($LASTEXITCODE -ne 0) { throw "git failed: $LASTEXITCODE" }
}
finally {
    Pop-Location
}
```

Push before entering `try` so a failed push cannot pop someone else's location. Do not use this wrapper for a fresh process with a supported CWD field. In real scripts, use `$PSScriptRoot` for adjacent resources.

- Set process environment values with `$env:NAME = 'value'`. Keep setup and dependent execution in the same call; children cannot change the parent's environment.
- In shared sessions, save/restore only values actually changed. A scriptblock scope does not restore process environment or location.
- PowerShell 7.5+ distinguishes an empty environment value from removal; earlier 7.x may treat empty strings as deletion.
- Prefer `& '.\.venv\Scripts\python.exe' ...` over activation across calls. Batch toolchain setup must run with its target in [one cmd process](./01-invocation-and-parsing.md#batch-setup-and-other-callers).
- Preserve PATH when extending it; Windows entries use `;`. Do not change profiles or user/machine environment merely to run a task.

## Discover commands only when uncertain

For a missing/shadowed command or a blocked shim, inspect that command:

```powershell
Get-Command -Name npm -All | Select-Object Name, CommandType, Source
```

Aliases/functions can shadow native names. Use `where.exe` or `curl.exe` when the native program is intended, and an absolute executable path when identity matters. A script in the current directory needs `.\script.ps1` or an absolute path. Do not resolve every known executable before every call.

Keep all PowerShell hosts and modules in 7.x/Core. Do not use `Import-Module -UseWindowsPowerShell`, `WinPSCompatSession`, or `-SkipEditionCheck` to force an incompatible module. An implicit compatibility import can also launch an older engine; check module support and use session-specific `DisableImplicitWinCompat` when that risk applies.

For script-policy errors, inspect the actual entry point, provenance, and `Get-ExecutionPolicy -List`. Diagnose missing dependencies, signatures, and permissions separately. Do not make `Bypass`, `Unblock-File`, installation, or elevation a routine prerequisite; use existing authorization and the smallest necessary scope. Execution policy is not a security boundary, but organizational rules and tool permissions still apply.

Sources: [path syntax](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_path_syntax?view=powershell-7.5), [Get-Location](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-location?view=powershell-7.5#notes), [environment](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_environment_variables?view=powershell-7.5), and the [source record](./07-official-sources.md).
