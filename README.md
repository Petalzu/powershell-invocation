# powershell-invocation

A skill for concise, reliable PowerShell 7.x / Core execution on Windows. Start with [SKILL.md](./SKILL.md); load references only for a relevant problem.

## Execution style

- Routine calls usually take 1–5 readable lines. Reuse verified context and run known commands directly.
- Use the tool's shell/CWD settings and focused editing tools. Keep large file bodies out of commands.
- Remove unnecessary setup as a call grows; use a helper for substantial logic rather than compressing it into a long one-liner.
- Preserve literal paths, argument boundaries, failure status, file formats, and ownership of background processes.
- Configure encoding or advanced process handling only when the task requires it.

PowerShell 7.x is required throughout, including child processes. Windows PowerShell, compatibility sessions, and automatic engine fallback are unsupported. Existing tool permissions and user instructions take precedence.

## Install and invoke

Repository: [Petalzu/powershell-invocation](https://github.com/Petalzu/powershell-invocation) (private; authorized access required).

Keep [SKILL.md](./SKILL.md), [references](./references), and [scripts](./scripts) together in a folder named `powershell-invocation`. Review an existing installation before replacing it; exclude `.git`, credentials, and unrelated configuration.

| Intended host/scope | Installation directory |
|---|---|
| Personal GitHub Copilot | `%USERPROFILE%\.copilot\skills\powershell-invocation` |
| Personal VS Code Codex harness | `%USERPROFILE%\.agents\skills\powershell-invocation` |
| Repository-local skill | `.github\skills\powershell-invocation` at the repository root |

These locations follow the [recorded VS Code documentation](./references/07-official-sources.md); other hosts may discover different locations. Check discovery in a fresh chat in the intended host. Automatic discovery and explicit invocation remain enabled by default; discovery does not guarantee selection for every task. In a host with the slash-command interface, invoke `/powershell-invocation` and describe the task.

## References

| Need | Read |
|---|---|
| Quoting, child processes, native argv, batch setup | [Invocation and parsing](./references/01-invocation-and-parsing.md) |
| Paths, CWD, environment, discovery | [Paths and environment](./references/02-paths-and-environment.md) |
| Garbled text, JSON/CSV, byte integrity | [Encoding and data](./references/03-encoding-and-data.md) |
| Failures, streams, timeouts, background processes | [Errors and processes](./references/04-errors-output-and-processes.md) |
| Short command patterns and tool adaptation | [Tools and recipes](./references/05-agent-tools-and-recipes.md) |
| A specific failure | [Troubleshooting](./references/06-troubleshooting-and-checklist.md) |
| Official evidence and version boundaries | [Sources and validation](./references/07-official-sources.md) |

## Validate

From this skill's directory in PowerShell 7.x:

```powershell
& '.\scripts\Test-PowerShellInvocation.ps1'
```

The [self-test](./scripts/Test-PowerShellInvocation.ps1) reports JSON pass/fail/skip counts and cleans its own temporary directory. It checks engine identity, Unicode paths/source/argv, file encodings, binary bytes, JSON shape, native failures, process status, and stream decoding. It uses no network, package installation, profile/policy changes, or persistent services.

Python is optional; missing Python skips its checks. To select an existing interpreter, pass `-PythonExecutable` with its trusted absolute path. Python examples using `-X utf8` require Python 3.7+. Never pass secrets to the [argv probe](./scripts/argv_probe.py), which prints its arguments.

See the [validation record](./references/07-official-sources.md) for exact results and limitations. The self-test is a maintenance tool, not a prerequisite for routine commands.

## Maintenance

Preserve the 7.x-only boundary, Unicode coverage, valid frontmatter, and relative links. Prefer a narrow correction supported by an observed failure over another universal setup rule. Keep common examples short and move conditional detail to references. Preserve existing file formats; validate changed examples and behavior without claiming coverage of untested hosts.

## Licensing

No license has been selected. Do not assume reuse or redistribution rights beyond those granted by the owner. Official links refer to their respective publishers.
