# Tools and short recipes

Choose the smallest pattern that satisfies the task. These examples assume a verified PowerShell 7.x shell and a confirmed working directory; they are independent alternatives, not one script to concatenate.

## Adapt to the actual tool

- Select `pwsh.exe` and the working directory with supported tool fields. A tool named `powershell` does not prove its engine version.
- Follow the visible schema. Fields such as `workdir`, `shellId`, `initial_wait`, `mode`, and `detach` belong to particular tools, not PowerShell; do not copy fields or wait ranges from another host.
- Reuse verified context. Do not prepend version checks, `Get-Command`, Console encoding setup, or preference resets to routine calls.
- Independent reads may share a bounded call or run through tool-level parallelism. When each result's status matters, keep separate tool results or check each command; the last command cannot summarize earlier failures.
- A fresh process loses previous variables, activation, and CWD changes. Keep necessary initialization beside its dependent command; use persistent sessions only when the tool supports them.
- Retain running handles and collect the final result. Do not restart work when its initial wait ends. Services need a supported lifecycle and verified readiness.
- Report the task outcome and material limitations. Include engine, encoding, and process details only when they explain the result.

## File editing and command size

Apply the [entrypoint rules](../SKILL.md#file-editing-and-command-size). Use an available patch/editor for authored content, preserving file format and unrelated changes. Discover one once if needed; do not invent a missing tool's schema or loop discovery.

| Task | Route |
|---|---|
| Read/search a file or run a CLI | Direct short command |
| Modify a function/configuration/document | Focused edit with the editor/patch tool |
| Small data transformation or short loop | Inline PowerShell when clear |
| Substantial control flow or repeated automation | Existing script, or helper created with the editor |
| Large input/arguments | File/stdin/response-file protocol supported by the consumer |
| No callable editor | Available patch executable, small literal write, or genuine programmatic transformation within permissions |

For a helper already created with the editor:

```powershell
& '.\scripts\transform.ps1' -ConfigPath '.\config\transform.json'
```

Use a child `pwsh -File` only when isolation is needed. Moving the same large body into a shell command that writes the helper does not simplify it. Do not use Base64, minification, nested interpreters, or arbitrary append chunks to disguise length.

## Short recipes

### Inspect repository status

```powershell
git.exe status --short
```

### Find files before reading

```powershell
rg --files -g '*.ps1' -g '!vendor' '.\scripts'
```

### Search a bounded area

```powershell
rg -n --fixed-strings --glob '*.ps1' 'Invoke-Task' '.\scripts'
```

Exit 1 means no match; inspect other failures. Prefer a narrower path/pattern over discarding a large search result.

### Read a small file or a log tail

```powershell
Get-Content -LiteralPath '.\config[1].json' -Raw
```

```powershell
Get-Content -LiteralPath '.\logs\build.log' -Tail 60
```

### Read a known line range

```powershell
Get-Content -LiteralPath '.\src\worker.ps1' -TotalCount 100 | Select-Object -Skip 79
```

This reads lines 80–100 without loading the entire file. Do not apply early pipeline truncation to a build or test process.

### Run a test in the existing virtual environment

```powershell
& '.\.venv\Scripts\python.exe' -X utf8 -m pytest '.\tests\test_paths.py' -q
```

Use the project's actual test/environment. Missing dependencies require diagnosis, not automatic reinstallation. This final native invocation uses the tool's status; see [exit propagation](./04-errors-output-and-processes.md#native-exit-codes) for a standalone wrapper.

### Keep a zero-success dependency concise

```powershell
dotnet.exe restore && dotnet.exe build --no-restore
```

When the next step is PowerShell logic, inspect `$LASTEXITCODE` immediately instead. `;` or a newline alone is not a success guard.

For special cases, read only the relevant guidance: [batch setup/child code](./01-invocation-and-parsing.md), [encoding](./03-encoding-and-data.md), or [background processes](./04-errors-output-and-processes.md#processes-and-services).
