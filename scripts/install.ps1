#Requires -Version 5.1
<#
.SYNOPSIS
  Windows entry point. gbrain runs in WSL. Obsidian is the Windows app.
#>
[CmdletBinding()]
param(
  [string]$Distro = 'Ubuntu',
  [string]$Vault,
  [switch]$NoJobs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Permission {
  param([string]$Id)
  Write-Output "install: PERMISSION $Id"
  Write-Output 'install: stop. Read docs/permissions-windows.md for that section.'
  Write-Output 'install: tell the person what to click or type, then re-run this command.'
}

function ConvertTo-WindowsArgument {
  param([Parameter(Mandatory = $true)][string]$Value)
  if ($Value -notmatch '[\s"]') {
    return $Value
  }
  $builder = New-Object System.Text.StringBuilder
  [void]$builder.Append('"')
  $slashes = 0
  foreach ($char in $Value.ToCharArray()) {
    if ($char -eq '\') {
      $slashes++
      continue
    }
    if ($char -eq '"') {
      [void]$builder.Append(('\' * (($slashes * 2) + 1)))
      [void]$builder.Append('"')
      $slashes = 0
      continue
    }
    if ($slashes -gt 0) {
      [void]$builder.Append(('\' * $slashes))
      $slashes = 0
    }
    [void]$builder.Append($char)
  }
  if ($slashes -gt 0) {
    [void]$builder.Append(('\' * ($slashes * 2)))
  }
  [void]$builder.Append('"')
  return $builder.ToString()
}

function ConvertTo-BashSingleQuoted {
  param([Parameter(Mandatory = $true)][string]$Value)
  $quote = "'"
  $escaped = $Value.Replace($quote, ($quote + '\' + $quote))
  return $quote + $escaped + $quote
}

function Get-WslScheduledTaskArgument {
  param(
    [Parameter(Mandatory = $true)][string]$Distro,
    [Parameter(Mandatory = $true)][string]$Script
  )
  # Task Scheduler parses Arguments with CommandLineToArgvW. Single quotes do
  # not keep a path with spaces together, and bash still needs its own quoting.
  $command = ConvertTo-BashSingleQuoted $Script
  return "-d $(ConvertTo-WindowsArgument $Distro) -- bash -lc $(ConvertTo-WindowsArgument $command)"
}

# scripts/test-lib.sh sets this to print one Task Scheduler argument and exit.
if ($env:SB_QUOTE_TASK_SCRIPT) {
  $quoteDistro = $Distro
  if ($env:SB_QUOTE_TASK_DISTRO) {
    $quoteDistro = $env:SB_QUOTE_TASK_DISTRO
  }
  Write-Output (Get-WslScheduledTaskArgument -Distro $quoteDistro -Script $env:SB_QUOTE_TASK_SCRIPT)
  exit 0
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
$jobFlag = ''
if ($NoJobs) {
  $jobFlag = '--no-jobs'
}
& wsl.exe -d $Distro -- bash -lc "cd '$repoWsl' && scripts/install.sh --vault '$vaultWsl' --skip-obsidian --obsidian-host windows $jobFlag"
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$existingObsidian = $null
foreach ($candidate in @(
    (Join-Path $env:LOCALAPPDATA 'Obsidian\Obsidian.exe'),
    (Join-Path $env:ProgramFiles 'Obsidian\Obsidian.exe')
  )) {
  if ($candidate -and (Test-Path -LiteralPath $candidate)) {
    $existingObsidian = $candidate
    break
  }
}
$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if (-not $existingObsidian -and $winget) {
  $listed = & winget.exe list --id Obsidian.Obsidian --exact --accept-source-agreements 2>$null
  if ($LASTEXITCODE -eq 0 -and $listed -match 'Obsidian') {
    $existingObsidian = 'winget:Obsidian.Obsidian'
  }
}
if (-not $existingObsidian -and -not $winget) {
  Write-Permission 'windows-winget'
  exit 10
}
if ($existingObsidian) {
  Write-Output "obsidian: using existing install at $existingObsidian"
  Write-Output "obsidian: leaving updates to Obsidian's own updater"
} else {
  Write-Output 'install: installing Obsidian with winget. A User Account Control prompt may appear.'
  & winget.exe install --id Obsidian.Obsidian --exact --scope user --accept-package-agreements --accept-source-agreements
  if ($LASTEXITCODE -ne 0) {
    Write-Permission 'windows-obsidian-installer'
    exit 10
  }
}

if ($NoJobs) {
  Write-Output 'install: jobs skipped'
  Write-Output 'install: done'
  Write-Output "install: open $vaultWin in Obsidian"
  exit 0
}

$linuxHome = (& wsl.exe -d $Distro -- bash -lc 'printf %s "$HOME"').Trim()
$sync = "$linuxHome/.local/share/second-brain/bin/sync-index.sh"
$update = "$linuxHome/.local/share/second-brain/bin/update-index.sh"
$syncAction = New-ScheduledTaskAction -Execute 'wsl.exe' -Argument (Get-WslScheduledTaskArgument -Distro $Distro -Script $sync)
$updateAction = New-ScheduledTaskAction -Execute 'wsl.exe' -Argument (Get-WslScheduledTaskArgument -Distro $Distro -Script $update)
$syncTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration ([TimeSpan]::MaxValue)
$updateTrigger = New-ScheduledTaskTrigger -Daily -At '4:15am'
try {
  Register-ScheduledTask -TaskName 'io.github.second-brain-installer.sync' -Action $syncAction -Trigger $syncTrigger -Force | Out-Null
  Register-ScheduledTask -TaskName 'io.github.second-brain-installer.update' -Action $updateAction -Trigger $updateTrigger -Force | Out-Null
} catch {
  Write-Permission 'windows-task-scheduler'
  exit 10
}

Write-Output 'install: phase jobs ok'
Write-Output 'install: done'
Write-Output "install: open $vaultWin in Obsidian"
