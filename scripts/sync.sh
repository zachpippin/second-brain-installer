#!/bin/sh
# Re-import vault markdown into gbrain, then advance the git sync checkpoint.
# Safe to run twice. Uncommitted notes are read by \`gbrain import\`.
# \`gbrain sync\` itself only indexes committed files, and this script passes
# --no-pull so it does not fetch into the vault.
#
# Usage: scripts/sync.sh DEST [--source-id ID]
# The source id defaults to GBRAIN_SOURCE, then the vault's .gbrain-source
# file, then obsidian-vault.
set -eu

dest=
source_id=${GBRAIN_SOURCE:-}

usage() {
  echo "Usage: scripts/sync.sh DEST [--source-id ID]"
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
    --)
      shift
      break
      ;;
    -*)
      echo "sync: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [ -n "$dest" ]; then
        echo "sync: unexpected extra argument: $1" >&2
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

if [ "${dest#/}" = "$dest" ]; then
  if [ ! -d "$(dirname "$dest")" ]; then
    echo "sync: directory does not exist: $(dirname "$dest")" >&2
    exit 1
  fi
  dest=$(unset CDPATH; cd -- "$(dirname "$dest")" && pwd)/$(basename "$dest")
fi

if [ ! -d "$dest" ]; then
  echo "sync: vault directory does not exist: $dest" >&2
  exit 1
fi

if [ -z "$source_id" ] && [ -f "$dest/.gbrain-source" ]; then
  source_id=$(tr -d '[:space:]' < "$dest/.gbrain-source")
fi
if [ -z "$source_id" ]; then
  source_id=obsidian-vault
fi

PATH="$HOME/.bun/bin:$PATH"
export PATH

if ! command -v gbrain >/dev/null 2>&1; then
  echo "sync: gbrain is not on PATH. Run scripts/setup.sh first." >&2
  exit 1
fi

echo "sync: importing $dest into source $source_id"
gbrain import "$dest" --source "$source_id" --no-embed

echo "sync: git checkpoint (no pull, no embed)"
gbrain sync --source "$source_id" --no-pull --no-embed

echo "sync: done"
echo "search: gbrain search \"query\" --source $source_id"
