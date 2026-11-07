# Troubleshooting and Acceptance Checklist

## 1. Identify the failing layer

Diagnose in order: **tool JSON/host -> PowerShell parsing -> command discovery -> paths/providers -> parameter binding -> encoding -> application behavior -> output/process lifecycle**. Change one verifiable assumption at a time. Not every failure is a permission or UTF-8 problem.

## 2. Common failures and correct repairs

| Symptom | Likely cause | Repair and verification |
|---|---|---|
| `Unexpected token` or unterminated string | Outer quotes ended early, insufficient JSON escaping, typographic quotes | Separate JSON/PowerShell/child-language layers; use arrays or script files; parse before execution |
| `The term 'C:\Program' is not recognized` | Space-containing executable split into tokens | `& 'C:\Program Files\Tool\tool.exe' @nativeArgs` |
| Only the path is printed | A quoted string was not invoked | Add `&`, keeping executable and arguments separate |
| `The term 'git --version' is not recognized` | Entire command line used as the executable name | `& 'git.exe' '--version'`, not iex |
| `Cannot find path` despite an existing file | Wrong CWD, bracket wildcard, URI/WSL path confusion | Confirm `Get-Location`, absolute path, `-LiteralPath`, and item type |
| Wrong file or no match | `-Path 'x[1].txt'` interprets a wildcard | Quoting is insufficient; use `-LiteralPath` |
| Invalid variable reference near a colon | `"$name:suffix"` looks scoped | Use `"${name}:suffix"` or formatting |
| Unsupported `Raw`/`AsByteStream`/`utf8NoBOM` parameter | Wrong engine/module or parameter set | Require 7.x/Core, then inspect command syntax; never fall back |
| Desktop edition, wrong major version, or an older entry point | Tool/runner default shell mismatch | Stop task execution and select verified `pwsh.exe` through supported configuration; otherwise report a blocker |
| Invalid `&&`/`||` separator | Wrong engine or invalid pipeline syntax | Verify 7.x/Core first; do not write older-engine workarounds |
| `&& if` or `&& $x = ...` fails | Arbitrary statement after pipeline chain operator | Split statements and explicitly inspect status |
| Reserved `<` or invalid `<<` | Bash heredoc/input redirection copied into PowerShell | Use a single-quoted here-string pipeline or a file plus arguments |
| Missing here-string terminator | No opening newline, indented/mismatched closing marker | Newline after opening marker; closing marker in column 1 |
| CWD/PATH changes disappear | Fresh process for each call | Initialize and execute in one call or use a supported persistent session |
| cl/link missing after setup.bat | Setup affected only a cmd child | Keep setup and command in one `cmd /d /c 'call ... && ...'` |
| `npm.ps1 cannot be loaded` | Script shim blocked by policy | Verify `Get-Command -All npm` and policy; select the trusted correct entry point, not a global policy change |
| Source text corrupt despite UTF-8 Console settings | Source bytes are not UTF-8, or wrong engine | Require 7.x/Core, inspect bytes, and use UTF-8 source without BOM; do not add an older-engine branch |
| Python receives `???` or decoding errors | Parent output encoding and child stdin disagree | Configure both ends in the same invocation; verify a generated non-ASCII round trip and bytes |
| Python corrupt output/UnicodeEncodeError | Redirected output encoding mismatch | Set Python encoding before startup and verify parent/tool decoding |
| `chcp 65001` does not help | Wrong boundary, CP936 output, or UTF-16 file | Identify actual bytes and consumer encoding instead of blind conversions |
| Missing glyphs or boxes | Font/rendering support | Compare code points/original data before rewriting files |
| JSON contains null characters or fails parsing | Existing file in another encoding or mixed streams | Read actual encoding, write explicit UTF-8, preserve data-only stdout, and use `-Raw` |
| JSON/CSV contains formatting internals | Formatting before serialization | Original objects -> `Select-Object` -> serializer |
| Large logs missing lines/columns | Tool truncation, table width, premature pipeline truncation | Read bounded task logs; avoid Format-* for machine data; do not rerun |
| Corrupt archives/images | Bytes passed through text processing | Native output-file options/byte streams; use only supported 7.4+ byte-preserving routes |
| Cmdlet failure bypasses catch | Nonterminating error | Use `-ErrorAction Stop` on the required operation |
| Native nonzero bypasses catch | Native exception mode not enabled | Immediately check `$LASTEXITCODE` or use controlled supported native preferences |
| Task reports 0 after build failure | Later success overwrote status or outer script completed normally | Save native code immediately, propagate at the standalone entry point, and check each stage |
| No match treated as a crash | `rg`/`git diff` informational exit 1 | Interpret the program's accepted status set |
| Empty/quoted native arguments lost | Legacy argument passing | Probe argv; use supported 7.x modes, data/response files, or .NET ArgumentList |
| Start-Process splits a space-containing argument | Its ArgumentList array was joined into one string | Direct `&`, correct target-specific quoting, or modern .NET API |
| Start-Process returns immediately and task claims success | Asynchronous startup mistaken for completion | Retain Process, wait/check `.ExitCode`, and verify readiness for services |
| Custom Process hangs | Full pipe buffers, premature wait, or sequential stream reads | Concurrent asynchronous draining or separate output files, with a time limit |
| Command continues after wait timeout | Waiting limit is not termination | Inspect/read/stop the original owned handle, not duplicate execution |
| Job missing in a later call | Parent session ended or a new process started | Use supported tool lifecycle handles, not jobs as durable services |
| Console encoding setter fails | Host lacks console capability | Use explicit file/Process encoding where supported; do not swallow errors |
| Cannot overwrite PID/Host | Case-insensitive automatic variable collision | Use names such as `$childProcessId` or `$toolHostName` |

## 3. Executable verification strategy

### A. Parse without executing side effects

Use the target engine's Parser for a controlled `.ps1` before executing potentially state-changing code:

```powershell
$tokens = $null
$parseErrors = $null
$script = 'C:\tools\task.ps1'
[System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$parseErrors) | Out-Null
if ($parseErrors.Count -gt 0) {
    $parseErrors | Select-Object Message, Extent
    throw 'Script has parse errors'
}
```

Parsing verifies syntax only. It does not prove command availability, parameter binding, permission, or task success. Use the actual supported 7.x version.

### B. Path and encoding round trips

- Use a randomly named task-owned temporary directory. Cover spaces, Unicode, brackets, parentheses, `&`, `$`, and apostrophes permitted in Windows names.
- Write exact encoding, read with `-LiteralPath -Raw -Encoding UTF8`, then compare strings and bytes.
- Verify BOM presence/absence separately, not only Console appearance.
- Probe Python/Node argv as JSON and compare **count, order, and values**. Include empty arguments, embedded quotes, and trailing slashes. Report Legacy-mode differences without false portability claims.
- Include non-ASCII and non-BMP characters. Construct fixtures from code points or language escapes when source-encoding independence matters; do not remove Unicode coverage.

### C. Failure propagation

- Use a controlled child returning `exit 7`; verify the parent immediately observes 7.
- Trigger `-ErrorAction Stop` with a task-owned missing path and verify both catch and finally execute.
- Verify generated outputs or real service behavior, not merely entry-point exit codes.
- Do not create unnecessary services for validation. Retain and clean up only PIDs created by this task.

## 4. Bundled self-test

`Test-PowerShellInvocation.ps1` covers:

1. Minimum-version/Core requirements, exact-major guard, and a verified 7.x child engine.
2. Unicode/special-character paths and LiteralPath round trips.
3. Exact UTF-8 without/with BOM, UTF-16LE/binary bytes, and generated non-ASCII script execution without BOM.
4. JSON array shape and Unicode values.
5. Terminating cmdlet errors, native nonzero status, and EncodedCommand.
6. Start-Process waiting and ExitCode with fixed arguments.
7. Optional Python stdin UTF-8, modern empty/quoted argv, and the safe Legacy-mode subset within 7.x.
8. Native byte redirection on 7.4+; earlier 7.x versions explicitly skip it without using another engine.
9. Restoration of Console/environment state and removal of the test's temporary directory.

The script needs no third-party testing framework, network, package installation, profile/policy change, or persistent service. It demonstrates covered behavior only on the actual engine/host, not every third-party CLI or agent runner.

## 5. Invocation acceptance checklist

- [ ] Engine is 7.x/Core, child paths are verified, and no old engine, file association, compatibility session, or automatic fallback is used.
- [ ] CWD and fresh/persistent tool semantics are known.
- [ ] Executable and arguments are separate and trusted; no dynamic iex/interpreter source concatenation.
- [ ] Exact paths use LiteralPath or literal file APIs; failed directory changes stop execution.
- [ ] JSON/PowerShell/child-language escaping is applied once per layer, without copied Bash/cmd syntax.
- [ ] UTF-8 **boundaries** are clear: source, BOM, file encoding, and native streams are handled separately.
- [ ] Cmdlet exceptions and native exit codes are handled separately without global suppression.
- [ ] No cross-call assumptions about old variables, CWD, or environment activation.
- [ ] Formatting, truncation, or mixed streams have not corrupted machine-readable output.
- [ ] Waiting limits and execution limits are distinguished; unknown outcomes are inspected before retrying.
- [ ] Only task-owned resources are cleaned up; no name-based bulk termination or global reconfiguration.
- [ ] Outcomes and failure paths are verified, with untested cases reported honestly.

