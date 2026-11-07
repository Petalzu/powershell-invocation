# Agent Tool Adaptation and Invocation Recipes

Keep **PowerShell language rules** separate from the **current agent-tool contract**. Tool fields, defaults, and session behavior can change; follow the visible schema. Do not pass tool fields as `pwsh.exe` command-line options.

## 1. Adapt to the current PowerShell tool

Run these recipes only in **PowerShell 7.x / Core**. A tool named `powershell` does not prove the engine version. If unknown, check read-only first; select a verified `pwsh.exe` through supported tool configuration if needed. Otherwise stop: do not initialize, build, or test in an older engine or use it as an outer wrapper.

For Copilot tools exposing `powershell`, `read_powershell`, and `stop_powershell`:

| Field/behavior | Invocation rule |
|---|---|
| `command` | PowerShell source, not XML/HTML escaped. Use ordinary JSON escaping only when writing raw JSON |
| `description` | Brief task description without secrets; follow the schema's length limit |
| Initial directory | Each process starts at the tool-defined CWD. Reusing a shellId does not prove a prior directory change survives |
| Variables/environment | Independent calls do not retain previous variables, activation, or PATH changes; initialize explicitly |
| `mode: "sync"` | Wait for bounded work. Expiry of the initial wait may leave the command running |
| `initial_wait` | Initial wait in seconds, not a kill deadline. Current schema: 30-600; 30 for quick probes, usually 120+ for builds/tests/installs |
| `mode: "async"` | Use when doing independent work while it runs. Retain the returned `shellId` and read after completion notification |
| `detach: true` | Async services that must outlive the interaction only. Respect approval/sandbox restrictions; do not detach bounded tasks |
| Read/stop | Use the original returned `shellId`; do not invent IDs or restart the operation |
| Read delay | Longer waits when actively awaiting long work; short waits for one-off status checks. Prefer notifications to polling |
| Reuse after stopping | Initialize the new process again; the old environment is gone |
| Oversized output | Search saved logs and read bounded relevant lines, not entire files or repeated executions |

Omit unavailable fields rather than inventing APIs. Use native Windows paths for Windows command execution.

### Tool-call JSON example

This is **tool input, not PowerShell source**. Replace the directory with a confirmed task directory:

```json
{
  "command": "$ErrorActionPreference = 'Stop'; Set-Location -LiteralPath 'C:\\repo' -ErrorAction Stop; & git.exe --no-pager status --short; $code = $LASTEXITCODE; if ($code -ne 0) { throw \"git status failed: $code\" }",
  "description": "Inspect repository status",
  "mode": "sync",
  "initial_wait": 30
}
```

If the initial wait expires, obtain the final result through the original handle; do not submit the JSON again. Promise persistence across interactions only through a host-approved mechanism. Do not bypass lifecycle restrictions with `Start-Process`, cmd `start`, jobs, or scheduled tasks.

## 2. Minimum preflight plan

Know these values without necessarily printing them:

1. Verified 7.x/Core engine, no fallback, and fresh-process versus persistent-session semantics.
2. Confirmed CWD, executable, and argument boundaries.
3. Input/output encoding contracts and whether native processes, binary data, or non-ASCII source are involved.
4. Success criteria: exceptions, accepted exit codes, output files, or service readiness.
5. How to read status, stop, and clean up after timeout.

Reuse trusted context. Do not dump the environment for a short command, or change policy/install dependencies/retry work without evidence.

## 3. Small recipes

### A. Read an exact file and bounded log lines

```powershell
$path = 'C:\repo\Documents\config[1].json'
Get-Content -LiteralPath $path -Raw -Encoding UTF8 -ErrorAction Stop
```

Read a log tail and search literal text:

```powershell
$log = 'C:\repo\logs\build.log'
Get-Content -LiteralPath $log -Tail 80 -Encoding UTF8 -ErrorAction Stop
Select-String -LiteralPath $log -Pattern 'error' -SimpleMatch -Context 2, 3
```

Prefer available code-search tools. When shell searching is necessary, limit directory, extension, and output. For saved tool output, locate matches first and read narrow ranges instead of repeatedly requesting the whole log.

### B. Multiline Python without Bash heredocs

```powershell
$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false)
$OutputEncoding = $utf8
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$python = (Get-Command -Name python.exe -CommandType Application -ErrorAction Stop).Source
@'
import json
print(json.dumps({'message': '\u4e2d\u6587', 'ok': True}, ensure_ascii=False))
'@ | & $python -X utf8 -
$code = $LASTEXITCODE
if ($code -ne 0) { throw "Python failed: $code" }
```

Agree on UTF-8 for both the parent and Python. Here the source stays ASCII while escaped code points produce non-ASCII output; the self-test additionally sends actual generated non-ASCII source through stdin. If application data also needs stdin, use a `.py` file and pipe the data separately. Restore Console encoding in persistent shared sessions.

### C. Multiline Node

```powershell
$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false)
$OutputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$node = (Get-Command -Name node.exe -CommandType Application -ErrorAction Stop).Source
@'
const data = { message: '\u4e2d\u6587', ok: true };
process.stdout.write(JSON.stringify(data) + '\n');
'@ | & $node -
$code = $LASTEXITCODE
if ($code -ne 0) { throw "Node failed: $code" }
```

For `import`, select an appropriate module file or `--input-type=module` for the actual Node version. Do not misdiagnose module-loading errors as PowerShell quoting failures.

### D. Python virtual environment and targeted tests

```powershell
$ErrorActionPreference = 'Stop'
$root = 'C:\repo'
$python = Join-Path -Path $root -ChildPath '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
    throw "Expected environment missing: $python"
}
Set-Location -LiteralPath $root -ErrorAction Stop
& $python -X utf8 -m pytest '.\tests\test_paths.py' -q
$code = $LASTEXITCODE
if ($code -ne 0) { throw "Targeted tests failed: $code" }
```

Use the repository's existing environment and smallest relevant selector. Handle missing dependencies within authorization; silence alone does not justify reinstalling. Do not change project configuration merely to accommodate this skill.

### E. Visual Studio and batch toolchains

```powershell
& $env:ComSpec /d /c 'call "C:\Build Tools\vcvars64.bat" >nul && cd /d "C:\repo\src" && cl /nologo example.c'
$code = $LASTEXITCODE
if ($code -ne 0) { throw "MSVC build failed: $code" }
```

Paths are placeholders. Verify the installed batch path rather than guessing a toolchain version. Setup and compilation must share the same cmd process to inherit PATH/LIB/INCLUDE; do not split them across tool calls.

### F. Download a file without executing it

```powershell
$ErrorActionPreference = 'Stop'
$uri = 'https://example.com/artifact.zip'
$destination = 'C:\downloads\artifact.zip'
Invoke-WebRequest -Uri $uri -OutFile $destination -TimeoutSec 60 -ErrorAction Stop
Get-Item -LiteralPath $destination -ErrorAction Stop | Select-Object FullName, Length
```

Use a task-approved trusted URL and confirmed directory. Verify against a publisher checksum when required. PowerShell 7.x does not need an older-engine compatibility option. Never pipe a download into `Invoke-Expression`, disable TLS/certificate checks, or expose credentials in command logs.

### G. Read status instead of duplicating work

Retain the returned handle, wait for notification/read according to the tool contract, inspect the final exit code/logs, stop the original handle if necessary, and verify outputs/readiness. Initial acceptance is not task completion.

### H. Temporary files and cleanup

```powershell
$ErrorActionPreference = 'Stop'
$tempRoot = Join-Path -Path $env:TEMP -ChildPath ('agent-ps-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($tempRoot) | Out-Null
try {
    $file = Join-Path -Path $tempRoot -ChildPath 'input[1].txt'
    [IO.File]::WriteAllText($file, 'hello', [Text.UTF8Encoding]::new($false))
    Get-Content -LiteralPath $file -Raw -Encoding UTF8 -ErrorAction Stop
}
finally {
    if (Test-Path -LiteralPath $tempRoot -PathType Container) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction Stop
    }
}
```

Deletion is appropriate because this invocation created the randomly named directory and retained its exact absolute path. Do not broaden it to all TEMP, a repository, or unverified user input. Preserve deliverables; clean up only task-owned scratch.

## 4. Brief execution record

Record `engine/version; CWD; executable; encoding boundary; exit code/exception; verification evidence; untested cases`. For services, also retain the directory, handle/verified PID, logs, readiness evidence, and stop method. Never record secrets, complete sensitive arguments, or unrelated environment data.

