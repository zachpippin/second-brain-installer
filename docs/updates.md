# Updates, pins, and rollback

A daily job runs `scripts/update.sh` at 04:15. A separate job runs the index sync every 15 minutes. Neither job edits notes. Before and after an update, the installer hashes every file in the vault. If that hash changes, the update fails.

## What is updated

| Component | Automatic path | Rollback |
| --- | --- | --- |
| gbrain | `bun install -g github:garrytan/gbrain#latest-stable`, then migrations | Reinstall the git ref recorded before the update, then run search |
| Obsidian on Linux | Official AppImage swapped in the user data directory | The previous file is moved back if the health check fails |
| Obsidian on macOS | Official disk image copied to `$HOME/Applications`. A re-run skips the download when that version is already installed. The daily updater does not download a newer image yet | `scripts/update.sh --force-fail` moves the `.app` aside, fails the bundle health check, and moves it back |
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

This removes the jobs, the AppImage, and on macOS both `$HOME/Applications/Obsidian.app` and `Obsidian.app.previous`. It does not remove notes, Bun, or the gbrain database. `--remove-vault` deletes the notes directory. On Windows, `scripts/uninstall.ps1` also removes the scheduled tasks, including older task names from earlier installs.
