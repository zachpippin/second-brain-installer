# Installer instructions

You are the coding agent installing this second brain. Follow [INSTALL.md](INSTALL.md) step by step. Do not invent gbrain flags, package names, or permission clicks.

gbrain ([github.com/garrytan/gbrain](https://github.com/garrytan/gbrain)) and [Obsidian](https://obsidian.md) are separate projects. This repository is not affiliated with either of them.

## What to run

1. Read [INSTALL.md](INSTALL.md) and the permissions doc for the detected OS:
   - [docs/permissions-linux.md](docs/permissions-linux.md)
   - [docs/permissions-macos.md](docs/permissions-macos.md)
   - [docs/permissions-windows.md](docs/permissions-windows.md)
2. macOS and Linux: `scripts/install.sh`
3. Windows: `scripts/install.ps1` (gbrain runs in WSL; native Windows gbrain is not the v1 path)
4. If a command prints `install: PERMISSION <id>`, stop. Tell the person the exact click or type from that section. When they confirm, re-run. On macOS Gatekeeper, re-run with `--yes` only after they confirm.
5. Do not continue until the phase line you expected is `ok`.
6. Finish with `scripts/doctor.sh` (or `scripts/doctor.ps1` on Windows).

## After install

The notes live in the vault folder, not in this repository. The vault's `AGENTS.md` is the rule file: search the vault before answering, and write decisions back. Do not store secrets. Do not enable ambient writeback.

Updates are automatic and must not change notes. Read [docs/updates.md](docs/updates.md). Use `scripts/update.sh --pin` when the person wants a component frozen.

## On failure

- Exit code 10 is a permission stop, not a crash.
- Exit code 1 is a failed step. Read the last `install:` or `update:` line, fix that step, and re-run. The scripts are safe to re-run.
- Do not delete the vault to recover a failed index. `scripts/doctor.sh` shows the last update result.
- Do not pass `--force-fail` except when testing rollback.
- Do not publish the brain, change git remotes, or change repository visibility.
