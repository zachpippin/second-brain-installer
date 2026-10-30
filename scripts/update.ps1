#Requires -Version 5.1
<#
.SYNOPSIS
  Update gbrain inside WSL. Record the Windows Obsidian version before any winget upgrade.
#>
[CmdletBinding()]
param(
  [string]$Distro = 'Ubuntu',
  [switch]$UpgradeObsidian
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
  Write-Error 'update.ps1 is the Windows entry point. On macOS or Linux run scripts/update.sh'
  exit 2
}

$repoWin = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repoWsl = (& wsl.exe -d $Distro -- wslpath -a $repoWin).Trim()
& wsl.exe -d $Distro -- bash -lc "cd '$repoWsl' && scripts/update.sh --component gbrain"
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$listed = & winget.exe list --id Obsidian.Obsidian --exact --accept-source-agreements
Write-Output 'update: obsidian-windows-before'
Write-Output $listed

if (-not $UpgradeObsidian) {
  Write-Output 'update: Windows Obsidian was not upgraded.'
  Write-Output 'update: winget rollback is not verified, so the daily job updates gbrain only.'
  Write-Output 'update: re-run with -UpgradeObsidian after reading docs/permissions-windows.md.'
  exit 0
}

Write-Output 'install: PERMISSION windows-obsidian-upgrade'
& winget.exe upgrade --id Obsidian.Obsidian --exact --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -ne 0) {
  Write-Output 'update: winget upgrade failed. The previous installer was not restored automatically.'
  exit 1
}
$after = & winget.exe list --id Obsidian.Obsidian --exact --accept-source-agreements
Write-Output 'update: obsidian-windows-after'
Write-Output $after
Write-Output 'update: done'
