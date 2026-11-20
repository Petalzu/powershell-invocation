# Paths and environment

## The file exists but the command cannot find it

- For `report[1].txt`, quoting keeps the argument together; `-LiteralPath` disables provider wildcards. Use `-Path` or `-Filter` only if you intend a pattern. Not every cmdlet accepts `-LiteralPath`.
- Prefer a confirmed working directory or an absolute filesystem path. `C:repo` is drive-relative; `\repo` uses the current drive. Provider paths, file URIs and WSL paths are not native Windows filenames. Confirm UNC support in the consumer.
- `Join-Path` composes names; it does not prove existence or containment. For .NET APIs use an absolute path: PowerShell location can differ from `[Environment]::CurrentDirectory`. In a script, locate adjacent files via `$PSScriptRoot`.
- Before a recursive move/delete, verify the actual source and any destination. For a new destination, check the existing parent and the proposed name. A string prefix or `Resolve-Path` alone does not rule out a sibling with a similar name or a junction in an ancestor. Refuse ambiguous paths, the root itself unless explicitly targeted, and links you cannot verify. Use one shell and literal paths.

## A later tool call lost its directory or environment

Use the tool's working-directory field. If none exists in a fresh call, set location with `-ErrorAction Stop` before the dependent command. In a *shared* runspace, restore only what you change:

```powershell
Push-Location -LiteralPath $repoPath -ErrorAction Stop
try {
    git.exe status --short
    if ($LASTEXITCODE -ne 0) { throw "git failed: $LASTEXITCODE" }
} finally { Pop-Location }
```

Push before `try` so a failed push cannot pop the caller's location. `& { ... }` scopes shell variables, not CWD, `$env:` or Console settings. Children inherit environment state at startup and cannot change the parent. Run a venv's executable directly instead of activating across calls; keep required setup and execution together. In 7.5+ an empty environment value is distinct from removal.

## A command is missing, shadowed, or policy-blocked

Inspect **that name**, not the whole environment: `Get-Command -Name npm -All | Select-Object Name,CommandType,Source`. Use an explicit executable path when identity matters. A script in the current directory requires `.\` or an absolute path.

Distinguish a missing executable from a blocked script shim or incompatible module. Inspect `Get-ExecutionPolicy -List` only for a policy error. Do not install, elevate, weaken policy, or start a Windows PowerShell compatibility session as a fallback.
