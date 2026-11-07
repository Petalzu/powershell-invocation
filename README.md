# powershell-invocation

**PowerShell Invocation Standards for AI Agents**

An agent skill for reliable PowerShell command execution on Windows. It covers parsing, quoting, literal paths, UTF-8 and BOM handling, native arguments, exit codes, redirection, and process lifecycle management, with official references and an offline self-test.

> **PowerShell 7.x / Core only.** Windows PowerShell, `powershell.exe`, compatibility sessions, and automatic engine fallback are prohibited. If a verified 7.x engine is unavailable, stop and report the blocker.

## What is included

- A concise, progressively loaded [skill entry point](./SKILL.md).
- Seven detailed reference chapters with official documentation links.
- An offline [PowerShell self-test](./scripts/Test-PowerShellInvocation.ps1).
- A small [Python argv probe](./scripts/argv_probe.py).
- Unicode fixtures constructed at runtime from code points and escapes, preserving real non-ASCII path, source, stdin, and argv coverage.

This is a skill and reference collection, not a shell replacement or a complete catalog of every cmdlet. Tool permissions, approvals, organizational policies, and user instructions always take precedence.

## Requirements

| Component | Requirement |
|---|---|
| Operating system | Windows; examples use native Windows paths |
| PowerShell | Major version 7 and `PSEdition = Core`; use a verified `pwsh.exe` |
| Agent | A host that supports agent skills and their on-demand resource loading |
| Python | Optional for argv/stdin tests; the examples use Python 3.7+ UTF-8 mode |
| Node.js | Optional for documented Node recipes; not required by the bundled self-test |
| Git | Required only when cloning or maintaining this repository |

Minor-version features are explicitly gated: modern native argument passing requires 7.3+, native byte-preserving redirection requires 7.4+, and generally available `-CommandWithArgs` requires 7.5+. Missing features do not authorize an older engine.

## Repository layout

```text
powershell-invocation/
|-- README.md
|-- SKILL.md
|-- references/
|   |-- 01-invocation-and-parsing.md
|   |-- 02-paths-and-environment.md
|   |-- 03-encoding-and-data.md
|   |-- 04-errors-output-and-processes.md
|   |-- 05-agent-tools-and-recipes.md
|   |-- 06-troubleshooting-and-checklist.md
|   `-- 07-official-sources.md
`-- scripts/
    |-- Test-PowerShellInvocation.ps1
    `-- argv_probe.py
```

Keep `SKILL.md`, `references`, and `scripts` together. The skill name and containing installation directory must both be `powershell-invocation`.

## Installation

### Clone the repository

Repository: [Petalzu/powershell-invocation](https://github.com/Petalzu/powershell-invocation).

The repository is private, so cloning requires an authorized GitHub account. From PowerShell 7.x, run the following in your chosen parent directory:

```powershell
git.exe clone https://github.com/Petalzu/powershell-invocation.git
if ($LASTEXITCODE -ne 0) { throw 'Repository cloning failed.' }
Set-Location -LiteralPath '.\powershell-invocation' -ErrorAction Stop
```

### Personal installation for GitHub Copilot

Place the complete repository contents in:

```text
%USERPROFILE%\.copilot\skills\powershell-invocation\
```

The final entry point must be `.copilot\skills\powershell-invocation\SKILL.md`, not an extra nested repository directory.

If the repository is already cloned elsewhere, run the following from its root in a verified PowerShell 7.x session. It refuses to overwrite an existing installation:

```powershell
if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -ne 7) {
    throw 'PowerShell 7.x (Core) is required; no fallback is allowed.'
}
$source = (Get-Location).ProviderPath
$entry = Join-Path -Path $source -ChildPath 'SKILL.md'
if (-not (Test-Path -LiteralPath $entry -PathType Leaf)) {
    throw 'Run this command from the repository root.'
}
$destination = Join-Path -Path $HOME -ChildPath '.copilot\skills\powershell-invocation'
if (Test-Path -LiteralPath $destination) {
    throw 'An installation already exists. Review and update it separately.'
}
[IO.Directory]::CreateDirectory($destination) | Out-Null
foreach ($name in @('SKILL.md', 'references', 'scripts', 'README.md')) {
    Copy-Item -LiteralPath (Join-Path -Path $source -ChildPath $name) -Destination $destination -Recurse -ErrorAction Stop
}
```

Do not copy `.git`, credentials, or unrelated user configuration into a skill installation.

### Project-local installation

Copy the same files into `.github\skills\powershell-invocation` at the intended repository root. Keep the relative structure intact. Review any existing skill of the same name rather than overwriting it silently.

Other agents may use their own supported locations, such as `.agents\skills\powershell-invocation` or `.claude\skills\powershell-invocation`. Check the current host documentation rather than assuming all clients share discovery settings. See the [official source record](./references/07-official-sources.md).

## Usage

In a skill-aware host, invoke:

```text
/powershell-invocation
```

Then describe the command-execution task. The discovery description also allows an agent to select the skill for relevant PowerShell work. Installation and discovery do not guarantee selection on every request; explicitly invoke it when needed.

Start with [SKILL.md](./SKILL.md). Load detailed chapters only for the relevant topic:

| Topic | Reference |
|---|---|
| Quoting, splatting, entry points, here-strings, native argv, Python/Node callers | [Invocation and parsing](./references/01-invocation-and-parsing.md) |
| LiteralPath, UNC, CWD, command discovery, environments and policy | [Paths and environment](./references/02-paths-and-environment.md) |
| UTF-8, BOM, Console settings, text/JSON/CSV and binary integrity | [Encoding and data](./references/03-encoding-and-data.md) |
| Exceptions, exit codes, streams, Start-Process, jobs and timeouts | [Errors, output, and processes](./references/04-errors-output-and-processes.md) |
| Agent tool contracts, shell handles, builds/tests and practical templates | [Tools and recipes](./references/05-agent-tools-and-recipes.md) |
| Failure diagnosis and acceptance checks | [Troubleshooting and checklist](./references/06-troubleshooting-and-checklist.md) |
| Official evidence, feature versions and tested scope | [Official sources](./references/07-official-sources.md) |

## Run the self-test

From the repository root in PowerShell 7.x:

```powershell
if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -ne 7) {
    throw 'PowerShell 7.x (Core) is required; no fallback is allowed.'
}
$engine = Join-Path -Path $PSHOME -ChildPath 'pwsh.exe'
$test = Join-Path -Path (Get-Location).ProviderPath -ChildPath 'scripts\Test-PowerShellInvocation.ps1'
& $engine -NoLogo -NoProfile -NonInteractive -File $test
$code = $LASTEXITCODE
if ($code -ne 0) { throw "Self-test failed: $code" }
```

To choose a trusted Python executable, add `-PythonExecutable` with its absolute path after the script path. Without Python, Python-dependent checks are skipped rather than installing packages automatically.

The self-test emits a JSON report with engine version, pass/fail/skip counts, individual results, and cleanup status. It checks:

- The current and child engines are PowerShell 7.x/Core.
- Unicode/special-character paths and LiteralPath behavior.
- Exact UTF-8 without/with BOM, UTF-16LE data, and binary bytes.
- JSON array shape and Unicode values.
- ErrorAction Stop, catch/finally, and a deliberately returned native exit code 7.
- UTF-16LE EncodedCommand transport and Start-Process ExitCode.
- Generated non-ASCII PowerShell source without BOM.
- Optional Python stdin/argv and modern quoted/empty arguments.
- Native byte-preserving redirection on supported 7.x versions.

It uses a randomly named task-owned temporary directory and removes it afterwards. It does not use the network, install dependencies, modify execution policy/profile, or start persistent services. Never pass secrets to the argv probe because it prints its arguments.

## Validation scope

The skill was verified on PowerShell 7.6.9/Core: **16 self-tests passed, 0 failed, 0 skipped**. Its 40 PowerShell examples parsed, and metadata, resource links, and other-language examples were checked. See the [validation record](./references/07-official-sources.md) for details and limitations.

Those results are not a promise for every 7.x release, third-party program, console-less host, remote session, or operating system. No older engine is used for validation.

## Maintenance

- Keep prose, metadata, comments, and examples clear and consistent.
- Preserve the PowerShell 7.x-only policy and Unicode test coverage.
- Verify behavioral changes against official documentation and record precise version boundaries.
- Run targeted checks after script changes; preserve relative links and valid skill frontmatter.
- Treat fields such as `shellId`, `initial_wait`, and `detach` as host-specific tool contracts, not PowerShell parameters.

## Licensing

No license has been selected for this package. Do not assume reuse or redistribution rights beyond those explicitly granted by the owner. Official documentation links remain references to their respective publishers; this repository does not reproduce those documents wholesale.
