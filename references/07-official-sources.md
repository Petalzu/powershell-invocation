# Official Sources, Version Boundaries, and Validation Record

Documentation review date: 2026-11-07. This skill supports **PowerShell 7.x/Core only**, with no older-engine execution guidance or automatic fallback. The rules summarize reviewed official bodies, parameter sections, and notes in original wording rather than reproducing documentation at length. Microsoft Learn `view=` selects a version; canonical/default links may redirect to newer versions, so preserve the relevant 7.x feature boundaries.

Coverage means the principal agent invocation methods, data boundaries, and common failures. It does not claim to enumerate every cmdlet, third-party argument parser, or terminal implementation. For an uncovered CLI, consult its official interface and verify minimal argv/byte behavior.

## 1. Invocation, quoting, and parsing

| Official source | Reviewed evidence | Skill requirement |
|---|---|---|
| [about_Parsing (7.5)](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_parsing?view=powershell-7.5) | Expression/argument modes, special characters, backticks, `--%`, 7.3 native argument changes | Separate parsing layers and argv; do not use `--%` for arbitrary dynamic input |
| [about_Quoting_Rules (7.5)](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_quoting_rules?view=powershell-7.5) | Single/double quotes, interpolation, `${name}:`, here-strings | Single-quote static values; place markers correctly; avoid Bash heredocs |
| [about_Operators (7.5)](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_operators?view=powershell-7.5) | `&` does not parse complete command strings; dot-sourcing differs from background execution | No `& 'git --version'`; dot-source only for intentional current-scope definitions |
| [about_Splatting (7.5)](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_splatting?view=powershell-7.5) | Hashtables for named parameters, arrays for positional/native arguments | Structured arguments rather than concatenated argv strings |
| [about_Pwsh (7.5)](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_pwsh?view=powershell-7.5) | File/Command/stdin, argument placement, UTF-16LE EncodedCommand, NonInteractive, exit semantics | Prefer -File; encode commands correctly; do not assume atomic stdin parsing |
| [about_Pwsh (7.6)](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_pwsh?view=powershell-7.6) | CommandWithArgs stabilization and EncodedCommand details | Treat CommandWithArgs as generally available in 7.5+, checking earlier 7.x support |
| [about_Requires](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_requires?view=powershell-7.5) | Execution prerequisites; Version is a minimum and edition can require Core | Require 7.0/Core, plus a runtime guard for exactly major version 7 |
| [Windows PowerShell Compatibility](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_windows_powershell_compatibility?view=powershell-7.5) | Explicit/implicit compatibility import can launch an older process; DisableImplicitWinCompat controls implicit import | No compatibility session or hidden fallback; use permitted session-specific prevention when needed |
| [about_Command_Precedence (7.5)](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_command_precedence?view=powershell-7.5) | Alias/function/cmdlet/external precedence, explicit paths, collisions | Verify entry points with Get-Command; use explicit native names |
| [Pipeline Chain Operators (7.5)](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_pipeline_chain_operators?view=powershell-7.5) | Pipelines containing cmdlets, functions, or native programs can be chained | Not native-only, and not arbitrary statements such as bare if blocks |

## 2. Paths, environment, and policy

| Official source | Reviewed evidence | Skill requirement |
|---|---|---|
| [about_Path_Syntax](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_path_syntax?view=powershell-7.5) | Absolute/relative/provider paths, separators, Win32 namespace | Native Windows paths; do not confuse URI/WSL/provider forms or treat long-path prefixes as universal fixes |
| [Get-Location](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-location?view=powershell-7.5#notes) | Runspace CWD can differ from Environment.CurrentDirectory | Explicit absolute paths and working directories for native/.NET calls |
| [Join-Path](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/join-path?view=powershell-7.5) | Provider separators, Resolve expansion/existence | Composition is not validation, confinement, or authorization |
| [Test-Path](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/test-path?view=powershell-7.5) | Leaf/Container, LiteralPath, null/blank behavior | Check exact paths/types, then still handle actual I/O failures |
| [Get-Content](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-content?view=powershell-7.5) | LiteralPath, Raw, Encoding, Tail, AsByteStream | Separate whole JSON, ordinary text, bounded logs, and bytes |
| [Environment Variables](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_environment_variables?view=powershell-7.5) | Process inheritance, scope, string values, 7.5 empty-string change | Initialize in the same call and restore shared-session state |
| [Execution Policies](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.5) | Safety feature rather than security boundary; scopes and Group Policy precedence | No default Bypass, permanent policy changes, or elevation; diagnose actual entry points |
| [cmd](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/cmd) | /d, /c, /k, quoting, special characters, chaining, AutoRun | Batch setup and target share a process; no untrusted `/c` interpolation |

## 3. Encoding and byte boundaries

| Official source | Reviewed evidence | Skill requirement |
|---|---|---|
| [Character Encoding (7.5)](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_character_encoding?view=powershell-7.5) | 7.x UTF-8/no-BOM defaults, BOM choices, appending, OutputEncoding does not set file encoding | Diagnose each boundary; default scripts to no BOM and explicitly encode precise outputs |
| [Preference Variables (7.5)](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables?view=powershell-7.5) | OutputEncoding governs native stdin and should usually align with Console.InputEncoding; scope matters | Keep file encoding separate from console/pipe settings |
| [Console.OutputEncoding](https://learn.microsoft.com/en-us/dotnet/api/system.console.outputencoding?view=net-9.0) | Console encoding, locale defaults, setter exceptions | Do not assume a console-less host supports setters; distinguish font rendering from bytes |
| [chcp](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/chcp) | Active console code page, already-running program behavior, font limitations | Not a universal file/process/tool-decoding switch |
| [File.WriteAllText](https://learn.microsoft.com/en-us/dotnet/api/system.io.file.writealltext?view=net-9.0) | Explicit Encoding overloads and overwrite/truncation behavior | Control BOM and confirm exact destination/overwrite intent |
| [ConvertTo-Json](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertto-json?view=powershell-7.5) | Object serialization, depth, version-added options | Preserve objects before serialization; control depth and array shape |
| [Python command line/environment](https://docs.python.org/3/using/cmdline.html#envvar-PYTHONIOENCODING) | -c, stdin source, UTF-8 mode, standard-stream overrides, Windows console exceptions | Agree on parent/child encoding; -u is buffering, not encoding |
| [Node CLI](https://nodejs.org/api/cli.html) | Stdin `-`, arguments, module entry points | Here-string source and version-appropriate module mode |

## 4. Errors, output, and lifecycle

| Official source | Reviewed evidence | Skill requirement |
|---|---|---|
| [Try/Catch/Finally](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_try_catch_finally?view=powershell-7.5) | Terminating errors, catch matching, finally | Use Stop for required cmdlet operations and do not swallow errors |
| [Automatic Variables](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables?view=powershell-7.5) | Status/exit variables, File/Command semantics, PID/PSScriptRoot | Save the correct state immediately; avoid stale values and variable collisions |
| [Native error preference](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables?view=powershell-7.5#psnativecommanduseerroractionpreference) | Argument modes and configurable native nonzero/ErrorAction behavior; default false | Separate ErrorAction from native status and interpret special tools locally |
| [Redirection (7.5)](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_redirection?view=powershell-7.5) | Six streams, progress exception, 7.4 byte preservation, merged stderr becomes text, width | No binary-through-text processing or JSON/diagnostic mixing |
| [What's New in PowerShell 7.4](https://learn.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-74?view=powershell-7.5) | Native byte-pipe feature became generally available | Mark the 7.4 threshold explicitly |
| [Experimental Features](https://learn.microsoft.com/en-us/powershell/scripting/learn/experimental-features?view=powershell-7.5) | Experimental availability differs from general availability | Do not assume experimental APIs are enabled |
| [Start-Process](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process?view=powershell-7.5) | Joined ArgumentList, Wait/PassThru, WorkingDirectory, process-tree waits, host limitations | No false argv guarantees; inspect Process.ExitCode; respect tool lifecycle limits |
| [Wait-Process](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/wait-process?view=powershell-7.5) | Local waits and timeout errors without termination | Distinguish waiting from execution/termination limits |
| [Stop-Process](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/stop-process?view=powershell-7.5) | Local IDs, permissions, confirmation | Stop owned verified PIDs, never name-based bulk termination |
| [about_Jobs](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_jobs?view=powershell-7.5) | Parent-session termination, serialization, thread/process isolation | Jobs are not durable cross-call services |
| [Wait-Job](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/wait-job?view=powershell-7.5) | Wait states/timeouts and returned job objects | Inspect state, receive results, and do not assume internal native success |
| [robocopy return codes](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy#exit-return-codes) | **8 or higher** means at least one copy failure | Use `-ge 8`, not an incorrect `-gt 8` copied from another example |

## 5. Programmatic hosts and skill format

| Official source | Reviewed evidence | Skill requirement |
|---|---|---|
| [ProcessStartInfo.ArgumentList](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.processstartinfo.argumentlist?view=net-9.0) | Values need no pre-escaping; Arguments and ArgumentList are mutually exclusive; builds OS command line | Distinguish from Start-Process; still validate target input semantics |
| [Process.StandardOutput](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.standardoutput?view=net-9.0) | Redirect/UseShellExecute configuration; premature waits and sequential stream draining can deadlock | Concurrent draining or logs; distinguish exit from stream EOF |
| [Parser.ParseFile](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.language.parser.parsefile?view=powershellsdk-7.4.0) | AST/tokens/errors without execution | Check syntax without side effects; parsing is not behavioral validation |
| [Python subprocess](https://docs.python.org/3/library/subprocess.html) | argv, shell=False, encoding, check, run timeout kill/wait versus Popen behavior | Explicit encoding and distinct timeout cleanup semantics |
| [Node child_process](https://nodejs.org/api/child_process.html) | spawn/execFile/shell distinctions, buffer limits, batch files, environment casing | Explicit engine/argv; handle error/status/close; avoid dynamic exec strings |
| [VS Code Agent Skills](https://code.visualstudio.com/docs/agent-customization/agent-skills) | Copilot and Codex personal directories, default invocation controls, progressive loading, and fresh-chat verification (reviewed 2026-11-11) | Preserve automatic and user invocation defaults; install for each intended harness and verify discovery |

Additional reviewed project references: [git diff --exit-code](https://git-scm.com/docs/git-diff#Documentation/git-diff.txt---exit-code) and [ripgrep official manual source, EXIT STATUS](https://raw.githubusercontent.com/BurntSushi/ripgrep/master/crates/core/flags/doc/template.rg.1). `rg --quiet` may return 0 after a match despite another error; it is not proof every input was error-free. Consult installed-version help when executing.

Agent fields such as shellId, detach, and initial wait ranges come from the current tool schema. They are **not Microsoft Learn guarantees about PowerShell language behavior**.

## 6. Important version boundaries

| Feature | Boundary |
|---|---|
| Allowed engine | Only 7.x/Core and verified `pwsh.exe`; no older entry point, compatibility session, or automatic fallback |
| UTF-8 without BOM default | Standard in supported 7.x; no older-engine encoding branches |
| Pipeline `&&`/`||` | Supported in 7.x; chain pipelines rather than arbitrary statements |
| Native argument-passing preference | 7.3+; Windows/Standard/Legacy have different behavior |
| Native byte-preserving redirection and direct pipes | Generally available in 7.4+; merged stderr/text stages remove the guarantee |
| Native ErrorAction integration, Start-Process Environment, Encoding ansi | 7.4+ general-use baseline; earlier experimental availability must be checked |
| CommandWithArgs | Experimental in 7.4, generally available in 7.5; outer quoting still matters |
| Empty-string versus removed environment value | Changed in 7.5; do not assume identical earlier 7.x behavior |

A general-use baseline does not claim a feature never existed experimentally. Check the actual installed version/capability and official documentation.

## 7. Historical validation: 2026-11-07

All validation ran in PowerShell 7.x only. Historical older-engine tests are not support claims or permitted entry points.

| Check | Verified result |
|---|---|
| Source encoding | All 10 skill files use valid UTF-8 without BOM; runtime fixtures exercise non-ASCII data |
| Skill structure | Frontmatter, name/directory match, 159-line entry point, and 14 relative resource links passed |
| PowerShell examples | All 40 fenced examples parsed successfully in PowerShell 7.6.9/Core |
| Other examples | 2 JSON, 1 Python, and 1 JavaScript code block passed syntax checks; the multiline Python/Node recipes also preserved their expected Unicode JSON values at runtime |
| Bundled self-test | 16 passed, 0 failed, 0 skipped in PowerShell 7.6.9/Core, including the verified child engine and generated Unicode script |
| Engine requirements | Parser confirmed minimum 7.0/Core; the exact-major guard is the first runtime statement |
| Guard conditions | Four data-substitution checks passed inside 7.x, accepting only Core plus major version 7; no prohibited engine was launched |
| Older-engine entry points | None in the self-test or executable examples; prohibited names remain only in policy text |

The self-test removed its own temporary directory. No dependencies were installed, profiles/policies changed, or persistent services started. These results are specific to the tested engine and host, not every 7.x release or third-party program.

Non-ASCII fixtures use code-point and escape notation. This preserves actual Unicode paths, stdin, argv, and generated source coverage at runtime rather than replacing those checks with ASCII-only data.

Coverage includes LiteralPath, UTF-8 with/without BOM, UTF-16LE data, binary bytes, JSON shape, failure propagation, exit 7, EncodedCommand, Start-Process, Python stdin/argv, a no-BOM generated non-ASCII script, the 7.x child-engine check, and cleanup. UTF-16LE remains a valid data/EncodedCommand format; it does not imply use of an older engine.

Machine interfaces must isolate diagnostics/progress and verify the host's output protocol. Skill discovery does not guarantee automatic selection for every related request.

Untested: other 7.x minor versions, Linux/macOS, every third-party CLI, console-less/remote hosts, real MSVC builds, external downloads, and persistent-service approvals/lifetimes. Older engines are prohibited and are not run for verification.

## 8. Update validation: 2026-11-11

On the local Windows host, PowerShell 7.6.10/Core completed the revised offline self-test: **20 passed, 0 failed, 0 skipped**, including the verified-engine shadowing check, locally scoped native error preference, and separate UTF-8/GBK native stdout and stderr checks. The temporary directory was removed. A separate run without Python passed 14 checks and reported six individual skips. The local skill-creator validator accepted the frontmatter, and 44 fenced PowerShell examples and 31 relative resource links were checked. These results do not establish discovery or automatic selection in every client, or behavior on untested engines and hosts.

