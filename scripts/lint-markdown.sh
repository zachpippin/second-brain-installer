#!/bin/sh
# Check markdown structure, relative links, vault wikilinks, and frontmatter.
# Usage: scripts/lint-markdown.sh [--root DIR]
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      shift
      root=$1
      ;;
    -h|--help)
      echo "Usage: scripts/lint-markdown.sh [--root DIR]"
      exit 0
      ;;
    *)
      echo "lint-markdown: unknown argument: $1" >&2
      exit 2
      ;;
  esac
  shift
done

export LINT_ROOT="$root"

python3 - <<'PY'
import os
import re
import sys
from pathlib import Path

root = Path(os.environ["LINT_ROOT"]).resolve()
vault = root / "vault"
errors = []
checked_links = 0
checked_notes = 0

LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
WIKI_RE = re.compile(r"\[\[([^\]|#]+)(#[^\]|]+)?(\|[^\]]+)?\]\]")
FENCE_RE = re.compile(r"^```.*?^```", re.MULTILINE | re.DOTALL)
REQUIRED = ("type", "tags", "created", "updated", "sources")
TYPES = {"person", "project", "topic", "session", "inbox", "map"}
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def strip_fences(text: str) -> str:
    return FENCE_RE.sub("", text)


def markdown_files(base: Path):
    if not base.is_dir():
        return
    for path in base.rglob("*.md"):
        if any(part in {".git", "node_modules"} for part in path.parts):
            continue
        yield path


def frontmatter_block(text: str):
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---\n", 4)
    if end < 0:
        return None
    return text[4:end]


def parse_keys(block: str):
    keys = {}
    current = None
    for line in block.splitlines():
        if not line.strip():
            continue
        if line.startswith(" ") or line.startswith("\t"):
            if current:
                keys.setdefault(current, "")
                keys[current] += "\n" + line
            continue
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        current = key.strip()
        keys[current] = value.strip()
    return keys


def check_frontmatter(path: Path, text: str):
    global checked_notes
    rel = path.relative_to(root).as_posix()
    if "/templates/" in f"/{rel}":
        return
    if not rel.startswith("vault/"):
        return
    if rel.startswith("vault/.obsidian/"):
        return
    checked_notes += 1
    block = frontmatter_block(text)
    if block is None:
        errors.append(f"{rel}: missing YAML frontmatter")
        return
    keys = parse_keys(block)
    for key in REQUIRED:
        if key not in keys:
            errors.append(f"{rel}: frontmatter missing {key}")
    kind = keys.get("type", "")
    if kind and kind not in TYPES:
        errors.append(f"{rel}: type {kind!r} is not one of {sorted(TYPES)}")
    for key in ("created", "updated"):
        value = keys.get(key, "")
        if value and value != "{{date}}" and not DATE_RE.match(value):
            errors.append(f"{rel}: {key} must be YYYY-MM-DD (got {value!r})")


def resolve_target(from_file: Path, target: str) -> bool:
    target = target.strip()
    if not target:
        return False
    candidate = (from_file.parent / target).resolve()
    if candidate.is_file():
        return True
    if not target.endswith(".md"):
        md = (from_file.parent / (target + ".md")).resolve()
        if md.is_file():
            return True
    return False


def resolve_wiki(target: str) -> bool:
    target = target.strip().removesuffix(".md")
    if not target:
        return False
    direct = vault / f"{target}.md"
    if direct.is_file():
        return True
    direct_file = vault / target
    if direct_file.is_file():
        return True
    stem = Path(target).name
    matches = [p for p in vault.rglob("*.md") if p.stem == stem]
    return len(matches) == 1


def check_links(path: Path, text: str):
    global checked_links
    visible = strip_fences(text)
    rel = path.relative_to(root).as_posix()
    in_vault = rel.startswith("vault/")
    for match in LINK_RE.finditer(visible):
        dest = match.group(1).strip()
        if dest.startswith(("<", "http://", "https://", "mailto:", "#")):
            continue
        dest = dest.split("#", 1)[0].strip()
        if not dest:
            errors.append(f"{rel}: empty link target")
            continue
        checked_links += 1
        if not resolve_target(path, dest):
            errors.append(f"{rel}: broken relative link ({dest})")
    if not in_vault:
        return
    for match in WIKI_RE.finditer(visible):
        dest = match.group(1).strip()
        checked_links += 1
        if not resolve_wiki(dest):
            errors.append(f"{rel}: broken wikilink [[{dest}]]")


files = list(markdown_files(root))
if not files:
    print("lint-markdown: no markdown files")
    sys.exit(1)

for path in files:
    data = path.read_bytes()
    if not data.endswith(b"\n"):
        errors.append(f"{path.relative_to(root).as_posix()}: missing final newline")
    text = data.decode("utf-8")
    check_frontmatter(path, text)
    check_links(path, text)

note_files = [
    p for p in markdown_files(vault)
    if "templates" not in p.relative_to(vault).parts and ".obsidian" not in p.relative_to(vault).parts
]
if len(note_files) < 18:
    errors.append(f"vault sample notes: expected at least 18, found {len(note_files)}")

print(f"lint-markdown: root {root}")
print(f"lint-markdown: markdown files {len(files)}")
print(f"lint-markdown: vault notes {len(note_files)}")
print(f"lint-markdown: frontmatter checked {checked_notes}")
print(f"lint-markdown: links checked {checked_links}")
if errors:
    print("lint-markdown: failed")
    for item in errors:
        print(f"  {item}")
    sys.exit(1)
print("lint-markdown: passed")
PY
