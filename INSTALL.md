# Install this second brain

An agent follows this file from top to bottom. The person should not have to assemble the pieces. Stop only for the operating-system prompts in the permissions docs.

gbrain and Obsidian are separate projects. This installer is not affiliated with them. gbrain is not the npm package named `gbrain`.

## 0. Confirm the checkout

Work from the root of this repository. The scripts call each other by relative path.

```sh
scripts/install.sh --help
```

Windows agents use PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1
```

If that PowerShell process is blocked before the script starts, follow `windows-execution-policy` in [docs/permissions-windows.md](docs/permissions-windows.md). Do not loosen the policy for the whole machine. `CurrentUser` and `RemoteSigned` are enough.

## 1. Detect the operating system

macOS or Linux:

```sh
scripts/install.sh --phase detect
```

Expect `install: os macos` or `install: os linux`, then `install: phase detect ok`.

Windows: do not run the bash installer in Git Bash. Run `scripts/install.ps1`. It checks for Windows and for WSL. Native Windows gbrain is not the v1 path. Bun itself runs on Windows, and gbrain's published install is a POSIX Bun CLI. A Windows portability pull request in the gbrain repository (garrytan/gbrain#647) was closed without merging. WSL 2 is the path that matches the published install.

If detect prints `WSL detected`, Obsidian is installed on the Windows side by `install.ps1`. The bash script only indexes the vault.

## 2. Read the permissions doc before each later step

- Linux: [docs/permissions-linux.md](docs/permissions-linux.md)
- macOS: [docs/permissions-macos.md](docs/permissions-macos.md)
- Windows: [docs/permissions-windows.md](docs/permissions-windows.md)

Before you run a command that may prompt, tell the person what they will see, using that doc. If the command prints `install: PERMISSION <id>`, stop and use that section. Check the doc's "it worked" test before going on.

## 3. Install

Linux or macOS, all phases:

```sh
scripts/install.sh --vault "$HOME/SecondBrain"
```

Pass `--no-jobs` to skip the sync and update schedules. That is useful for a test run, or when the person does not want background jobs.

The default vault is `$HOME/SecondBrain`. Re-running does not overwrite notes that are already there. On macOS, a second run does not download the disk image again when the installed version already matches the latest release. The vault path is resolved with `realpath` before gbrain registers it, so a symlink such as `/tmp` on macOS is stored as its real directory.

Expect these lines, in order:

```text
install: phase prereqs ok
install: phase bun ok
install: phase obsidian ok
install: phase vault ok
install: phase jobs ok
install: phase verify ok
install: done
```

You can run one phase with `--phase prereqs`, `--phase bun`, `--phase obsidian`, `--phase vault`, `--phase jobs`, or `--phase verify`.

Windows, from the repository root:

```powershell
powershell -NoProfile -File scripts/install.ps1
```

Expect `install: done` and a vault path under the person's user profile. Open that folder in Obsidian.

### What each phase does

| Phase | Action | Failure |
| --- | --- | --- |
| prereqs | Requires git, Python 3, curl, and unzip | Install the missing command with the OS package manager, then re-run |
| bun | Uses Bun 1.4.4 or newer, or downloads the official Bun zip from GitHub | Do not pipe a shell installer from the internet. Re-run the phase |
| obsidian | Linux: official AppImage in the user data directory. macOS: official disk image into `$HOME/Applications` | Read the permissions doc. Do not continue if the health line failed |
| vault | Copies `vault/` and indexes it with `gbrain init --pglite --no-embedding --non-interactive --search-mode conservative --db-only` | If the source id already points somewhere else, the script stops and prints `gbrain sources set-path`. Do not delete the old path |
| jobs | Sync every 15 minutes and update daily at 04:15 | Linux uses a systemd user timer, or cron if systemd `--user` is unavailable. macOS uses launchd. Windows uses Task Scheduler calling WSL |
| verify | `gbrain search "offline bed map"` finds the garden planner note | Run `scripts/doctor.sh` and fix the first failing line |

The first gbrain brain is keyless and database-only. Ambient writeback, embeddings, and skill publishing stay off.

## 4. Check

```sh
scripts/doctor.sh
```

Windows:

```powershell
powershell -NoProfile -File scripts/doctor.ps1
```

Expect `doctor: ok` on Linux and macOS when a display is available. With no display, Obsidian's launch is reported as skipped and the version file is still checked. A skipped launch is not a successful GUI test.

## 5. Hand the vault to the person

Tell them the vault path. The rule file inside it is `AGENTS.md`: search before answering, and write decisions back. Background sync keeps the index updated. Daily update is described in [docs/updates.md](docs/updates.md).

To remove the jobs without deleting notes:

```sh
scripts/uninstall.sh
```

Windows: `powershell -NoProfile -File scripts/uninstall.ps1`

`--remove-vault` deletes notes. Do not pass it unless the person asked.
