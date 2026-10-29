# macOS permissions

These steps were not executed on a Mac while this installer was written. Follow them anyway; the script stops so you can.

## macos-gatekeeper

The installer exits 10 with this id before the first copy into `$HOME/Applications`.

Tell the person:

1. The next command downloads the official Obsidian disk image and copies `Obsidian.app` into the home Applications folder, not the system `/Applications` folder. That avoids an administrator password on later automatic updates.
2. The first time they open Obsidian, macOS may say the app is from the internet.
3. If it is blocked: open Finder, go to the home Applications folder, Control-click `Obsidian.app`, choose Open, then choose Open again in the dialog.
4. If Finder still blocks it: System Settings, Privacy & Security, and allow Obsidian.

After they confirm they understand the first-launch dialog, re-run:

```sh
scripts/install.sh --vault "$HOME/SecondBrain" --yes
```

Do not pass `--yes` before they confirm.

It worked when doctor shows an Obsidian version and the person can open the app once.

## macos-brew-password

Only if you choose Homebrew instead of the disk image (`brew install --cask obsidian` or `brew install oven-sh/bun/bun`).

Tell the person: a macOS password dialog or a Terminal `Password:` prompt is about to appear. Type the login password and press Enter. Do not paste the password into chat.

It worked when `brew list --cask obsidian` or `bun --version` exits 0.

## macos-files

Do not ask for Full Disk Access up front.

If the installer cannot read or write the vault path:

1. System Settings, Privacy & Security, Files and Folders.
2. Enable the terminal or agent app for the folder that holds the vault.
3. Full Disk Access is only needed if Files and Folders is not enough. Add the same terminal app there, then quit and reopen it.

It worked when `scripts/install.sh --phase vault` prints `install: phase vault ok`.

## macos-launchd

`launchctl bootstrap` usually does not prompt. If it says the service is not approved:

1. System Settings, General, Login Items & Extensions.
2. Allow the second-brain sync agent if it is listed.

It worked when `scripts/doctor.sh` prints `sync-job: launchd sync loaded`.
