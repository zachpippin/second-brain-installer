#!/bin/sh
# Copy the template vault, then register it as a gbrain source and import it.
# Safe to run twice: an existing destination is not overwritten, and an
# existing source id is reused when its path matches.
#
# Usage:
#   scripts/setup.sh DEST [--source-id ID] [--search-mode MODE] [--dry-run] [--skip-install]
#
# Environment:
#   GBRAIN_HOME         respected; not overwritten
#   GBRAIN_SOURCE       default source id (obsidian-vault)
#   GBRAIN_SEARCH_MODE  conservative, balanced, or tokenmax (fresh init only)
set -eu

root=$(unset CDPATH; cd -- "$(dirname "$0")/.." && pwd)
dest=
source_id=${GBRAIN_SOURCE:-obsidian-vault}
search_mode=${GBRAIN_SEARCH_MODE:-conservative}
dry_run=0
skip_install=0

usage() {
  echo "Usage: scripts/setup.sh DEST [--source-id ID] [--search-mode MODE] [--dry-run] [--skip-install]"
  echo "Copy vault/ to DEST, init a keyless gbrain if needed, and import the vault."
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --source-id)
      shift
      source_id=$1
      ;;
    --search-mode)
      shift
      search_mode=$1
      ;;
    --dry-run)
      dry_run=1
      ;;
    --skip-install)
      skip_install=1
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "setup: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [ -n "$dest" ]; then
        echo "setup: unexpected extra argument: $1" >&2
        usage >&2
        exit 2
      fi
      dest=$1
      ;;
  esac
  shift
done

if [ -z "$dest" ]; then
  usage >&2
  exit 2
fi

case "$search_mode" in
  conservative|balanced|tokenmax) ;;
  *)
    echo "setup: --search-mode must be conservative, balanced, or tokenmax" >&2
    exit 2
    ;;
esac

# Source ids follow `gbrain sources --help`: [a-z0-9-]{1,32}, and the
# stricter form from the multi-source guide (start and end alphanumeric).
if ! printf '%s' "$source_id" | grep -Eq '^[a-z0-9]([a-z0-9-]{0,30}[a-z0-9])?$'; then
  echo "setup: source id must match [a-z0-9]([a-z0-9-]{0,30}[a-z0-9])?" >&2
  exit 2
fi

mkdir -p -- "$(dirname "$dest")"
if [ "${dest#/}" = "$dest" ]; then
  dest=$(unset CDPATH; cd -- "$(dirname "$dest")" && pwd)/$(basename "$dest")
fi
template=$(unset CDPATH; cd -- "$root/vault" && pwd)

if [ "$dest" = "$template" ]; then
  echo "setup: destination must be outside vault/" >&2
  exit 1
fi

echo "setup: template $template"
echo "setup: destination $dest"
echo "setup: source id $source_id"
echo "setup: search mode $search_mode (used only when creating a brain)"

if [ "$dry_run" -eq 1 ]; then
  echo "setup: dry-run, no files or gbrain state changed"
  echo "next: re-run without --dry-run"
  exit 0
fi

if [ ! -d "$template" ]; then
  echo "setup: template vault is missing: $template" >&2
  exit 1
fi

for cmd in git python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "setup: required command not found: $cmd" >&2
    exit 1
  fi
done

PATH="$HOME/.bun/bin:$PATH"
export PATH

if ! command -v gbrain >/dev/null 2>&1; then
  if [ "$skip_install" -eq 1 ]; then
    echo "setup: gbrain is not on PATH. Install with:" >&2
    echo "  bun install -g github:garrytan/gbrain#latest-stable" >&2
    exit 1
  fi
  if ! command -v bun >/dev/null 2>&1; then
    echo "setup: Bun 1.4.4 or newer is required to install gbrain." >&2
    echo "Install Bun from https://bun.sh and re-run." >&2
    exit 1
  fi
  bun_major=$(bun --version | cut -d. -f1)
  bun_minor=$(bun --version | cut -d. -f2)
  bun_patch=$(bun --version | cut -d. -f3 | cut -c1-2)
  if [ "$bun_major" -lt 1 ] \
    || { [ "$bun_major" -eq 1 ] && [ "$bun_minor" -lt 4 ]; } \
    || { [ "$bun_major" -eq 1 ] && [ "$bun_minor" -eq 4 ] && [ "$bun_patch" -lt 4 ]; }; then
    echo "setup: Bun $(bun --version) is older than 1.4.4" >&2
    exit 1
  fi
  echo "setup: installing gbrain from github:garrytan/gbrain#latest-stable"
  echo "setup: do not install the unrelated npm package named gbrain"
  bun install -g github:garrytan/gbrain#latest-stable
fi

if ! command -v gbrain >/dev/null 2>&1; then
  echo "setup: gbrain is still not on PATH after install" >&2
  exit 1
fi

echo "setup: using $(command -v gbrain)"

mkdir -p "$dest"
# Copy missing files only, including dotfiles. Do not overwrite a destination
# the user has already edited.
python3 - "$template" "$dest" <<'PY'
import os
import shutil
import sys
from pathlib import Path

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
for dirpath, dirnames, filenames in os.walk(src):
    rel = Path(dirpath).relative_to(src)
    target_dir = dst / rel
    target_dir.mkdir(parents=True, exist_ok=True)
    for name in filenames:
        source = Path(dirpath) / name
        target = target_dir / name
        if target.exists():
            continue
        shutil.copy2(source, target)
PY

if [ ! -f "$dest/AGENTS.md" ] && [ -f "$template/AGENTS.md" ]; then
  cp "$template/AGENTS.md" "$dest/AGENTS.md"
fi
if [ ! -f "$dest/CLAUDE.md" ] && [ -f "$template/CLAUDE.md" ]; then
  cp "$template/CLAUDE.md" "$dest/CLAUDE.md"
fi

if ! git -C "$dest" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$dest" init -b main
fi

if ! git -C "$dest" rev-parse --verify HEAD >/dev/null 2>&1; then
  git -C "$dest" add -A
  git -C "$dest" -c user.email=notes@example.com -c user.name="Vault Template" commit -m "Initial vault snapshot"
fi

engine_json=$(gbrain engine status --json 2>/dev/null || true)
need_init=$(printf '%s' "$engine_json" | python3 -c '
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    print("yes")
    raise SystemExit(0)
data = json.loads(raw)
if data.get("effective_engine"):
    print("no")
else:
    print("yes")
')

if [ "$need_init" = "yes" ]; then
  echo "setup: creating a keyless local brain (PGLite, no embeddings, database-only content root)"
  gbrain init --pglite --no-embedding --non-interactive --search-mode "$search_mode" --db-only
else
  echo "setup: reusing the existing gbrain brain (init is not re-run)"
fi

echo "setup: applying pending migrations (no autopilot install)"
gbrain apply-migrations --yes --no-autopilot-install

list_json=$(gbrain sources list --json)
source_state=$(printf '%s' "$list_json" | python3 -c '
import json, os, sys
data = json.loads(sys.stdin.read())
sources = data.get("sources", data if isinstance(data, list) else [])
sid = sys.argv[1]
dest = os.path.realpath(sys.argv[2])
for source in sources:
    if source.get("id") != sid:
        continue
    path = source.get("local_path") or ""
    try:
        same = os.path.realpath(path) == dest
    except OSError:
        same = False
    print("match" if same else "differ")
    raise SystemExit(0)
print("missing")
' "$source_id" "$dest")

case "$source_state" in
  missing)
    echo "setup: registering source $source_id"
    gbrain sources add "$source_id" --path "$dest" --federated --name "Obsidian vault"
    ;;
  match)
    echo "setup: source $source_id already points at this vault"
    ;;
  differ)
    echo "setup: source $source_id is already registered at a different path." >&2
    echo "Inspect: gbrain sources list --json" >&2
    echo "To retarget without deleting pages: gbrain sources set-path $source_id $dest" >&2
    exit 1
    ;;
  *)
    echo "setup: could not read gbrain sources list --json" >&2
    exit 1
    ;;
esac

gbrain sources federate "$source_id"
( cd "$dest" && gbrain sources attach "$source_id" )

echo "setup: importing markdown (no embeddings)"
gbrain import "$dest" --source "$source_id" --no-embed

echo "setup: recording a git sync checkpoint without pulling or embedding"
gbrain sync --source "$source_id" --no-pull --no-embed

cat <<EOF

setup: done

Open this folder as an Obsidian vault:
  $dest

Ask an agent:
  What did Sam Rivera decide about offline bed maps in the garden planner?
It should find wiki/projects/garden-planner and append sessions/YYYY-MM-DD.md.

Search from the shell:
  gbrain search "offline bed map" --source $source_id

After you edit notes, re-import them:
  $root/scripts/sync.sh $dest

This script does not enable ambient writeback, embeddings, or skill publishing.
Init may suggest \`gbrain config set memory.auto_writeback salient\`. Leave it
unset unless you want that. Keyword search works without an API key.

The starter vault includes AGENTS.md. Search before asking, and write
decisions back into the wiki and sessions/. MCP examples are in
$root/scripts/mcp/.
EOF
