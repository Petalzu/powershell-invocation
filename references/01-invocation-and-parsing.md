# Arguments and parsing

## Identify which parser changed the value

| Symptom | First action |
|---|---|
| Tool input fails before the shell starts | Follow the actual tool schema. Let the JSON serializer escape `\` and `"`; PowerShell receives the decoded string. JSON quoting does not make shell interpolation safe. |
| A path prints instead of running, or a spaced command is not found | Pass the executable alone to `&`; put switches and values in separate array elements. `& 'git --version'` looks up that whole name. |
| Unexpected `$`, apostrophe, or colon | Use `'O''Brien'` for literal text, `"${name}:suffix"` for deliberate expansion. Backslash is not PowerShell's quote escape. |
| A value beginning with `-` is treated as an option | Use the target's value-taking option or end-of-options marker where supported. A correctly quoted argument can still be an option to the application. |

For example, `$repoPath` stays one value even if it contains spaces or `&`:

```powershell
$nativeArgs = @('-C', $repoPath, 'status', '--short')
git.exe @nativeArgs
```

On Windows, PowerShell 7.3+ normally uses `Windows` native argument passing; some targets (including batch files) still use legacy parsing. On 7.0-7.2 or in `Legacy` mode an empty value, embedded `"`, or trailing `\` beside a quote may change. Check the actual mode **only if those values matter**. From this skill's directory, compare count, order and content with the [argv probe](../scripts/argv_probe.py); it prints its inputs, so use synthetic values only:

```powershell
python.exe -X utf8 '.\scripts\argv_probe.py' '' 'a"b' 'C:\space here\' 'semi; & $HOME'
```

This tests a normal executable, not a different program's parser. If the target disagrees, prefer its file/stdin/response-file interface. For explicit process control, .NET `ProcessStartInfo.ArgumentList.Add()` takes unquoted values; `Start-Process -ArgumentList` joins its array into one string. Do not repair data with `Invoke-Expression` or a dynamic `cmd /c` payload.

## Cross a shell boundary only when necessary

- **PowerShell script:** in the current shell use `& '.\scripts\task.ps1' -InputPath $inputPath`. If isolation is required, use the verified engine below. Host options precede `-File`; script arguments follow it. Use a file or serialized data for complex objects, not a generated `-Command` string.
- **Python, Node, .NET caller:** supply the verified absolute `pwsh.exe`, argument list and working directory via the process API, with shell parsing off. Stdin used as program source cannot also carry application data. In PowerShell a short literal here-string can carry source; Bash `<<EOF` and `< file` are not input redirection here.
- **Batch environment setup:** only when the toolchain requires it, use one trusted, fixed cmd payload for setup and its dependent command, e.g. `& $env:ComSpec /d /c 'call "C:\Build Tools\setup.bat" && tool.exe --version'`. Child environment changes do not return to PowerShell. Never forward file deletion/moves to cmd.

```powershell
& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -NonInteractive -File '.\scripts\task.ps1' -InputPath $inputPath
```

For a quick syntax check without running a changed script, use `Parser.ParseFile()` from `System.Management.Automation.Language`; inspect the returned parse errors. Parsing alone cannot validate argument binding or runtime behavior.
