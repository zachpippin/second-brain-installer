#!/usr/bin/env bash
# Shared paths for the second-brain installer. Source this file.

sb_repo_root() {
  local lib_dir
  lib_dir=$(unset CDPATH; cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  unset CDPATH; cd -- "$lib_dir/../.." && pwd
}

sb_os() {
  local name
  name=$(uname -s)
  case "$name" in
    Darwin) printf '%s\n' macos ;;
    Linux) printf '%s\n' linux ;;
    MINGW* | MSYS* | CYGWIN*) printf '%s\n' windows ;;
    *) printf '%s\n' unknown ;;
  esac
}

sb_wsl() {
  if [[ -r /proc/version ]] && grep -qi microsoft /proc/version; then
    return 0
  fi
  return 1
}

sb_export_dirs() {
  SB_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/second-brain"
  SB_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/second-brain"
  SB_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/second-brain"
  export SB_CONFIG_DIR SB_STATE_DIR SB_DATA_DIR
  mkdir -p "$SB_CONFIG_DIR" "$SB_STATE_DIR" "$SB_DATA_DIR/bin" "$SB_DATA_DIR/obsidian"
}

sb_state() {
  python3 "$(sb_repo_root)/scripts/lib/state.py" "$@"
}

sb_version_ge() {
  python3 - "$1" "$2" <<'PY'
import sys

def parse(raw):
    parts = []
    for piece in raw.split(".")[:3]:
        number = ""
        for char in piece:
            if char.isdigit():
                number += char
            else:
                break
        parts.append(int(number or "0"))
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts)

sys.exit(0 if parse(sys.argv[1]) >= parse(sys.argv[2]) else 1)
PY
}

sb_path_prepend_bun() {
  export PATH="$HOME/.bun/bin:$PATH"
}

sb_need_permission() {
  echo "install: PERMISSION $1"
  echo "install: stop. Read the matching section in the permissions doc."
  echo "install: tell the person what to click or type, then re-run this command."
  exit 10
}

sb_vault_fingerprint() {
  sb_state fingerprint "$1"
}

sb_index_health() {
  local source tmp
  sb_path_prepend_bun
  source=$(sb_state config-get source_id)
  if [[ -z $source ]]; then
    echo "index: source id is not configured" >&2
    return 1
  fi
  tmp=$(mktemp)
  if ! gbrain search "offline bed map" --source "$source" --json >"$tmp" 2>"$tmp.err"; then
    echo "index: gbrain search failed" >&2
    cat "$tmp.err" >&2 || true
    rm -f "$tmp" "$tmp.err"
    return 1
  fi
  rm -f "$tmp" "$tmp.err"
  echo "index: search ok"
}

sb_gbrain_ref() {
  python3 - "$HOME/.bun" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
pattern = re.compile(r"github:garrytan/gbrain#([0-9a-fA-F]{7,40})")
found = ""
if not root.is_dir():
    sys.exit(0)
for path in (
    root / "install/global/bun.lock",
    root / "install/global/package.json",
):
    if path.is_file():
        match = pattern.search(path.read_text(encoding="utf-8", errors="replace"))
        if match:
            found = match.group(1)
if not found:
    lock_dir = root / "install/global"
    if lock_dir.is_dir():
        for path in lock_dir.rglob("*"):
            if not path.is_file() or path.stat().st_size > 2_000_000:
                continue
            if path.suffix not in {".lock", ".json", ".txt"} and path.name not in {"bun.lock"}:
                continue
            match = pattern.search(path.read_text(encoding="utf-8", errors="replace"))
            if match:
                found = match.group(1)
                break
sys.stdout.write(found)
PY
}

sb_normalize_gbrain_version() {
  local raw=$1
  raw=${raw#"gbrain "}
  printf '%s' "$raw" | awk 'NF { $1=$1; print }'
}

sb_realpath() {
  python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"
}

sb_record_gbrain() {
  local version ref
  sb_path_prepend_bun
  version=$(gbrain --version 2>&1 | head -n 1 || true)
  version=$(sb_normalize_gbrain_version "$version")
  ref=$(sb_gbrain_ref)
  sb_state versions-set gbrain "$version"
  sb_state versions-set gbrain_ref "$ref"
  echo "gbrain: recorded ${version:-unknown} ref ${ref:-missing}"
}
