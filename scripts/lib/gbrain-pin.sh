#!/bin/sh
# Read scripts/lib/gbrain-pin and check a Bun global install against it.
# Sourced by setup.sh (POSIX sh) and by scripts/lib/common.sh.

sb_gbrain_pin_field() {
  python3 - "$1" "$2" <<'PY'
import re
import sys

path, field = sys.argv[1], sys.argv[2]
allowed = ("commit", "integrity")
commit_re = re.compile(r"^[0-9a-f]{40}$")
integrity_re = re.compile(r"^sha512-[A-Za-z0-9+/=]+$")
values = {}
try:
    lines = open(path, encoding="utf-8").read().splitlines()
except OSError as exc:
    sys.stderr.write(f"gbrain: cannot read pin file {path}: {exc}\n")
    sys.exit(1)
for lineno, line in enumerate(lines, 1):
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        continue
    parts = stripped.split(None, 1)
    if len(parts) != 2 or parts[0] not in allowed:
        sys.stderr.write(
            f"gbrain: {path}:{lineno}: expected 'commit SHA' or 'integrity sha512-...'\n"
        )
        sys.exit(1)
    key, value = parts
    if key in values:
        sys.stderr.write(f"gbrain: {path}:{lineno}: duplicate {key}\n")
        sys.exit(1)
    values[key] = value
commit = values.get("commit", "")
integrity = values.get("integrity", "")
if not commit_re.fullmatch(commit):
    sys.stderr.write("gbrain: pin commit must be a 40-character lowercase git commit\n")
    sys.exit(1)
if not integrity_re.fullmatch(integrity):
    sys.stderr.write("gbrain: pin integrity must be a Bun sha512-... hash\n")
    sys.exit(1)
if field not in values:
    sys.stderr.write(f"gbrain: pin file is missing {field}\n")
    sys.exit(1)
sys.stdout.write(values[field])
PY
}

sb_gbrain_resolved_commit() {
  python3 - "$1" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
pattern = re.compile(r"github:garrytan/gbrain#([0-9a-fA-F]{7,40})")
found = []
if root.is_dir():
    files = []
    for path in (
        root / "install/global/bun.lock",
        root / "install/global/package.json",
    ):
        if path.is_file():
            files.append(path)
    lock_dir = root / "install/global"
    if lock_dir.is_dir():
        for path in lock_dir.rglob("*"):
            if path in files or not path.is_file() or path.stat().st_size > 2_000_000:
                continue
            if path.suffix not in {".lock", ".json", ".txt"} and path.name != "bun.lock":
                continue
            files.append(path)
    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        found.extend(pattern.findall(text))
full = [item for item in found if re.fullmatch(r"[0-9a-fA-F]{40}", item)]
chosen = full[0] if full else (found[0] if found else "")
sys.stdout.write(chosen)
PY
}

sb_gbrain_verify_install() {
  python3 - "$1" "$2" "$3" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
commit = sys.argv[2]
integrity = sys.argv[3]
spec = f"github:garrytan/gbrain#{commit}"
global_dir = root / "install/global"
package_json = global_dir / "package.json"
lock = global_dir / "bun.lock"
missing = [str(path) for path in (package_json, lock) if not path.is_file()]
if missing:
    sys.stderr.write("gbrain: Bun did not write a global package.json and bun.lock\n")
    for path in missing:
        sys.stderr.write(f"gbrain: missing {path}\n")
    sys.exit(1)
recorded = package_json.read_text(encoding="utf-8", errors="replace")
recorded += "\n"
recorded += lock.read_text(encoding="utf-8", errors="replace")
if spec not in recorded:
    sys.stderr.write(f"gbrain: Bun did not record pinned commit {commit}\n")
    sys.exit(1)
lock_text = lock.read_text(encoding="utf-8", errors="replace")
if integrity not in lock_text:
    sys.stderr.write("gbrain: Bun lockfile integrity does not match scripts/lib/gbrain-pin\n")
    sys.exit(1)
PY
}

sb_gbrain_install_pinned() {
  local pin_file commit integrity spec bun_root
  pin_file=$1
  commit=$(sb_gbrain_pin_field "$pin_file" commit) || return 1
  integrity=$(sb_gbrain_pin_field "$pin_file" integrity) || return 1
  spec="github:garrytan/gbrain#${commit}"
  echo "gbrain: installing ${spec}"
  bun install -g "$spec" || return 1
  bun_root=${BUN_INSTALL:-$HOME/.bun}
  if ! sb_gbrain_verify_install "$bun_root" "$commit" "$integrity"; then
    echo "gbrain: installed package does not match the pinned commit" >&2
    return 1
  fi
  echo "gbrain: pin ok ${commit}"
}
