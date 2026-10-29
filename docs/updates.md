# Updates, pins, and rollback

A daily job runs `scripts/update.sh` at 04:15. A separate job runs the index sync every 15 minutes. Neither job edits notes. Before and after an update, the installer hashes every file in the vault. If that hash changes, the update fails.

## What is updated

| Component | Automatic path | Rollback |
| --- | --- | --- |
| gbrain | `bun install -g github:garrytan/gbrain#latest-stable`, then migrations | Reinstall the git ref recorded before the update, then run search |
| Obsidian on Linux | Official AppImage swapped in the user data directory | The previous file is moved back if the health check fails |
| Obsidian on macOS | Not run in testing. Install uses the official disk image in the home Applications folder | Previous `.app` is kept aside by `scripts/install.sh` on a re-run. The daily updater does not replace it until that path is tested |
| Obsidian on Windows | Not part of the daily job. `scripts/update.ps1 -UpgradeObsidian` runs winget only when asked | Not verified. The version printed before the upgrade is only a record |

gbrain updates are refused when no rollback ref was recorded. That is intentional.

## Health check

After an update the script checks:

- `gbrain search` exits 0 for the configured source
- The Obsidian file is executable and, for a real AppImage, larger than a stub. With a display, it also has to start. Without a display, doctor says launch was skipped

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

`--force-fail` is for testing. It replaces the Obsidian file with a failing script, checks that health fails, restores the previous file, then reinstalls the recorded gbrain ref and checks search. Do not use it on someone's machine unless they asked for a rollback test.

```sh
scripts/update.sh --force-fail
```

## Uninstall

```sh
scripts/uninstall.sh
```

This removes the jobs and the installer state, including the AppImage copy. It does not remove notes, Bun, or the gbrain database. `--remove-vault` deletes the notes directory. On Windows, `scripts/uninstall.ps1` also removes the scheduled tasks.
