# Version boundaries and validation

Use this page to check a version-sensitive claim, not as a prerequisite for a shell call. The skill targets `pwsh.exe` on Windows, Core edition, major version 7; a minimum version alone does not establish that contract.

| Available by default | Boundary and evidence |
|---|---|
| 7.0+ | [Pipeline chain operators](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_pipeline_chain_operators?view=powershell-7.5). Ordinary [text-file output defaults to UTF-8 without BOM](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_character_encoding?view=powershell-7.5); native programs can use a different encoding. |
| 7.3+ | [Native argument passing](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_parsing?view=powershell-7.5): Windows normally uses `Windows` mode, with legacy behavior for some targets. |
| 7.4+ | [Direct native byte redirection](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_redirection?view=powershell-7.5); [native ErrorAction integration](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables?view=powershell-7.5#psnativecommanduseerroractionpreference) is stable but **off** by default. |
| 7.5+ | [An empty environment variable differs from a removed variable](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_environment_variables?view=powershell-7.5). |

Thresholds refer to general availability. Do not assume preview features or a particular host preference on an earlier engine.

## Contracts worth checking at the source

- **Execution:** [pwsh `-File` / `-Command` exit behavior](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_pwsh?view=powershell-7.5), [command precedence](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_command_precedence?view=powershell-7.5), [PowerShell vs .NET working directory](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-location?view=powershell-7.5#notes).
- **Native status:** [ripgrep manual and exit status](https://github.com/BurntSushi/ripgrep/blob/master/crates/core/flags/doc/template.rg.1), [git diff](https://git-scm.com/docs/git-diff#Documentation/git-diff.txt---exit-code), [robocopy return codes](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy#exit-return-codes).
- **Processes:** [Start-Process argument joining and waits](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process?view=powershell-7.5), [.NET ArgumentList](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.processstartinfo.argumentlist), [redirected streams and deadlocks](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.standardoutput).
- **Data:** [ConvertTo-Json](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertto-json?view=powershell-7.5), [Python stream encoding](https://docs.python.org/3/using/cmdline.html#envvar-PYTHONIOENCODING).

## Tested scope

The [offline self-test](../scripts/Test-PowerShellInvocation.ps1) exercises real child processes, synthetic Unicode paths/argv, text and binary bytes, and cleanup. Its JSON report distinguishes skipped optional checks from passes. Tool-specific shell selectors, wait handles, and skill discovery remain host contracts, not PowerShell guarantees.

On 2026-11-20, Windows with PowerShell 7.6.10/Core passed all 22 checks, with no failures or skips; scratch files were removed. This includes two cases beyond the 20-check baseline: an exact exit code across a failed dependency chain, and an explicit-path ripgrep search under redirected stdin. One host does not establish behavior on other 7.x releases, arbitrary native parsers, or automatic skill selection by every agent.
