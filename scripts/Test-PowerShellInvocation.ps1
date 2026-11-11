#Requires -Version 7.0
#Requires -PSEdition Core

[CmdletBinding()]
param(
    [string]$PythonExecutable
)

if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -ne 7) {
    throw 'PowerShell 7.x (Core) is required; no fallback is allowed.'
}

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$results = [System.Collections.Generic.List[object]]::new()
$utf8 = [System.Text.UTF8Encoding]::new($false)
$utf8Bom = [System.Text.UTF8Encoding]::new($true)
$unicodeText = ([string][char]0x4E2D) + ([string][char]0x6587) + ' ' + [char]::ConvertFromUtf32(0x1F680)
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path -Path $tempBase -ChildPath ('agent-ps-check-' + [guid]::NewGuid().ToString('N'))
$engine = Join-Path -Path $PSHOME -ChildPath 'pwsh.exe'
$probe = Join-Path -Path $PSScriptRoot -ChildPath 'argv_probe.py'
$oldOutputEncoding = $OutputEncoding
$oldConsoleInput = [Console]::InputEncoding
$oldConsoleOutput = [Console]::OutputEncoding
$oldPythonEncoding = $env:PYTHONIOENCODING
$initialLocation = (Get-Location).Path

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    if ($Expected -cne $Actual) {
        throw ('{0}; expected <{1}>, actual <{2}>' -f $Message, $Expected, $Actual)
    }
}

function Assert-Bytes {
    param([byte[]]$Expected, [byte[]]$Actual)
    Assert-Equal $Expected.Length $Actual.Length 'Byte lengths differ'
    for ($index = 0; $index -lt $Expected.Length; $index++) {
        Assert-Equal $Expected[$index] $Actual[$index] ('Byte differs at offset {0}' -f $index)
    }
}

function Invoke-Check {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body | Out-Null
        $results.Add([pscustomobject]@{ Name = $Name; Status = 'passed'; Detail = '' })
    }
    catch {
        $results.Add([pscustomobject]@{ Name = $Name; Status = 'failed'; Detail = $_.Exception.Message })
    }
}

function Add-Skip {
    param([string]$Name, [string]$Reason)
    $results.Add([pscustomobject]@{ Name = $Name; Status = 'skipped'; Detail = $Reason })
}

[IO.Directory]::CreateDirectory($tempRoot) | Out-Null
try {
    $OutputEncoding = $utf8
    [Console]::InputEncoding = $utf8
    [Console]::OutputEncoding = $utf8
    $env:PYTHONIOENCODING = 'utf-8'
    $specialDirectory = Join-Path -Path $tempRoot -ChildPath ($unicodeText + ' [1] & (test) $value O''Brien')
    [IO.Directory]::CreateDirectory($specialDirectory) | Out-Null

    Invoke-Check 'Child engine is PowerShell 7.x Core' {
        $source = '$PSVersionTable | Select-Object PSEdition, @{Name="Major";Expression={$_.PSVersion.Major}} | ConvertTo-Json -Compress'
        $payload = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($source))
        $json = & $engine -NoLogo -NoProfile -NonInteractive -EncodedCommand $payload
        $code = $LASTEXITCODE
        Assert-Equal 0 $code 'Child version query failed'
        $version = $json | ConvertFrom-Json -ErrorAction Stop
        Assert-Equal 'Core' $version.PSEdition 'Child edition is not Core'
        Assert-Equal 7 $version.Major 'Child major version is not 7'
    }

    Invoke-Check 'Verified engine path bypasses command shadowing' {
        function pwsh.exe { throw 'A bare command name was invoked' }
        $payload = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("Write-Output 'verified'"))
        $actual = & $engine -NoLogo -NoProfile -NonInteractive -EncodedCommand $payload
        $code = $LASTEXITCODE
        Assert-Equal 0 $code 'Verified engine invocation failed'
        Assert-Equal 'verified' ([string]$actual) 'The verified engine was not used'
    }

    Invoke-Check 'LiteralPath and exact UTF-8 round trip' {
        $path = Join-Path -Path $specialDirectory -ChildPath 'config[1].txt'
        [IO.File]::WriteAllText($path, $unicodeText, $utf8)
        Assert-True (Test-Path -LiteralPath $path -PathType Leaf) 'Exact file was not found'
        $actual = Get-Content -LiteralPath $path -Raw -Encoding UTF8 -ErrorAction Stop
        Assert-Equal $unicodeText $actual 'Unicode text changed'
        Assert-Bytes ($utf8.GetBytes($unicodeText)) ([IO.File]::ReadAllBytes($path))
        $resolved = (Resolve-Path -LiteralPath $path -ErrorAction Stop).ProviderPath
        Assert-Equal $path $resolved 'Resolved path changed'
    }

    Invoke-Check 'Set-Content literal filename and no extra newline' {
        $path = Join-Path -Path $specialDirectory -ChildPath 'content[2].txt'
        Set-Content -LiteralPath $path -Value $unicodeText -Encoding utf8NoBOM -NoNewline -ErrorAction Stop
        Assert-Equal $unicodeText (Get-Content -LiteralPath $path -Raw -Encoding UTF8) 'Text or newline changed'
        $bytes = [IO.File]::ReadAllBytes($path)
        $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191
        Assert-Equal $false $hasBom 'UTF-8 output unexpectedly contains a BOM'
    }

    Invoke-Check 'Explicit UTF-8 BOM bytes' {
        $path = Join-Path -Path $specialDirectory -ChildPath 'bom[3].txt'
        [IO.File]::WriteAllText($path, $unicodeText, $utf8Bom)
        $expected = [byte[]]($utf8Bom.GetPreamble() + $utf8Bom.GetBytes($unicodeText))
        Assert-Bytes $expected ([IO.File]::ReadAllBytes($path))
        Assert-Equal $unicodeText (Get-Content -LiteralPath $path -Raw -Encoding UTF8) 'BOM text changed'
    }

    Invoke-Check 'Explicit UTF-16LE and binary bytes' {
        $path = Join-Path -Path $specialDirectory -ChildPath 'utf16[4].txt'
        $encoding = [Text.Encoding]::Unicode
        [IO.File]::WriteAllText($path, $unicodeText, $encoding)
        $expected = [byte[]]($encoding.GetPreamble() + $encoding.GetBytes($unicodeText))
        Assert-Bytes $expected ([IO.File]::ReadAllBytes($path))
        Assert-Equal $unicodeText (Get-Content -LiteralPath $path -Raw -Encoding Unicode) 'UTF-16 text changed'
        $binaryPath = Join-Path -Path $specialDirectory -ChildPath 'binary[5].dat'
        $binary = [byte[]]@(0, 10, 13, 127, 128, 239, 255)
        [IO.File]::WriteAllBytes($binaryPath, $binary)
        Assert-Bytes $binary ([IO.File]::ReadAllBytes($binaryPath))
    }

    Invoke-Check 'JSON array shape and Unicode round trip' {
        $rows = @([pscustomobject]@{ Message = $unicodeText; Path = $specialDirectory })
        $json = ConvertTo-Json -InputObject $rows -Depth 5 -Compress
        Assert-True ($json.StartsWith('[')) 'Single-element collection did not remain an array'
        $decoded = @($json | ConvertFrom-Json -ErrorAction Stop)
        Assert-Equal 1 $decoded.Count 'JSON item count changed'
        Assert-Equal $unicodeText $decoded[0].Message 'JSON Unicode value changed'
        Assert-Equal $specialDirectory $decoded[0].Path 'JSON path changed'
    }

    Invoke-Check 'Literal working directory and finally restoration' {
        $before = (Get-Location).Path
        Push-Location -LiteralPath $specialDirectory -ErrorAction Stop
        try {
            Assert-Equal $specialDirectory (Get-Location).Path 'Working directory did not change'
        }
        finally {
            Pop-Location
        }
        Assert-Equal $before (Get-Location).Path 'Working directory was not restored'
    }

    Invoke-Check 'ErrorAction Stop reaches catch and finally' {
        $caught = $false
        $finalized = $false
        try {
            Get-Item -LiteralPath (Join-Path -Path $tempRoot -ChildPath 'definitely-missing.txt') -ErrorAction Stop | Out-Null
        }
        catch {
            $caught = $true
        }
        finally {
            $finalized = $true
        }
        Assert-True $caught 'Missing file was not caught'
        Assert-True $finalized 'Finally was not executed'
    }

    Invoke-Check 'Native exit 7 is preserved immediately' {
        $payload = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes('exit 7'))
        & $engine -NoLogo -NoProfile -NonInteractive -EncodedCommand $payload
        $code = $LASTEXITCODE
        Assert-Equal 7 $code 'Native exit code was not preserved'
    }

    if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
        Invoke-Check 'Manual native exit handling preserves host preference' {
            & {
                $PSNativeCommandUseErrorActionPreference = $true
                $payload = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes('exit 7'))
                $code = & {
                    $ErrorActionPreference = 'Stop'
                    $PSNativeCommandUseErrorActionPreference = $false
                    & $engine -NoLogo -NoProfile -NonInteractive -EncodedCommand $payload
                    $LASTEXITCODE
                }
                Assert-Equal 7 $code 'Manual exit-code check was skipped'
                Assert-Equal $true $PSNativeCommandUseErrorActionPreference 'Host preference was not preserved'
            }
        }
    }
    else {
        Add-Skip 'Manual native exit handling preserves host preference' 'Native error preference is unavailable in this PowerShell version'
    }

    Invoke-Check 'EncodedCommand uses UTF-16LE and preserves Unicode' {
        $source = '[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false); Write-Output ' + "'" + $unicodeText + "'"
        $payload = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($source))
        $actual = & $engine -NoLogo -NoProfile -NonInteractive -EncodedCommand $payload
        $code = $LASTEXITCODE
        Assert-Equal 0 $code 'EncodedCommand failed'
        Assert-Equal $unicodeText ([string]$actual) 'Encoded Unicode output changed'
    }

    Invoke-Check 'Start-Process Wait PassThru and ExitCode' {
        $payload = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes('exit 7'))
        $options = @{
            FilePath = $engine
            ArgumentList = @('-NoLogo', '-NoProfile', '-NonInteractive', '-EncodedCommand', $payload)
            WorkingDirectory = $tempRoot
            WindowStyle = 'Hidden'
            Wait = $true
            PassThru = $true
            ErrorAction = 'Stop'
        }
        $process = Start-Process @options
        try {
            Assert-True $process.HasExited 'Start-Process returned before exit'
            Assert-Equal 7 $process.ExitCode 'Process ExitCode was not preserved'
        }
        finally {
            if (-not $process.HasExited) {
                Stop-Process -Id $process.Id -ErrorAction Stop
                $process.WaitForExit()
            }
            $process.Dispose()
        }
    }

    Invoke-Check 'UTF-8 no-BOM script runs from a special-character path' {
        $script = Join-Path -Path $specialDirectory -ChildPath 'child[6].ps1'
        $source = '[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false); Write-Output ' + "'" + $unicodeText + "'"
        [IO.File]::WriteAllText($script, $source, $utf8)
        $actual = & $engine -NoLogo -NoProfile -NonInteractive -File $script
        $code = $LASTEXITCODE
        Assert-Equal 0 $code 'No-BOM script failed'
        Assert-Equal $unicodeText ([string]$actual) 'No-BOM script output changed'
    }

    if ([string]::IsNullOrWhiteSpace($PythonExecutable)) {
        $pythonCommand = Get-Command -Name python.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($pythonCommand) { $PythonExecutable = $pythonCommand.Source }
    }
    if (-not [string]::IsNullOrWhiteSpace($PythonExecutable)) {
        function Invoke-PythonStreamProbe {
            param([string]$StreamEncoding, [Text.Encoding]$Decoder)
            $startInfo = [Diagnostics.ProcessStartInfo]::new()
            $startInfo.FileName = $PythonExecutable
            $startInfo.UseShellExecute = $false
            $startInfo.CreateNoWindow = $true
            $startInfo.RedirectStandardOutput = $true
            $startInfo.RedirectStandardError = $true
            $startInfo.StandardOutputEncoding = $Decoder
            $startInfo.StandardErrorEncoding = $Decoder
            $startInfo.Environment['PYTHONIOENCODING'] = $StreamEncoding
            $startInfo.ArgumentList.Add('-c')
            $startInfo.ArgumentList.Add('import sys; sys.stdout.write("\u4e2d\u6587 stdout"); sys.stderr.write("\u4e2d\u6587 stderr")')
            $process = [Diagnostics.Process]::new()
            $process.StartInfo = $startInfo
            $started = $false
            try {
                $started = $process.Start()
                Assert-True $started 'Python process did not start'
                $stdoutTask = $process.StandardOutput.ReadToEndAsync()
                $stderrTask = $process.StandardError.ReadToEndAsync()
                if (-not $process.WaitForExit(15000)) { throw 'Python stream probe timed out' }
                $stdout = $stdoutTask.GetAwaiter().GetResult()
                $stderr = $stderrTask.GetAwaiter().GetResult()
                Assert-Equal 0 $process.ExitCode 'Python stream probe failed'
                $chinese = ([string][char]0x4E2D) + [char]0x6587
                Assert-Equal ($chinese + ' stdout') $stdout 'Native stdout changed'
                Assert-Equal ($chinese + ' stderr') $stderr 'Native stderr changed'
            }
            finally {
                if ($started -and -not $process.HasExited) {
                    $process.Kill()
                    $process.WaitForExit()
                }
                $process.Dispose()
            }
        }

        Invoke-Check 'Python UTF-8 stdout and stderr round trip' {
            Invoke-PythonStreamProbe -StreamEncoding 'utf-8' -Decoder $utf8
        }
        Invoke-Check 'GBK native stdout and stderr decode correctly' {
            Invoke-PythonStreamProbe -StreamEncoding 'gbk' -Decoder ([Text.Encoding]::GetEncoding(936))
        }

        Invoke-Check 'Python stdin code and stdout UTF-8 round trip' {
            $source = "print('" + $unicodeText + "')"
            $actual = $source | & $PythonExecutable -X utf8 -
            $code = $LASTEXITCODE
            Assert-Equal 0 $code 'Python stdin execution failed'
            Assert-Equal $unicodeText ([string]$actual) 'Python UTF-8 text changed'
        }

        Invoke-Check 'Python argv safe subset across engine modes' {
            $values = @('space value', $unicodeText, $specialDirectory, '$value & (literal)')
            $probeArgs = @('-X', 'utf8', $probe) + $values
            $json = & $PythonExecutable @probeArgs
            $code = $LASTEXITCODE
            Assert-Equal 0 $code 'argv probe failed'
            $actual = $json | ConvertFrom-Json -ErrorAction Stop
            Assert-Equal $values.Count $actual.argv.Count 'argv count changed'
            for ($index = 0; $index -lt $values.Count; $index++) {
                Assert-Equal $values[$index] $actual.argv[$index] ('argv changed at index {0}' -f $index)
            }
        }

        $argumentMode = Get-Variable -Name PSNativeCommandArgumentPassing -ErrorAction SilentlyContinue
        if ($PSVersionTable.PSVersion -ge [version]'7.3' -and $argumentMode -and $argumentMode.Value -in @('Windows', 'Standard')) {
            Invoke-Check 'Modern native argv retains empty quotes and trailing slash' {
                $values = @('', 'a"b', 'C:\path with spaces\', 'semi; & $HOME', $unicodeText)
                $probeArgs = @('-X', 'utf8', $probe) + $values
                $json = & $PythonExecutable @probeArgs
                $code = $LASTEXITCODE
                Assert-Equal 0 $code 'Modern argv probe failed'
                $actual = $json | ConvertFrom-Json -ErrorAction Stop
                Assert-Equal $values.Count $actual.argv.Count 'Modern argv count changed'
                for ($index = 0; $index -lt $values.Count; $index++) {
                    Assert-Equal $values[$index] $actual.argv[$index] ('Modern argv changed at index {0}' -f $index)
                }
            }
        }
        else {
            Add-Skip 'Modern native argv retains empty quotes and trailing slash' 'PowerShell 7.x predates 7.3 or uses Legacy argument passing; no engine fallback'
        }

        if ($PSVersionTable.PSVersion -ge [version]'7.4') {
            Invoke-Check 'Native stdout direct redirection preserves binary bytes' {
                $path = Join-Path -Path $specialDirectory -ChildPath 'redirected[7].bin'
                $source = 'import sys; sys.stdout.buffer.write(bytes([0,10,13,127,128,239,255]))'
                & $PythonExecutable -X utf8 -c $source > $path
                $code = $LASTEXITCODE
                Assert-Equal 0 $code 'Native binary producer failed'
                Assert-Bytes ([byte[]]@(0, 10, 13, 127, 128, 239, 255)) ([IO.File]::ReadAllBytes($path))
            }
        }
        else {
            Add-Skip 'Native stdout direct redirection preserves binary bytes' 'Requires PowerShell 7.4 or later'
        }
    }
    else {
        $reason = 'python.exe unavailable; use -PythonExecutable with a trusted absolute executable path'
        foreach ($checkName in @(
            'Python UTF-8 stdout and stderr round trip',
            'GBK native stdout and stderr decode correctly',
            'Python stdin code and stdout UTF-8 round trip',
            'Python argv safe subset across engine modes',
            'Modern native argv retains empty quotes and trailing slash',
            'Native stdout direct redirection preserves binary bytes'
        )) {
            Add-Skip $checkName $reason
        }
    }
}
finally {
    $OutputEncoding = $oldOutputEncoding
    [Console]::InputEncoding = $oldConsoleInput
    [Console]::OutputEncoding = $oldConsoleOutput
    $env:PYTHONIOENCODING = $oldPythonEncoding
    if (Test-Path -LiteralPath $tempRoot -PathType Container) {
        $resolved = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $tempRoot -ErrorAction Stop).ProviderPath)
        $expected = [IO.Path]::GetFullPath($tempRoot)
        $boundary = $tempBase.TrimEnd([char[]]@('\', '/')) + [IO.Path]::DirectorySeparatorChar
        $item = Get-Item -LiteralPath $resolved -Force -ErrorAction Stop
        if (-not [string]::Equals($resolved, $expected, [StringComparison]::OrdinalIgnoreCase) -or
            -not $resolved.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase) -or
            -not [IO.Path]::GetFileName($resolved).StartsWith('agent-ps-check-', [StringComparison]::Ordinal) -or
            ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'Refusing to clean up an unexpected temporary directory.'
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Stop
    }
}

Assert-Equal $initialLocation (Get-Location).Path 'Initial working directory changed'
Assert-True (-not (Test-Path -LiteralPath $tempRoot)) 'Temporary directory was not removed'
$failed = @($results | Where-Object { $_.Status -eq 'failed' })
$report = [ordered]@{
    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    Edition = $PSVersionTable.PSEdition
    Passed = @($results | Where-Object { $_.Status -eq 'passed' }).Count
    Failed = $failed.Count
    Skipped = @($results | Where-Object { $_.Status -eq 'skipped' }).Count
    TemporaryFilesRemoved = $true
    Results = @($results.ToArray())
}
$report | ConvertTo-Json -Depth 6
if ($failed.Count -gt 0) { throw ('{0} invocation checks failed' -f $failed.Count) }
