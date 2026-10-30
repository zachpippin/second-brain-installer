#!/usr/bin/env bash
# Background sync and update jobs. Uninstall removes the jobs only.
# Labels are shared across launchd, systemd, cron, and Task Scheduler.
SB_JOB_SYNC=io.github.second-brain-installer.sync
SB_JOB_UPDATE=io.github.second-brain-installer.update

sb_cron_without_ours() {
  printf '%s\n' "$1" \
    | grep -v 'io.github.second-brain-installer.sync' \
    | grep -v 'io.github.second-brain-installer.update' \
    | grep -v 'second-brain-sync' \
    | grep -v 'second-brain-update' \
    || true
}

sb_write_runners() {
  local vault source repo sync_runner update_runner bun_dir
  vault=$(sb_state config-get vault)
  source=$(sb_state config-get source_id)
  repo=$(sb_state config-get repo_root)
  bun_dir=$(dirname "$(command -v bun)")
  sync_runner="$SB_DATA_DIR/bin/sync-index.sh"
  update_runner="$SB_DATA_DIR/bin/update-index.sh"
  python3 - "$sync_runner" "$update_runner" "$vault" "$source" "$repo" "$bun_dir" <<'PY'
import shlex
import stat
import sys
from pathlib import Path

sync_path, update_path, vault, source, repo, bun_dir = sys.argv[1:]
sync = """#!/bin/sh
set -eu
PATH={bun_dir}:$PATH
export PATH
gbrain import {vault} --source {source} --no-embed
gbrain sync --source {source} --no-pull --no-embed
""".format(vault=shlex.quote(vault), source=shlex.quote(source), bun_dir=shlex.quote(bun_dir))
update = """#!/bin/sh
set -eu
PATH={bun_dir}:$PATH
export PATH
exec {repo}/scripts/update.sh
""".format(repo=shlex.quote(repo), bun_dir=shlex.quote(bun_dir))
for path, body in ((sync_path, sync), (update_path, update)):
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(body, encoding="utf-8")
    target.chmod(target.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
PY
}

sb_jobs_install_cron() {
  local sync_line update_line current filtered
  sync_line="*/15 * * * * $SB_DATA_DIR/bin/sync-index.sh >> $SB_STATE_DIR/sync-job.log 2>&1 # ${SB_JOB_SYNC}"
  update_line="15 4 * * * $SB_DATA_DIR/bin/update-index.sh >> $SB_STATE_DIR/update-job.log 2>&1 # ${SB_JOB_UPDATE}"
  if ! command -v crontab >/dev/null 2>&1; then
    return 1
  fi
  current=$(crontab -l 2>/dev/null || true)
  filtered=$(sb_cron_without_ours "$current")
  {
    printf '%s\n' "$filtered" | sed '/^$/d'
    printf '%s\n' "$sync_line"
    printf '%s\n' "$update_line"
  } | crontab -
  printf '%s\n' cron > "$SB_STATE_DIR/scheduler"
  echo "sync-job: cron installed (sync every 15 minutes, update daily at 04:15)"
}

sb_jobs_install_systemd() {
  local unit_dir
  unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  mkdir -p "$unit_dir"
  cat > "$unit_dir/${SB_JOB_SYNC}.service" <<EOF
[Unit]
Description=Sync the second-brain vault into gbrain

[Service]
Type=oneshot
ExecStart=$SB_DATA_DIR/bin/sync-index.sh
EOF
  cat > "$unit_dir/${SB_JOB_SYNC}.timer" <<'EOF'
[Unit]
Description=Sync the second-brain vault into gbrain

[Timer]
OnBootSec=2min
OnUnitActiveSec=15min
Persistent=true

[Install]
WantedBy=timers.target
EOF
  cat > "$unit_dir/${SB_JOB_UPDATE}.service" <<EOF
[Unit]
Description=Update Obsidian and gbrain for the second brain

[Service]
Type=oneshot
ExecStart=$SB_DATA_DIR/bin/update-index.sh
EOF
  cat > "$unit_dir/${SB_JOB_UPDATE}.timer" <<'EOF'
[Unit]
Description=Daily Obsidian and gbrain update

[Timer]
OnCalendar=*-*-* 04:15:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable --now "${SB_JOB_SYNC}.timer" "${SB_JOB_UPDATE}.timer"
  printf '%s\n' systemd > "$SB_STATE_DIR/scheduler"
  echo "sync-job: systemd user timers installed"
}

sb_jobs_install_launchd() {
  local dir sync_plist update_plist domain
  dir="$HOME/Library/LaunchAgents"
  mkdir -p "$dir"
  sync_plist="$dir/${SB_JOB_SYNC}.plist"
  update_plist="$dir/${SB_JOB_UPDATE}.plist"
  cat > "$sync_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${SB_JOB_SYNC}</string>
  <key>ProgramArguments</key>
  <array>
    <string>$SB_DATA_DIR/bin/sync-index.sh</string>
  </array>
  <key>StartInterval</key>
  <integer>900</integer>
  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
EOF
  cat > "$update_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${SB_JOB_UPDATE}</string>
  <key>ProgramArguments</key>
  <array>
    <string>$SB_DATA_DIR/bin/update-index.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>4</integer>
    <key>Minute</key>
    <integer>15</integer>
  </dict>
</dict>
</plist>
EOF
  domain="gui/$(id -u)"
  launchctl bootout "$domain" "$sync_plist" >/dev/null 2>&1 || true
  launchctl bootout "$domain" "$update_plist" >/dev/null 2>&1 || true
  launchctl bootout "$domain/$SB_JOB_SYNC" >/dev/null 2>&1 || true
  launchctl bootout "$domain/$SB_JOB_UPDATE" >/dev/null 2>&1 || true
  launchctl bootout "$domain/com.second-brain.sync" >/dev/null 2>&1 || true
  launchctl bootout "$domain/com.second-brain.update" >/dev/null 2>&1 || true
  launchctl bootstrap "$domain" "$sync_plist"
  launchctl bootstrap "$domain" "$update_plist"
  printf '%s\n' launchd > "$SB_STATE_DIR/scheduler"
  echo "sync-job: launchd agents installed"
}

sb_jobs_install() {
  local os
  sb_write_runners
  os=$(sb_os)
  case "$os" in
    macos)
      sb_jobs_install_launchd
      ;;
    linux)
      if systemctl --user daemon-reload >/dev/null 2>&1; then
        sb_jobs_install_systemd
      elif sb_jobs_install_cron; then
        true
      else
        sb_need_permission linux-scheduler
      fi
      ;;
    *)
      echo "sync-job: this OS uses scripts/install.ps1 for Task Scheduler" >&2
      return 1
      ;;
  esac
}

sb_jobs_uninstall() {
  local os unit_dir domain current filtered
  os=$(sb_os)
  case "$os" in
    macos)
      domain="gui/$(id -u)"
      for label in "$SB_JOB_SYNC" "$SB_JOB_UPDATE" com.second-brain.sync com.second-brain.update; do
        launchctl bootout "$domain/$label" >/dev/null 2>&1 || true
        launchctl bootout "$domain" "$HOME/Library/LaunchAgents/${label}.plist" >/dev/null 2>&1 || true
        rm -f "$HOME/Library/LaunchAgents/${label}.plist"
      done
      ;;
    linux)
      unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
      if systemctl --user daemon-reload >/dev/null 2>&1; then
        systemctl --user disable --now "${SB_JOB_SYNC}.timer" "${SB_JOB_UPDATE}.timer" >/dev/null 2>&1 || true
        systemctl --user disable --now second-brain-sync.timer second-brain-update.timer >/dev/null 2>&1 || true
        rm -f "$unit_dir/${SB_JOB_SYNC}.service" "$unit_dir/${SB_JOB_SYNC}.timer"
        rm -f "$unit_dir/${SB_JOB_UPDATE}.service" "$unit_dir/${SB_JOB_UPDATE}.timer"
        rm -f "$unit_dir/second-brain-sync.service" "$unit_dir/second-brain-sync.timer"
        rm -f "$unit_dir/second-brain-update.service" "$unit_dir/second-brain-update.timer"
        systemctl --user daemon-reload >/dev/null 2>&1 || true
      fi
      if command -v crontab >/dev/null 2>&1; then
        current=$(crontab -l 2>/dev/null || true)
        filtered=$(sb_cron_without_ours "$current")
        if printf '%s\n' "$filtered" | grep -q '[^[:space:]]'; then
          printf '%s\n' "$filtered" | sed '/^$/d' | crontab -
        else
          crontab -r >/dev/null 2>&1 || true
        fi
      fi
      ;;
  esac
  rm -f "$SB_STATE_DIR/scheduler"
  echo "sync-job: removed"
}

sb_jobs_status() {
  local scheduler
  scheduler="missing"
  if [[ -f $SB_STATE_DIR/scheduler ]]; then
    scheduler=$(tr -d '[:space:]' < "$SB_STATE_DIR/scheduler")
  fi
  echo "sync-job: scheduler $scheduler"
  case "$scheduler" in
    systemd)
      systemctl --user --no-pager --full status "${SB_JOB_SYNC}.timer" "${SB_JOB_UPDATE}.timer" || true
      ;;
    launchd)
      launchctl print "gui/$(id -u)/${SB_JOB_SYNC}" >/dev/null 2>&1 && echo "sync-job: launchd sync loaded" || echo "sync-job: launchd sync not loaded"
      launchctl print "gui/$(id -u)/${SB_JOB_UPDATE}" >/dev/null 2>&1 && echo "sync-job: launchd update loaded" || echo "sync-job: launchd update not loaded"
      ;;
    cron)
      crontab -l 2>/dev/null | grep 'second-brain-' || echo "sync-job: cron lines missing"
      ;;
    *)
      echo "sync-job: not installed"
      ;;
  esac
}
