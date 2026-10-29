#!/usr/bin/env bash
# Show versions, the last update, background jobs, and whether search works.
set -euo pipefail

ROOT=$(unset CDPATH; cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/common.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/obsidian.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/jobs.sh"

sb_export_dirs
sb_path_prepend_bun

status=0
echo "doctor: os $(sb_os)"
if sb_wsl; then
  echo "doctor: environment wsl"
fi

vault=$(sb_state config-get vault)
source=$(sb_state config-get source_id)
echo "doctor: vault ${vault:-missing}"
echo "doctor: source ${source:-missing}"
host=$(sb_state config-get obsidian_host)
echo "doctor: obsidian-host ${host:-missing}"
echo "doctor: obsidian-version $(sb_state versions-get obsidian)"
echo "doctor: obsidian-pin $(sb_state pin-get obsidian)"
app=$(sb_obsidian_app)
if [[ $host == windows ]]; then
  echo "doctor: obsidian is the Windows app; this shell does not launch it"
elif [[ -x $app || -d $app ]]; then
  if ! sb_obsidian_health "$app"; then
    status=1
  fi
else
  echo "doctor: obsidian binary missing"
  status=1
fi
if command -v bun >/dev/null 2>&1; then
  echo "doctor: bun $(bun --version)"
else
  echo "doctor: bun missing"
  status=1
fi
if command -v gbrain >/dev/null 2>&1; then
  echo "doctor: gbrain $(sb_normalize_gbrain_version "$(gbrain --version 2>&1 | head -n 1 || true)")"
else
  echo "doctor: gbrain missing"
  status=1
fi
echo "doctor: gbrain-recorded $(sb_state versions-get gbrain)"
echo "doctor: gbrain-ref $(sb_state versions-get gbrain_ref)"
echo "doctor: gbrain-pin $(sb_state pin-get gbrain)"
echo "doctor: last-update"
sb_state last
sb_jobs_status
if [[ -n $vault && -d $vault ]] && command -v gbrain >/dev/null 2>&1; then
  if ! sb_index_health; then
    status=1
  fi
else
  echo "index: not checked"
  status=1
fi
if [[ $status -eq 0 ]]; then
  echo "doctor: ok"
else
  echo "doctor: failed"
fi
exit "$status"
