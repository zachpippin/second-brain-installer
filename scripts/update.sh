#!/usr/bin/env bash
# Update Obsidian and gbrain. Notes are fingerprinted and must not change.
# On a failed health check the previous binary or gbrain ref is restored.
# Usage: scripts/update.sh [--force-fail] [--component obsidian|gbrain|all]
#        scripts/update.sh --pin obsidian VERSION
#        scripts/update.sh --unpin gbrain
set -euo pipefail

ROOT=$(unset CDPATH; cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/common.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/obsidian.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/jobs.sh"

FORCE_FAIL=0
COMPONENT=all
PIN_COMPONENT=""
PIN_VERSION=""
UNPIN=""

usage() {
  echo "Usage: scripts/update.sh [--force-fail] [--component obsidian|gbrain|all]"
  echo "       scripts/update.sh --pin COMPONENT VERSION"
  echo "       scripts/update.sh --unpin COMPONENT"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --force-fail) FORCE_FAIL=1 ;;
    --component) COMPONENT=$2; shift ;;
    --pin) PIN_COMPONENT=$2; PIN_VERSION=$3; shift 2 ;;
    --unpin) UNPIN=$2; shift ;;
    *) echo "update: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

sb_export_dirs
sb_path_prepend_bun

if [[ -n $PIN_COMPONENT ]]; then
  sb_state pin-set "$PIN_COMPONENT" "$PIN_VERSION"
  echo "update: pinned $PIN_COMPONENT at $PIN_VERSION"
  exit 0
fi
if [[ -n $UNPIN ]]; then
  sb_state pin-set "$UNPIN" ""
  echo "update: unpinned $UNPIN"
  exit 0
fi

case "$COMPONENT" in
  obsidian|gbrain|all) ;;
  *) echo "update: unknown component: $COMPONENT" >&2; exit 2 ;;
esac

VAULT=$(sb_state config-get vault)
if [[ -z $VAULT || ! -d $VAULT ]]; then
  echo "update: vault is not configured. Run scripts/install.sh first." >&2
  exit 1
fi

BEFORE=$(sb_vault_fingerprint "$VAULT")

assert_notes_unchanged() {
  local after
  after=$(sb_vault_fingerprint "$VAULT")
  if [[ $after != "$BEFORE" ]]; then
    echo "update: the vault fingerprint changed. Notes must not be modified by an update." >&2
    exit 1
  fi
}

update_obsidian() {
  local pin current app meta version
  pin=$(sb_state pin-get obsidian)
  current=$(sb_state versions-get obsidian)
  app=$(sb_obsidian_app)
  if [[ -n $pin ]]; then
    echo "update: obsidian pinned at $pin"
    sb_state log --component obsidian --action update --from-version "$pin" --to-version "$pin" --result skipped-pin --detail "pin set"
    return 0
  fi
  if [[ $FORCE_FAIL -eq 1 ]]; then
    if ! sb_obsidian_force_fail "$app"; then
      sb_state log --component obsidian --action update --from-version "$current" --to-version "$current" --result rollback-failed --detail "forced failure"
      return 1
    fi
    sb_state log --component obsidian --action update --from-version "$current" --to-version "$current" --result rolled-back --detail "forced failure"
    return 0
  fi
  if [[ $(sb_state config-get obsidian_host) == windows ]]; then
    echo "update: Obsidian on Windows is updated by scripts/update.ps1"
    sb_state log --component obsidian --action update --from-version "$current" --to-version "$current" --result skipped-windows --detail "Windows host"
    return 0
  fi
  if [[ $(sb_os) != linux ]]; then
    echo "update: automatic Obsidian replacement is implemented for the Linux AppImage in this script."
    echo "update: macOS replacement is installed by scripts/install.sh and was not executed here."
    sb_state log --component obsidian --action update --from-version "$current" --to-version "$current" --result skipped-untested-os --detail "$(sb_os)"
    return 0
  fi
  meta=$(sb_obsidian_release linux "$(uname -m)")
  version=$(printf '%s\n' "$meta" | sed -n '1p')
  if [[ -n $current && $current == "$version" ]]; then
    echo "update: obsidian already at $version"
    sb_state log --component obsidian --action update --from-version "$current" --to-version "$version" --result unchanged --detail "already current"
    return 0
  fi
  echo "update: obsidian $current -> $version"
  if ! sb_obsidian_install_linux; then
    sb_state log --component obsidian --action update --from-version "$current" --to-version "$version" --result rolled-back --detail "install health failed"
    return 1
  fi
  sb_state versions-set obsidian "$version"
  sb_state log --component obsidian --action update --from-version "$current" --to-version "$version" --result ok --detail "official AppImage"
}

update_gbrain() {
  local pin current ref
  pin=$(sb_state pin-get gbrain)
  current=$(sb_normalize_gbrain_version "$(sb_state versions-get gbrain)")
  ref=$(sb_state versions-get gbrain_ref)
  if [[ -n $pin ]]; then
    echo "update: gbrain pinned at $pin"
    sb_state log --component gbrain --action update --from-version "$pin" --to-version "$pin" --result skipped-pin --detail "pin set"
    return 0
  fi
  if [[ -z $ref ]]; then
    echo "update: refusing gbrain update because no rollback ref is recorded" >&2
    sb_state log --component gbrain --action update --from-version "$current" --to-version "" --result refused --detail "no rollback ref"
    return 1
  fi
  if [[ $FORCE_FAIL -eq 1 ]]; then
    echo "update: forcing a gbrain rollback to $ref"
    bun install -g "github:garrytan/gbrain#${ref}"
    gbrain apply-migrations --yes --no-autopilot-install
    if ! sb_index_health; then
      sb_state log --component gbrain --action update --from-version "$current" --to-version "$ref" --result rollback-failed --detail "forced failure"
      return 1
    fi
    sb_record_gbrain
    sb_state log --component gbrain --action update --from-version "$current" --to-version "$ref" --result rolled-back --detail "forced failure"
    echo "update: gbrain rollback ok"
    return 0
  fi
  echo "update: installing gbrain latest-stable"
  bun install -g github:garrytan/gbrain#latest-stable
  echo "update: do not install the unrelated npm package named gbrain"
  gbrain apply-migrations --yes --no-autopilot-install
  if ! sb_index_health; then
    echo "update: gbrain health failed, rolling back to $ref"
    bun install -g "github:garrytan/gbrain#${ref}"
    gbrain apply-migrations --yes --no-autopilot-install
    if sb_index_health; then
      sb_state log --component gbrain --action update --from-version "$current" --to-version "$ref" --result rolled-back --detail "search failed"
    else
      sb_state log --component gbrain --action update --from-version "$current" --to-version "$ref" --result rollback-failed --detail "search failed"
    fi
    return 1
  fi
  sb_record_gbrain
  sb_state log --component gbrain --action update --from-version "$current" --to-version "$(sb_state versions-get gbrain)" --result ok --detail "latest-stable"
  echo "update: gbrain ok"
}

status=0
if [[ $COMPONENT == all || $COMPONENT == obsidian ]]; then
  update_obsidian || status=1
fi
if [[ $COMPONENT == all || $COMPONENT == gbrain ]]; then
  update_gbrain || status=1
fi
assert_notes_unchanged
echo "update: notes unchanged"
if [[ $status -ne 0 ]]; then
  echo "update: failed"
  exit "$status"
fi
echo "update: done"
