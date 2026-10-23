#!/bin/sh
# Fail if the tree looks like it contains secrets, private contact data,
# non-documentation IP addresses, overlay-network hostnames, or home paths.
# Optional denylist: .scrub-denylist at the repo root (gitignored).
# Usage: scripts/scrub-check.sh [--self-test] [--root DIR]
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
mode=scan
while [ $# -gt 0 ]; do
  case "$1" in
    --self-test)
      mode=self-test
      ;;
    --root)
      shift
      root=$1
      ;;
    -h|--help)
      echo "Usage: scripts/scrub-check.sh [--self-test] [--root DIR]"
      exit 0
      ;;
    *)
      echo "scrub-check: unknown argument: $1" >&2
      exit 2
      ;;
  esac
  shift
done

export SCRUB_ROOT="$root"
export SCRUB_MODE="$mode"

python3 - <<'PY'
import ipaddress
import os
import re
import sys
import tempfile
from pathlib import Path

root = Path(os.environ["SCRUB_ROOT"]).resolve()
mode = os.environ["SCRUB_MODE"]

SKIP_DIRS = {
    ".git",
    "node_modules",
    ".gbrain",
    "dist",
    "build",
    "venv",
    "__pycache__",
}
SKIP_SUFFIXES = {
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".pdf",
    ".zip", ".gz", ".woff", ".woff2", ".pyc", ".pglite",
}

DOC_V4 = (
    ipaddress.ip_network("192.0.2.0/24"),
    ipaddress.ip_network("198.51.100.0/24"),
    ipaddress.ip_network("203.0.113.0/24"),
)
DOC_V6 = ipaddress.ip_network("2001:db8::/32")

IPV4_RE = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")
IPV6_RE = re.compile(
    r"(?<![A-Za-z0-9])(?:[0-9A-Fa-f]{0,4}:){2,7}[0-9A-Fa-f]{0,4}(?![A-Za-z0-9])"
)
EMAIL_RE = re.compile(r"\b[A-Za-z0-9._%+-]+@([A-Za-z0-9.-]+\.[A-Za-z]{2,})\b")
PHONE_RE = re.compile(
    r"(?<!\d)(?:\+\d{1,3}[\s.-]?)?(?:\(\d{3}\)|\d{3})[\s.-]\d{3}[\s.-]\d{4}(?!\d)"
)
HOME_RE = re.compile(r"(?<![A-Za-z0-9])/(?:Users|home)/[A-Za-z0-9._-]+")
# docs/demo.tape records against a placeholder account. Only that exact
# directory name is ignored. Any other account name still fails.
HOME_PLACEHOLDERS = {"/home/demo", "/Users/demo"}

# Built so this file does not contain the forbidden hostname text.
HOST_SUFFIX = "." + "ts" + "." + "net"
HOST_WORD = "tail" + "net"
HOST_RE = re.compile(re.escape(HOST_SUFFIX), re.IGNORECASE)
HOST_WORD_RE = re.compile(r"\b" + HOST_WORD + r"\b", re.IGNORECASE)

KEY_HEADER = "-----BEGIN " + "PRIVATE" + " KEY-----"
SECRET_RES = [
    re.compile(re.escape(KEY_HEADER)),
    re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}\b"),
    re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}\b"),
    re.compile(r"\bsk-ant-[A-Za-z0-9_-]{20,}\b"),
    re.compile(r"\bsk-[A-Za-z0-9]{20,}\b"),
    re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b"),
    re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b"),
    re.compile(
        r"(?i)\b(?:api[_-]?key|secret|access[_-]?token|auth[_-]?token|password|passwd)"
        r"\b\s*[:=]\s*['\"]?[A-Za-z0-9_+/=-]{20,}"
    ),
]


def allow_email(domain: str) -> bool:
    domain = domain.lower().rstrip(".")
    return domain == "example.com" or domain.endswith(".example.com")


def ipv4_bad(text: str):
    found = []
    for match in IPV4_RE.finditer(text):
        raw = match.group(0)
        try:
            addr = ipaddress.ip_address(raw)
        except ValueError:
            continue
        if not any(addr in net for net in DOC_V4):
            found.append(raw)
    return found


def ipv6_bad(text: str):
    found = []
    for match in IPV6_RE.finditer(text):
        raw = match.group(0).strip(":")
        if raw.count(":") < 2:
            continue
        try:
            addr = ipaddress.ip_address(raw)
        except ValueError:
            continue
        if addr not in DOC_V6:
            found.append(raw)
    return found


def scan_text(rel: str, text: str, denylist):
    hits = []

    def add(rule, detail):
        hits.append((rel, rule, detail))

    for secret_re in SECRET_RES:
        if secret_re.search(text):
            add("secret", secret_re.pattern[:48])
            break
    for match in EMAIL_RE.finditer(text):
        if not allow_email(match.group(1)):
            add("email", match.group(0))
            break
    if PHONE_RE.search(text):
        add("phone", "phone-number pattern")
    bad4 = ipv4_bad(text)
    if bad4:
        add("ip", bad4[0])
    bad6 = ipv6_bad(text)
    if bad6:
        add("ip", bad6[0])
    if HOST_RE.search(text) or HOST_WORD_RE.search(text):
        add("hostname", "overlay-network hostname")
    for home in HOME_RE.finditer(text):
        if home.group(0) not in HOME_PLACEHOLDERS:
            add("home-path", home.group(0))
            break
    lowered = text.casefold()
    for term in denylist:
        if term.casefold() in lowered:
            add("denylist", term)
            break
    return hits


def load_denylist(base: Path):
    path = base / ".scrub-denylist"
    if not path.is_file():
        return [], False
    terms = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        item = line.strip()
        if not item or item.startswith("#"):
            continue
        if len(item) < 3:
            print(f"scrub-check: skipping denylist term shorter than 3 characters", file=sys.stderr)
            continue
        terms.append(item)
    return terms, True


def iter_files(base: Path):
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".git")]
        for name in filenames:
            path = Path(dirpath) / name
            if path.name == ".scrub-denylist":
                continue
            if path.suffix.lower() in SKIP_SUFFIXES:
                continue
            yield path


def scan_tree(base: Path):
    denylist, present = load_denylist(base)
    hits = []
    scanned = 0
    for path in iter_files(base):
        try:
            data = path.read_bytes()
        except OSError as exc:
            hits.append((str(path), "read-error", str(exc)))
            continue
        if b"\0" in data[:8192]:
            continue
        text = data.decode("utf-8", errors="replace")
        rel = str(path.relative_to(base))
        scanned += 1
        hits.extend(scan_text(rel, text, denylist))
    return hits, scanned, present, len(denylist)


def print_report(base: Path, hits, scanned, denylist_present, denylist_count):
    print(f"scrub-check: root {base}")
    print(f"scrub-check: files {scanned}")
    print("secrets: " + ("FAIL" if any(h[1] == "secret" for h in hits) else "ok"))
    print("emails: " + ("FAIL" if any(h[1] == "email" for h in hits) else "ok"))
    print("phones: " + ("FAIL" if any(h[1] == "phone" for h in hits) else "ok"))
    print("ips: " + ("FAIL" if any(h[1] == "ip" for h in hits) else "ok"))
    print("hostnames: " + ("FAIL" if any(h[1] == "hostname" for h in hits) else "ok"))
    print("home-paths: " + ("FAIL" if any(h[1] == "home-path" for h in hits) else "ok"))
    if denylist_present:
        print(f"denylist: {denylist_count} term(s)" + (" FAIL" if any(h[1] == "denylist" for h in hits) else " ok"))
    else:
        print("denylist: skipped (no .scrub-denylist)")
    if hits:
        print("scrub-check: failed")
        for rel, rule, detail in hits:
            print(f"  {rel}: {rule}: {detail}")
        return 1
    print("scrub-check: passed")
    return 0


def self_test():
    failures = []

    def expect(label, text, rules):
        hits = scan_text("fixture", text, [])
        got = {h[1] for h in hits}
        if got != set(rules):
            failures.append(f"{label}: expected {sorted(rules)} got {sorted(got)} hits={hits}")

    expect("clean note", "Sam uses notes@example.com and 192.0.2.10.\ncreated: 2026-04-11\n", [])
    expect("doc ranges", "198.51.100.20 and 203.0.113.9 and 2001:db8::10\n", [])
    expect("version-like", "checked gbrain 0.60.411.0 during setup\n", [])
    expect("other email", "write to sam@" + "example.org please\n", ["email"])
    expect("phone", "call " + "555" + "-010-0199 tomorrow\n", ["phone"])
    expect("public ip", "resolver " + "8" + ".8.8.8\n", ["ip"])
    expect("private ip", "lan " + "192" + ".168.1.20\n", ["ip"])
    expect("loopback", "bind " + "127" + ".0.0.1\n", ["ip"])
    expect("hostname suffix", "see host.example." + "ts" + "." + "net" + " later\n", ["hostname"])
    expect("hostname word", "do not publish a " + HOST_WORD + " name\n", ["hostname"])
    expect("users home", "path /" + "Users" + "/ada/notes\n", ["home-path"])
    expect("linux home", "path /" + "home" + "/ada/notes\n", ["home-path"])
    expect("placeholder home", "HOME=/home/demo\n", [])
    expect("placeholder users", "path /Users/demo/notes\n", [])
    expect("demo prefix", "path /" + "home" + "/demo-other/notes\n", ["home-path"])
    expect("demo then real", "a /home/demo b /" + "home" + "/ada\n", ["home-path"])
    expect("aws key", "AKIA" + "IOSFODNN7EXAMPLE\n", ["secret"])
    expect("token assignment", "api_key=" + ("a" * 24) + "\n", ["secret"])
    expect("private key", KEY_HEADER + "\n", ["secret"])
    expect("example email ok", "contact notes@example.com\n", [])
    expect("subdomain email ok", "contact notes@mail.example.com\n", [])

    with tempfile.TemporaryDirectory() as tmp:
        base = Path(tmp)
        (base / "ok.md").write_text("notes@example.com\n192.0.2.8\n", encoding="utf-8")
        (base / ".scrub-denylist").write_text("# comment\n\nWorkbenchHookPhrase\n", encoding="utf-8")
        (base / "bad.md").write_text("The WorkbenchHookPhrase is here.\n", encoding="utf-8")
        hits, scanned, present, count = scan_tree(base)
        if not present or count != 1:
            failures.append(f"denylist load failed present={present} count={count}")
        if scanned != 2:
            failures.append(f"expected 2 scanned files, got {scanned}")
        rules = {(h[0], h[1]) for h in hits}
        if ("bad.md", "denylist") not in rules:
            failures.append(f"denylist miss: {hits}")
        if any(h[0] == "ok.md" for h in hits):
            failures.append(f"clean file flagged: {hits}")

    if failures:
        print("scrub-check self-test: failed")
        for item in failures:
            print(f"  {item}")
        return 1
    print("scrub-check self-test: passed")
    return 0


if mode == "self-test":
    sys.exit(self_test())

if not root.is_dir():
    print(f"scrub-check: root is not a directory: {root}", file=sys.stderr)
    sys.exit(2)

hits, scanned, present, count = scan_tree(root)
sys.exit(print_report(root, hits, scanned, present, count))
PY
