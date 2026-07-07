[CmdletBinding()]
param(
    [string]$GodotExe = $env:GODOT_EXE,
    [switch]$WaitForExit
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$logsDir = Join-Path $scriptDir "logs"
$null = New-Item -ItemType Directory -Path $logsDir -Force
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
    $defaultExe = "C:\Users\scott\Desktop\Godot_v4.7-stable_win64.exe"
    if (Test-Path $defaultExe) {
        $GodotExe = $defaultExe
    }
}

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
    throw "Set GODOT_EXE or pass -GodotExe with the Godot 4.7 executable path."
}

if (-not (Test-Path $GodotExe)) {
    throw "Godot executable not found: $GodotExe"
}

$godotExePath = (Resolve-Path $GodotExe).Path
$workingDirectory = $projectRoot
$argumentTokens = @(
    "--path",
    $projectRoot
)
$argumentList = '--path "{0}"' -f $projectRoot
$stdoutPath = Join-Path $logsDir "godot_stdout_$timestamp.log"
$stderrPath = Join-Path $logsDir "godot_stderr_$timestamp.log"
$launchLogPath = Join-Path $logsDir "launch_$timestamp.log"
$commandText = '"' + $godotExePath + '" ' + (($argumentTokens | ForEach-Object {
    if ($_ -match '\s') {
        '"' + $_ + '"'
    } else {
        $_
    }
}) -join " ")

@(
    "Launching Zombie Barricade Prototype smoke test target..."
    "Godot executable: $godotExePath"
    "Project path: $projectRoot"
    "Working directory: $workingDirectory"
    "Command: $commandText"
    "Stdout log: $stdoutPath"
    "Stderr log: $stderrPath"
    "Launch log: $launchLogPath"
    "Window: uses project default (720x1280)"
    "Use with project/tests/computer_use/computer_use_smoke_test.md."
) | Set-Content -Path $launchLogPath

Write-Host "Launching Zombie Barricade Prototype smoke test target..."
Write-Host "Godot:   $godotExePath"
Write-Host "Project: $projectRoot"
Write-Host "Workdir: $workingDirectory"
Write-Host "Window:  uses project default (720x1280)"
Write-Host "Stdout:  $stdoutPath"
Write-Host "Stderr:  $stderrPath"
Write-Host "Log:     $launchLogPath"
Write-Host ""
Write-Host "Use with project/tests/computer_use/computer_use_smoke_test.md."

$process = Start-Process `
    -FilePath $godotExePath `
    -ArgumentList $argumentList `
    -WorkingDirectory $workingDirectory `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError $stderrPath `
    -PassThru

if ($WaitForExit) {
    $process | Wait-Process
    Add-Content -Path $launchLogPath -Value "Process exit code: $($process.ExitCode)"
    Write-Host "Godot exited with code: $($process.ExitCode)"
} else {
    Add-Content -Path $launchLogPath -Value "Launched PID: $($process.Id)"
    Write-Host "Launched PID $($process.Id)."
}
