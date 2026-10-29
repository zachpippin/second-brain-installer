# Windows permissions

These steps were not executed on Windows while this installer was written. `scripts/install.ps1` is the entry point. gbrain runs in WSL 2. Obsidian is the Windows app from winget.

Native Windows gbrain was not verified. Do not tell the person that `bun install -g` in PowerShell or Git Bash is the supported path.

## windows-execution-policy

If PowerShell refuses to run `scripts/install.ps1`:

Tell the person to open PowerShell and run:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

If Windows asks for confirmation, they press Enter or choose Yes. This does not change the policy for other users.

It worked when `Get-ExecutionPolicy -Scope CurrentUser` prints `RemoteSigned`, `Unrestricted`, or `Bypass`, and the script starts.

## windows-wsl

Printed when `wsl.exe` is missing.

Tell the person:

1. A User Account Control prompt will appear. They choose Yes to allow the Windows feature change.
2. In an elevated PowerShell, the command is `wsl --install`.
3. Windows may require a restart. They restart, then open "Ubuntu" from the Start menu once.
4. Ubuntu asks them to create a UNIX username and password. That password stays on their machine. They do not send it to the agent.

It worked when `wsl -l -q` lists a distribution.

## windows-wsl-distro

Printed when WSL exists but no distribution is installed.

Tell the person to install Ubuntu from the Microsoft Store, or run `wsl --install -d Ubuntu`, accept any User Account Control prompt, finish the first-launch username, then re-run `scripts/install.ps1`.

It worked when `wsl -l -q` prints `Ubuntu`.

## windows-winget

Printed when `winget.exe` is missing.

Tell the person to install App Installer from the Microsoft Store, then re-run the script.

It worked when `winget --version` prints a version.

## windows-obsidian-installer

winget may show a User Account Control prompt and a SmartScreen or installer window.

Tell the person:

1. If User Account Control appears, choose Yes only for the Obsidian install.
2. If SmartScreen says Windows protected your PC, choose More info, then Run anyway, only if the publisher is the Obsidian install they just started.
3. Finish the installer. Accept the default per-user location if it offers one.

It worked when `winget list --id Obsidian.Obsidian --exact` shows Obsidian.

## windows-obsidian-upgrade

Automatic replacement of a Windows Obsidian install was not verified, and winget does not give this installer a tested rollback. The daily job updates gbrain inside WSL only.

Run `scripts/update.ps1 -UpgradeObsidian` only after the person agrees to the User Account Control prompt. If the upgrade fails, do not claim the old installer was restored. The version printed before the upgrade is the record.

## windows-task-scheduler

Printed when registering `SecondBrainSync` or `SecondBrainUpdate` fails.

Tell the person to open Task Scheduler, confirm their user can create tasks, and re-run `scripts/install.ps1`. A User Account Control prompt means they choose Yes.

It worked when `Get-ScheduledTask -TaskName SecondBrainSync` shows a task.
