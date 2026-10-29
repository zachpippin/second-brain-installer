#Requires -Version 5.1
<#
.SYNOPSIS
  Windows doctor. gbrain status comes from WSL. Obsidian status comes from winget.
#>
[CmdletBinding()]
param(
  [string]$Distro = 'Ubuntu'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
  Write-Error 'doctor.ps1 is the Windows entry point. On macOS or Linux run scripts/doctor.sh'
  exit 2
}

$repoWin = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repoWsl = (& wsl.exe -d $Distro -- wslpath -a $repoWin).Trim()
& wsl.exe -d $Distro -- bash -lc "cd '$repoWsl' && scripts/doctor.sh"
$wslStatus = $LASTEXITCODE

Write-Output 'doctor: windows-obsidian'
$windowsApp = $null
foreach ($candidate in @(
    (Join-Path $env:LOCALAPPDATA 'Obsidian\Obsidian.exe'),
    (Join-Path $env:ProgramFiles 'Obsidian\Obsidian.exe')
  )) {
  if ($candidate -and (Test-Path -LiteralPath $candidate)) {
    $windowsApp = $candidate
    break
  }
}
if ($windowsApp) {
  Write-Output "doctor: obsidian-updates left to Obsidian's own updater ($windowsApp)"
}
& winget.exe list --id Obsidian.Obsidian --exact --accept-source-agreements
foreach ($name in @('io.github.second-brain-installer.sync', 'io.github.second-brain-installer.update', 'SecondBrainSync', 'SecondBrainUpdate')) {
  $task = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
  if ($task) {
    Write-Output "doctor: task $name $($task.State)"
  } else {
    Write-Output "doctor: task $name missing"
  }
}
exit $wslStatus
