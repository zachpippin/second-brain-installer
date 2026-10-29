#!/usr/bin/env bash
# Install Obsidian, gbrain, the starter vault, and the background jobs.
# Safe to re-run. Stops with exit 10 when a person has to approve an OS prompt.
# Usage: scripts/install.sh [--vault PATH] [--yes] [--dry-run] [--skip-obsidian]
#        [--obsidian-host linux|macos|windows] [--phase NAME]
set -euo pipefail

ROOT=$(unset CDPATH; cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/common.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/obsidian.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/jobs.sh"

VAULT="${SECOND_BRAIN_VAULT:-$HOME/SecondBrain}"
ASSUME=0
DRY=0
SKIP_OBSIDIAN=0
OBSIDIAN_HOST=""
PHASE=""

usage() {
  echo "Usage: scripts/install.sh [--vault PATH] [--yes] [--dry-run] [--skip-obsidian] [--obsidian-host HOST] [--phase NAME]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --vault) VAULT=$2; shift ;;
    --yes) ASSUME=1 ;;
    --dry-run) DRY=1 ;;
    --skip-obsidian) SKIP_OBSIDIAN=1 ;;
    --obsidian-host) OBSIDIAN_HOST=$2; shift ;;
    --phase) PHASE=$2; shift ;;
    *) echo "install: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

phase_selected() {
  [[ -z $PHASE || $PHASE == "$1" ]]
}

ensure_bun() {
  sb_path_prepend_bun
  if command -v bun >/dev/null 2>&1 && sb_version_ge "$(bun --version)" "1.4.4"; then
    echo "install: bun $(bun --version)"
    return 0
  fi
  local asset url tmp unpacked
  case "$(sb_os)-$(uname -m)" in
    linux-x86_64) asset=bun-linux-x64.zip ;;
    linux-aarch64|linux-arm64) asset=bun-linux-aarch64.zip ;;
    macos-arm64) asset=bun-darwin-aarch64.zip ;;
    macos-x86_64) asset=bun-darwin-x64.zip ;;
    *)
      echo "install: no Bun build is selected for this OS" >&2
      exit 1
      ;;
  esac
  url="https://github.com/oven-sh/bun/releases/latest/download/${asset}"
  echo "install: downloading Bun from the official GitHub release ($asset)"
  tmp=$(mktemp -d)
  curl -fL --retry 3 -o "$tmp/bun.zip" "$url"
  unzip -q "$tmp/bun.zip" -d "$tmp"
  unpacked=$(find "$tmp" -type f -name bun -perm -u+x | head -n 1 || true)
  if [[ -z $unpacked ]]; then
    unpacked=$(find "$tmp" -type f -name bun | head -n 1 || true)
  fi
  if [[ -z $unpacked ]]; then
    echo "install: Bun archive did not contain a bun binary" >&2
    exit 1
  fi
  mkdir -p "$HOME/.bun/bin"
  cp "$unpacked" "$HOME/.bun/bin/bun"
  chmod +x "$HOME/.bun/bin/bun"
  rm -rf "$tmp"
  sb_path_prepend_bun
  if ! sb_version_ge "$(bun --version)" "1.4.4"; then
    echo "install: Bun $(bun --version) is older than 1.4.4" >&2
    exit 1
  fi
  echo "install: bun $(bun --version)"
}

run_detect() {
  local os
  os=$(sb_os)
  echo "install: os $os"
  if [[ $os == windows ]]; then
    echo "install: on Windows run scripts/install.ps1. gbrain is installed inside WSL, not in Git Bash." >&2
    exit 1
  fi
  if [[ $os == unknown ]]; then
    echo "install: unsupported operating system $(uname -s)" >&2
    exit 1
  fi
  if sb_wsl && [[ $SKIP_OBSIDIAN -eq 0 && ${SECOND_BRAIN_OBSIDIAN_IN_WSL:-} != 1 ]]; then
    echo "install: WSL detected. Obsidian for Windows is installed by scripts/install.ps1."
    SKIP_OBSIDIAN=1
    if [[ -z $OBSIDIAN_HOST ]]; then
      OBSIDIAN_HOST=windows
    fi
  fi
  echo "install: phase detect ok"
}

run_prereqs() {
  local cmd
  for cmd in git python3 curl unzip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "install: required command not found: $cmd" >&2
      exit 1
    fi
  done
  echo "install: phase prereqs ok"
}

run_bun() {
  if [[ $DRY -eq 1 ]]; then
    echo "install: dry-run would install Bun 1.4.4 or newer into \$HOME/.bun"
    return 0
  fi
  ensure_bun
  echo "install: phase bun ok"
}

run_obsidian() {
  local os
  os=$(sb_os)
  if [[ $SKIP_OBSIDIAN -eq 1 ]]; then
    echo "install: obsidian skipped"
    echo "install: phase obsidian ok"
    return 0
  fi
  if [[ $DRY -eq 1 ]]; then
    echo "install: dry-run would install Obsidian for $os from the official release"
    return 0
  fi
  case "$os" in
    linux)
      echo "install: AppImage files need the executable bit. This script sets it."
      echo "install: if the desktop still blocks the file, see docs/permissions-linux.md section linux-appimage-exec."
      sb_obsidian_install_linux
      ;;
    macos)
      if [[ $ASSUME -ne 1 ]]; then
        sb_need_permission macos-gatekeeper
      fi
      sb_obsidian_install_macos
      ;;
    *)
      echo "install: Obsidian install for $os is handled by scripts/install.ps1" >&2
      exit 1
      ;;
  esac
  echo "install: phase obsidian ok"
}

run_vault() {
  if [[ $DRY -eq 1 ]]; then
    echo "install: dry-run would copy the starter vault to $VAULT and index it"
    return 0
  fi
  sb_path_prepend_bun
  "$ROOT/scripts/setup.sh" "$VAULT"
  sb_export_dirs
  sb_state config-set vault "$VAULT"
  sb_state config-set source_id "${GBRAIN_SOURCE:-obsidian-vault}"
  sb_state config-set repo_root "$ROOT"
  sb_state config-set obsidian_host "${OBSIDIAN_HOST:-$(sb_os)}"
  if [[ -f "$(sb_obsidian_dir)/VERSION" ]]; then
    sb_state versions-set obsidian "$(tr -d '[:space:]' < "$(sb_obsidian_dir)/VERSION")"
  fi
  sb_record_gbrain
  echo "install: phase vault ok"
}

run_jobs() {
  if [[ $DRY -eq 1 ]]; then
    echo "install: dry-run would install the sync and update jobs"
    return 0
  fi
  sb_export_dirs
  sb_jobs_install
  echo "install: phase jobs ok"
}

run_verify() {
  local vault source
  if [[ $DRY -eq 1 ]]; then
    echo "install: dry-run would search the vault"
    return 0
  fi
  vault=$(sb_state config-get vault)
  source=$(sb_state config-get source_id)
  sb_path_prepend_bun
  tmp=$(mktemp)
  if ! gbrain search "offline bed map" --source "$source" --json >"$tmp"; then
    echo "install: search failed" >&2
    rm -f "$tmp"
    exit 1
  fi
  if [[ -f $vault/wiki/projects/garden-planner.md ]] && ! grep -q garden-planner "$tmp"; then
    echo "install: search did not find the garden planner note" >&2
    rm -f "$tmp"
    exit 1
  fi
  rm -f "$tmp"
  echo "install: phase verify ok"
  echo "install: done"
  echo "install: vault $vault"
  echo "install: open that folder in Obsidian. Ask an agent what Sam Rivera decided about offline bed maps."
}

main() {
  local os
  os=$(sb_os)
  if [[ $os == windows ]]; then
    echo "install: on Windows run scripts/install.ps1" >&2
    exit 1
  fi
  sb_export_dirs
  if phase_selected detect; then run_detect; fi
  if phase_selected prereqs; then run_prereqs; fi
  if phase_selected bun; then run_bun; fi
  if phase_selected obsidian; then run_obsidian; fi
  if phase_selected vault; then run_vault; fi
  if phase_selected jobs; then run_jobs; fi
  if phase_selected verify; then run_verify; fi
  if [[ -n $PHASE ]]; then
    case "$PHASE" in
      detect|prereqs|bun|obsidian|vault|jobs|verify) ;;
      *) echo "install: unknown phase: $PHASE" >&2; exit 2 ;;
    esac
  fi
}

main
