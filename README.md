# powershell-invocation

A skill for invoking **PowerShell 7.x / Core on Windows**. The [entrypoint](./SKILL.md) is sufficient for routine shell calls; it links directly to the relevant troubleshooting reference when needed. Windows PowerShell 5.1, compatibility sessions, and automatic engine fallback are not supported.

## Install and invoke

Keep [SKILL.md](./SKILL.md), [references](./references), and [scripts](./scripts) together in a `powershell-invocation` folder. Review any existing installation before replacing it. The [source repository](https://github.com/Petalzu/powershell-invocation) is private.

| VS Code host/scope | Directory |
|---|---|
| Personal GitHub Copilot | `%USERPROFILE%\.copilot\skills\powershell-invocation` |
| Personal Codex harness | `%USERPROFILE%\.agents\skills\powershell-invocation` |
| Repository-local | `.github\skills\powershell-invocation` |

Check discovery in a fresh chat in the intended host. Default automatic and explicit invocation remain enabled. Where slash commands are supported, try `/powershell-invocation`. Other hosts may discover skills differently; see [VS Code Agent Skills](https://code.visualstudio.com/docs/agent-customization/agent-skills).

## Maintainer checks

From the skill directory in PowerShell 7.x on Windows:

```powershell
& '.\scripts\Test-PowerShellInvocation.ps1'
```

The [offline self-test](./scripts/Test-PowerShellInvocation.ps1) returns JSON pass/fail/skip counts and removes its scratch directory. It checks argument boundaries, native status, path and byte integrity, and process handling. It does not install packages or change profiles or policy. If Python or ripgrep is absent, only its checks skip. `-PythonExecutable` selects an existing trusted interpreter (3.7+). The [argv probe](./scripts/argv_probe.py) prints arguments: use synthetic data only. Neither script is routine preflight.

See [version boundaries and validation](./references/07-official-sources.md) for official references and tested scope. No license has been selected; do not assume redistribution rights.
