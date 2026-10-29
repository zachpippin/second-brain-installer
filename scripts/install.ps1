#Requires -Version 5.1
<#
.SYNOPSIS
  Windows entry point. gbrain runs in WSL. Obsidian is the Windows app.
#>
[CmdletBinding()]
param(
  [string]$Distro = 'Ubuntu',
  [string]$Vault
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Permission {
  param([string]$Id)
  Write-Output "install: PERMISSION $Id"
  Write-Output 'install: stop. Read docs/permissions-windows.md for that section.'
  Write-Output 'install: tell the person what to click or type, then re-run this command.'
}

if ($env:OS -ne 'Windows_NT') {
  Write-Error 'install.ps1 is the Windows entry point. On macOS or Linux run scripts/install.sh'
  exit 2
}

$policy = Get-ExecutionPolicy -Scope CurrentUser
Write-Output "install: execution-policy $policy"
if ($policy -eq 'Restricted') {
  Write-Permission 'windows-execution-policy'
  exit 10
}

$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wsl) {
  Write-Permission 'windows-wsl'
  exit 10
}

$list = & wsl.exe -l -q
if ($LASTEXITCODE -ne 0 -or -not $list) {
  Write-Permission 'windows-wsl-distro'
  exit 10
}

$repoWin = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repoWsl = (& wsl.exe -d $Distro -- wslpath -a $repoWin).Trim()
if (-not $Vault) {
  $vaultWin = Join-Path $env:USERPROFILE 'SecondBrain'
} else {
  $vaultWin = $Vault
}
$vaultWsl = (& wsl.exe -d $Distro -- wslpath -a $vaultWin).Trim()

Write-Output "install: wsl distro $Distro"
Write-Output "install: vault $vaultWin"
& wsl.exe -d $Distro -- bash -lc "cd '$repoWsl' && scripts/install.sh --vault '$vaultWsl' --skip-obsidian --obsidian-host windows"
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if (-not $winget) {
  Write-Permission 'windows-winget'
  exit 10
}

Write-Output 'install: installing Obsidian with winget. A User Account Control prompt may appear.'
& winget.exe install --id Obsidian.Obsidian --exact --scope user --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -ne 0) {
  Write-Permission 'windows-obsidian-installer'
  exit 10
}

$linuxHome = (& wsl.exe -d $Distro -- bash -lc 'printf %s "$HOME"').Trim()
$sync = "$linuxHome/.local/share/second-brain/bin/sync-index.sh"
$update = "$linuxHome/.local/share/second-brain/bin/update-index.sh"
$syncAction = New-ScheduledTaskAction -Execute 'wsl.exe' -Argument "-d $Distro -- bash -lc '$sync'"
$updateAction = New-ScheduledTaskAction -Execute 'wsl.exe' -Argument "-d $Distro -- bash -lc '$update'"
$syncTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration ([TimeSpan]::MaxValue)
$updateTrigger = New-ScheduledTaskTrigger -Daily -At '4:15am'
try {
  Register-ScheduledTask -TaskName 'SecondBrainSync' -Action $syncAction -Trigger $syncTrigger -Force | Out-Null
  Register-ScheduledTask -TaskName 'SecondBrainUpdate' -Action $updateAction -Trigger $updateTrigger -Force | Out-Null
} catch {
  Write-Permission 'windows-task-scheduler'
  exit 10
}

Write-Output 'install: phase jobs ok'
Write-Output 'install: done'
Write-Output "install: open $vaultWin in Obsidian"
