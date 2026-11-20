---
name: powershell-invocation
description: 'Compose, run, or debug PowerShell 7.x (pwsh) commands on Windows, especially shell tool calls involving native CLI arguments, exit codes, paths, encoding, or process waits.'
---

# PowerShell invocation

## Ordinary call: run it directly

Use the tool's shell and working-directory fields. Select `pwsh.exe`; if the engine is unknown, check `$PSVersionTable` once for Core and major 7. If unavailable, report the blocker; do not fall back to Windows PowerShell or a compatibility session.

- **Run:** `git.exe status --short` needs no wrapper, discovery, encoding setup, or self-test. Assume fresh calls; keep required setup with its command.
- **Read:** `Get-Content -LiteralPath '.\config[1].json' -Raw` reads that exact name. Give `rg` a search path (`.` or narrower); otherwise a noninteractive runner may search stdin. Batch independent reads only if their results stay distinguishable.
- **Pass values:** use `& $exe @nativeArgs` for a variable or quoted executable path, one element per argument. Single-quote literals; never evaluate a constructed command string.
- **Edit:** prefer a focused patch; preserve encoding, BOM, and line endings. Without an editor, make the smallest permitted change. Use a script for complex logic and a supported file input for large data.
- **Recursive move/delete:** verify resolved source and destination paths, including links/junctions, stay within the intended boundary. If uncertain, stop. Keep the operation in PowerShell end to end.

## When another step depends on the result

- **Cmdlet:** use `-ErrorAction Stop` on the required operation. **Native CLI:** `&&` works for zero-success pipelines; otherwise capture `$LASTEXITCODE` immediately and interpret the program's contract. A newline or `;` is not a guard. `rg` exit 1 means no match; `git diff --exit-code` exit 1 means differences.
- **Still running:** a wait expiring is not an exit. Read the original handle before retrying, especially after a write; stop only a verified, task-owned process.

## Read only for the issue at hand

| First symptom or requirement | Read |
|---|---|
| Argument split, embedded quote, child shell, batch setup | [Arguments and parsing](./references/01-invocation-and-parsing.md) |
| Wrong file, lost CWD/environment, missing or shadowed command | [Paths and environment](./references/02-paths-and-environment.md) |
| Garbled text, broken JSON shape, binary output | [Encoding and data](./references/03-encoding-and-data.md) |
| Unexpected status, incomplete output, timeout or background process | [Exit codes and processes](./references/04-errors-output-and-processes.md) |
