#Requires -Version 5.1
<#
.SYNOPSIS
  Remove the Windows scheduled tasks and the WSL jobs. Notes stay unless -RemoveVault.
#>
[CmdletBinding()]
param(
  [string]$Distro = 'Ubuntu',
  [switch]$RemoveVault
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
  Write-Error 'uninstall.ps1 is the Windows entry point. On macOS or Linux run scripts/uninstall.sh'
  exit 2
}

foreach ($name in @('SecondBrainSync', 'SecondBrainUpdate')) {
  Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
  Write-Output "uninstall: task $name removed"
}

$repoWin = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repoWsl = (& wsl.exe -d $Distro -- wslpath -a $repoWin).Trim()
$flag = ''
if ($RemoveVault) {
  $flag = '--remove-vault'
}
& wsl.exe -d $Distro -- bash -lc "cd '$repoWsl' && scripts/uninstall.sh $flag"
exit $LASTEXITCODE
