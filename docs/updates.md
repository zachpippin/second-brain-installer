# Updates, pins, and rollback

A daily job runs `scripts/update.sh` at 04:15. A separate job runs the index sync every 15 minutes. Neither job edits notes. Before and after an update, the installer hashes every file in the vault. If that hash changes, the update fails.

## What is updated

| Component | Automatic path | Rollback |
| --- | --- | --- |
| gbrain | `bun install -g github:garrytan/gbrain#latest-stable`, then migrations | Reinstall the git ref recorded before the update, then run search |
| Obsidian on Linux | Official AppImage swapped in the user data directory | The previous file is moved back if the health check fails |
| Obsidian on macOS | If `/Applications/Obsidian.app` (or another copy this installer did not create) already exists, it is reused and left to Obsidian's own updater. Otherwise the official disk image is copied to `$HOME/Applications`, and a re-run skips the download when that version matches | `scripts/update.sh --force-fail` rolls back only a copy this installer recorded as its own |
| Obsidian on Windows | Not part of the daily job. `scripts/update.ps1 -UpgradeObsidian` runs winget only when asked | Not verified. The version printed before the upgrade is only a record |

gbrain updates are refused when no rollback ref was recorded. That is intentional.

## Health check

After an update the script checks:

- `gbrain search` exits 0 for the configured source
- The Obsidian file is executable and, for a real AppImage, larger than a stub. With a display and `timeout` installed, it also has to start. A macOS `.app` passes when `Contents/MacOS/Obsidian` is executable and `Info.plist` has a version. `timeout` is not required on macOS

## Pin

Freeze a component:

```sh
scripts/update.sh --pin obsidian 1.14.5
scripts/update.sh --pin gbrain 0.60.411.0
```

Clear a pin:

```sh
scripts/update.sh --unpin obsidian
```

A pinned component is skipped and the update log records `skipped-pin`.

## Log and doctor

The log is `update-log.jsonl` under the state directory (`$XDG_STATE_HOME/second-brain` or `~/.local/state/second-brain`). `scripts/doctor.sh` prints the last record, versions, pins, job status, and index status.

## Forced failure

`--force-fail` is for testing. It moves the Obsidian AppImage or `.app` aside, puts a failing script in its place, checks that health fails, restores the previous app, then reinstalls the recorded gbrain ref and checks search. Do not use it on someone's machine unless they asked for a rollback test.

```sh
scripts/update.sh --force-fail
```

## Uninstall

```sh
scripts/uninstall.sh
```

This removes the jobs and an Obsidian copy only when the installer recorded that it installed that copy. An existing `/Applications` app, a Linux package, or a Windows install is left in place. It does not remove notes, Bun, or the gbrain database. `--remove-vault` deletes the notes directory. On Windows, `scripts/uninstall.ps1` also removes the scheduled tasks, including older task names from earlier installs.
