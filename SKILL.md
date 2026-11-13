---
name: powershell-invocation
description: 'Write and run concise, reliable PowerShell 7.x commands on Windows. Use for pwsh execution, quoting, native CLI exit codes, encoding, and process troubleshooting.'
---

# PowerShell invocation

Use the shortest clear command that preserves arguments, failure status, and the intended destination. **Routine calls should usually take 1–5 readable lines.** Add setup only when needed.

## Default execution

- Use **PowerShell 7.x / Core only**, selected through the tool's shell setting. Trust a verified environment; otherwise check `$PSVersionTable` once. No Windows PowerShell wrappers, compatibility sessions, or older-engine fallback. Report a blocker if 7.x is unavailable.
- Prefer the tool's working-directory field. Use relative paths inside that confirmed directory and absolute paths across boundaries. Assume fresh calls unless persistence is documented; keep required setup and execution together.
- Run known commands directly: `git.exe status --short`. Use `&` for a quoted executable path or variable. Do not routinely add `Get-Command`, nested `pwsh`, scriptblock wrappers, or `Start-Process`.
- Use full cmdlet names and clear parameters. Variables and splatting should clarify reuse or complex arguments, not wrap every literal.
- Search with `rg` / `rg --files` when available. Narrow paths/patterns before reading; use `Get-Content -LiteralPath ... -Raw` for small files or `-Tail` for logs.
- Batch related independent reads when results stay distinguishable, or use tool-level parallelism. Keep dependent work sequential. Avoid unrelated command bundles and decorative separators.

## File editing and command size

- Use a callable editor/patch tool for authored files; preserve encoding, BOM, line endings, and unrelated content. If none is exposed, discover one once when supported.
- Beyond roughly **10 lines**, remove needless setup first. Use an existing script, or create a helper with the editor, for substantial logic or complex quoting. Short loops can stay inline.
- Keep large file bodies/data out of shell source; use editing tools and supported file/response-file parameters. Do not disguise length with semicolon-packed lines, Base64, nested interpreters, or append chunks.
- Prefer real newlines to trailing backticks. Line counts guide readability: do not split required setup from execution or create a helper for every small task.
- Without a callable editor, use an available patch executable or a small shell write/programmatic transformation within permissions. Report a limitation only when no permitted route exists.

## Correctness without boilerplate

- **Arguments:** single-quote fixed values; interpolate only intentionally. Pass executable and arguments separately. PowerShell backslash does not escape quotes, and JSON escaping is not shell escaping. Never use `Invoke-Expression` to repair quoting.
- **Paths:** use `-LiteralPath` where supported; quotes do not neutralize `[]*?`. Before recursive deletion/moving, verify the resolved target, including links, stays inside the intended directory. Keep those operations in one shell.
- **Cmdlets:** use `-ErrorAction Stop` when failure must prevent later work, especially directory changes. Set scoped `$ErrorActionPreference` for scripts that need it, not every command.
- **Native programs:** a single final command can rely on the tool's reliable success/failure status. Before dependent logic, inspect `$LASTEXITCODE` immediately; save it if needed later. Use `exit $code` only at a standalone script/process boundary when exact propagation is required.
- **Status meanings:** `rg` exit 1 means no match; `git diff --exit-code` exit 1 means differences; robocopy fails at 8 or higher. Cmdlet error preferences alone do not handle native failures. Consult the error reference if host native-error preferences interfere.
- **Encoding:** ordinary PowerShell 7 text-file defaults are UTF-8; preserve existing formats. Configure only a boundary that needs it. Do not prepend Console settings or `chcp` routinely, or pass binary data through text pipelines.
- **Processes:** a wait expiring does not prove termination. Read the original handle; stop only owned, verified processes. Use supported tool lifecycle management.

For a native step followed by PowerShell logic:

```powershell
dotnet.exe build
if ($LASTEXITCODE -ne 0) { throw "Build failed: $LASTEXITCODE" }
```

Use the project's actual command. For simple zero-success dependencies, `&&` connects pipelines; it cannot precede a bare `if` or assignment. A newline or `;` alone does not stop on failure. Examples are alternatives, not a checklist to paste into every call.

## Read only when needed

| Need | Reference |
|---|---|
| Nested quoting, complex argv, child PowerShell, batch setup | [Invocation and parsing](./references/01-invocation-and-parsing.md) |
| Ambiguous paths, persistent CWD/environment, command discovery | [Paths and environment](./references/02-paths-and-environment.md) |
| Garbled text, legacy encodings, structured data, binary output | [Encoding and data](./references/03-encoding-and-data.md) |
| Lost failures, special exit codes, streams, background processes | [Errors and processes](./references/04-errors-output-and-processes.md) |
| Choosing a tool or short command pattern | [Tools and recipes](./references/05-agent-tools-and-recipes.md) |
| Diagnosing a failure | [Troubleshooting](./references/06-troubleshooting-and-checklist.md) |
| Feature-version evidence and tested scope | [Official sources](./references/07-official-sources.md) |

Ordinary calls need no further reading. For skill maintenance/regressions, run the offline [self-test](./scripts/Test-PowerShellInvocation.ps1) from this skill's directory: `& '.\scripts\Test-PowerShellInvocation.ps1'`. It cleans its scratch directory; missing Python skips Python checks. The [argv probe](./scripts/argv_probe.py) prints arguments: use synthetic values. Neither is routine preflight.
