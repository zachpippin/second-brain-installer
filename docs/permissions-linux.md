# Linux permissions

Stop at a section only when the installer prints that `install: PERMISSION` id, or when the check below fails. Do not ask for a password ahead of time. The default Linux path is an official AppImage and does not need sudo.

## linux-appimage-exec

The installer runs `chmod +x` on the AppImage. Some file managers and desktops still block it.

Tell the person:

1. Open the file manager to the second-brain data directory under the home folder: `.local/share/second-brain/obsidian/`.
2. Right-click `Obsidian.AppImage` and enable "Allow executing file as program", or run `chmod +x` on that file in a terminal they trust.
3. If the file is on a `noexec` mount, move the repository and data directory to a normal home directory and re-run `scripts/install.sh`.

It worked when `scripts/doctor.sh` prints `obsidian: health ok`.

## linux-fuse

Older AppImages need FUSE (`libfuse2` or `fuse3`). Current Obsidian builds often run without it. If launch fails with a FUSE error:

1. Tell the person a package install will ask for their password in the terminal.
2. They type the password. The characters will not echo. They press Enter.
3. Install the distribution's FUSE package with its normal package manager, then re-run `scripts/install.sh --phase obsidian`.

It worked when the FUSE error is gone and doctor prints a health line.

## linux-sudo

Printed only if a later command really needs root, such as a `.deb` the person asked for. The default installer does not use sudo.

Tell the person: a `sudo` password prompt is showing. Type the login password and press Enter. Do not send the password to the agent.

It worked when `sudo -n true` succeeds, or when the package command exits 0.

## linux-scheduler

Printed when neither `systemctl --user` nor `crontab` works.

Tell the person:

1. Install the `cron` package, or enable systemd user sessions (`systemd` and `dbus-user-session`).
2. A package install may show the sudo prompt from `linux-sudo`.
3. Re-run `scripts/install.sh --phase jobs`.

Optional, only if sync should run while they are logged out: `loginctl enable-linger` for their user. That is not required for a normal login session.

It worked when `scripts/doctor.sh` prints `sync-job: scheduler cron` or `sync-job: scheduler systemd`.

## Flatpak and deb

Flatpak (`md.obsidian.Obsidian` on Flathub) is community-maintained, not the official build. A `.deb` from the official release needs sudo. v1 automatic rollback is implemented for the AppImage this installer downloads. Do not switch to Flatpak or a deb unless the person asks, and tell them rollback is then not automatic.
