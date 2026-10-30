# macOS permissions

This path was run on an Apple Silicon Mac (macOS 26.6.2) without Homebrew. Install, search, rollback, pin, launchd, and uninstall worked. The steps below are what to do if a prompt appears.

## macos-gatekeeper

If `/Applications/Obsidian.app` is already installed, the installer reuses it and does not copy a second app into the home Applications folder. Updates of that copy are left to Obsidian.

When it does install, the official disk image is downloaded with curl and copied to `$HOME/Applications/Obsidian.app`. On the tested Mac, that app had no `com.apple.quarantine` extended attribute, and `spctl --assess` reported `accepted, source=Notarized Developer ID` (Dynalist Inc.). The "downloaded from the internet" dialog did not appear.

The installer stops with `install: PERMISSION macos-gatekeeper` only when that quarantine attribute is present on a copy it just installed, and `--yes` was not passed. A re-run that finds the same version already installed does not download the disk image again and does not stop for Gatekeeper.

If macOS does ask:

1. Control-click `Obsidian.app` in the home Applications folder, choose Open, then choose Open again.
2. If it is still blocked: System Settings, Privacy & Security, and allow Obsidian.

It worked when `scripts/doctor.sh` prints `obsidian: health ok bundle` and a version.

## macos-brew-password

Only if you choose Homebrew instead of the disk image (`brew install --cask obsidian` or `brew install oven-sh/bun/bun`). The tested install did not use Homebrew.

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

`launchctl bootstrap` usually does not prompt. The job labels are `io.github.second-brain-installer.sync` and `io.github.second-brain-installer.update`.

If macOS says a service is not approved:

1. System Settings, General, Login Items & Extensions.
2. Allow those labels if they are listed.

It worked when `scripts/doctor.sh` prints `sync-job: launchd sync loaded`.
