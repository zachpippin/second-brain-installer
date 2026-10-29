#!/usr/bin/env bash
# Remove background jobs and files this installer created.
# The notes vault is kept unless --remove-vault is passed.
set -euo pipefail

ROOT=$(unset CDPATH; cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/common.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/jobs.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/obsidian.sh"

REMOVE_VAULT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      echo "Usage: scripts/uninstall.sh [--remove-vault]"
      exit 0
      ;;
    --remove-vault) REMOVE_VAULT=1 ;;
    *) echo "uninstall: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

sb_export_dirs
vault=$(sb_state config-get vault || true)
app=$(sb_obsidian_app)
sb_jobs_uninstall
rm -rf "$app" "$app.previous"
echo "uninstall: removed $app"
rm -rf "$SB_DATA_DIR" "$SB_STATE_DIR" "$SB_CONFIG_DIR"
if [[ $REMOVE_VAULT -eq 1 && -n $vault ]]; then
  echo "uninstall: removing vault $vault"
  rm -rf "$vault"
else
  echo "uninstall: notes were left in place${vault:+ at $vault}"
fi
echo "uninstall: done"
