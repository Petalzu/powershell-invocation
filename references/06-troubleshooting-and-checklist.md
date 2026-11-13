# Troubleshooting

Find the first failing boundary: tool/JSON -> PowerShell parsing -> command/path resolution -> arguments/encoding -> application -> output/lifecycle. Change one relevant assumption at a time. Do not run this as a checklist before successful ordinary commands.

## Repair by symptom

| Symptom | Focused repair |
|---|---|
| Simple work produces long commands | Remove repeated discovery, encoding setup, and wrappers; use a direct call. Move substantial logic or file bodies to the appropriate editing/script route |
| Patch does not match | Reread the relevant range and fix context; avoid a whole-file shell rewrite |
| Tool name exists but has no callable schema | Discover once if supported, then use an available editing route; do not invent fields or loop discovery |
| Unexpected token / unterminated string | Check JSON, PowerShell, and child-language quoting separately; avoid nested source strings |
| A spaced executable fails or only prints its path | Use `& $exe @nativeArgs`; the executable variable contains only its path |
| Existing bracketed filename is not found | Check CWD and `-LiteralPath`; quotes alone do not stop wildcard matching |
| Variable followed by colon fails | Use `"${name}:suffix"` or formatting |
| Bash heredoc / `&& if` fails | Use a short here-string or script file; chains connect pipelines, not arbitrary statements |
| Unsupported PowerShell syntax/parameter | Verify 7.x/Core and the actual command/version; do not fall back to an older engine |
| CWD, PATH, or activation disappears | Fresh calls do not share state; keep initialization with its command |
| Batch compiler setup appears ineffective | Setup and compilation must share the same cmd process |
| Blocked npm/script shim | Inspect that entry point and policy; diagnose before changing policy or installing anything |
| Chinese output or stdin is corrupted | Identify actual producer/consumer encodings; configure that boundary before startup. See [encoding](./03-encoding-and-data.md) |
| Console encoding setter fails | Host may lack a console; use explicit file/Process encoding instead |
| JSON has formatting internals, extra text, or wrong array shape | Serialize selected original objects, preserve arrays, and keep stdout data-only |
| Archive/image bytes are corrupted | Remove text processing; use an output-file option or supported byte API |
| Cmdlet error bypasses catch | Required cmdlets need `-ErrorAction Stop` to make nonterminating errors catchable |
| Native failure is missed or overwritten | Check `$LASTEXITCODE` immediately and propagate at the process boundary; cmdlet error preferences alone are insufficient |
| No matches/differences treated as crashes | Interpret informational codes; inspect native-error preferences if they interrupt manual handling |
| Empty/quoted native argv changes | Check the 7.3+ argument mode and test synthetic argv; use a supported file/response protocol for incompatible cases |
| `Start-Process` splits arguments | Its array becomes one command string; prefer direct invocation or .NET ArgumentList |
| Process hangs or continues after timeout | Drain both redirected streams concurrently; inspect/wait/stop the original owned handle |
| Job missing in a later call | Parent session ended or a new process started; use the tool's lifecycle |
| Cannot overwrite PID/Host/HOME | Automatic variables are case-insensitive; choose task-specific names |

For detailed fixes, open [invocation](./01-invocation-and-parsing.md), [paths](./02-paths-and-environment.md), or [errors/processes](./04-errors-output-and-processes.md) according to the symptom.

## Targeted verification

Parse a substantial or changed script without executing it:

```powershell
$tokens = $null
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors) | Out-Null
if ($parseErrors.Count) { throw ($parseErrors.Message -join [Environment]::NewLine) }
```

Parsing checks syntax, not command availability, parameter binding, permissions, or behavior. Test the boundary being changed:

- Paths/encoding: use task-owned fixtures with spaces, brackets, apostrophes, Chinese, and non-BMP characters; compare actual strings and bytes.
- Native arguments: compare count, order, and values, including empty strings, embedded quotes, and trailing backslashes.
- Failures: use a controlled native exit 7 and a missing-path cmdlet error; confirm dependent work stops and required status survives.
- Processes: verify identity and readiness, then clean up only owned resources. No service is needed just to test an ordinary CLI.

The offline [self-test](../scripts/Test-PowerShellInvocation.ps1) covers those core boundaries, JSON shape, BOM/no-BOM, UTF-16LE, binary redirection, scoped error preferences, UTF-8/GBK streams, and cleanup. It requires no network or packages; Python checks are optional. Use it for skill maintenance or regressions, not every invocation. See [tested scope](./07-official-sources.md).
