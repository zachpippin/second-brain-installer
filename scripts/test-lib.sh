#!/usr/bin/env bash
# Regression checks for scheduler quoting, stored paths, and the gbrain pin.
set -euo pipefail

ROOT=$(unset CDPATH; cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/common.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/jobs.sh"

fail() {
  echo "test-lib: $*" >&2
  exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pin="$ROOT/scripts/lib/gbrain-pin"
commit=$(sb_gbrain_pin_field "$pin" commit)
integrity=$(sb_gbrain_pin_field "$pin" integrity)
[[ $commit =~ ^[0-9a-f]{40}$ ]] || fail "pinned commit is not 40 hex: $commit"
[[ $integrity == sha512-* ]] || fail "pinned integrity is missing"
sh_commit=$(sh -c '. "$1"; sb_gbrain_pin_field "$2" commit' sh "$ROOT/scripts/lib/gbrain-pin.sh" "$pin")
[[ $sh_commit == "$commit" ]] || fail "POSIX pin reader returned $sh_commit"

printf '%s\n' 'commit latest-stable' > "$tmp/bad-pin"
if sb_gbrain_pin_field "$tmp/bad-pin" commit >/dev/null 2>"$tmp/bad-pin.err"; then
  fail "a tag name was accepted as a commit"
fi
grep -q '40-character' "$tmp/bad-pin.err" || fail "bad pin error did not mention the commit form"

spec="github:garrytan/gbrain#${commit}"
mkdir -p "$tmp/bun/install/global"
printf '{\n  "dependencies": {"gbrain": "%s"}\n}\n' "$spec" > "$tmp/bun/install/global/package.json"
cat > "$tmp/bun/install/global/bun.lock" <<EOF
{
  "workspaces": {
    "": { "dependencies": { "gbrain": "$spec" } }
  },
  "packages": {
    "gbrain": ["gbrain@github:garrytan/gbrain#${commit:0:7}", {}, "garrytan-gbrain-${commit:0:7}", "$integrity"]
  }
}
EOF
sb_gbrain_verify_install "$tmp/bun" "$commit" "$integrity"
resolved=$(sb_gbrain_resolved_commit "$tmp/bun")
[[ $resolved == "$commit" ]] || fail "resolver preferred $resolved over $commit"
if sb_gbrain_verify_install "$tmp/bun" "$commit" "sha512-not-the-recorded-hash" >/dev/null 2>"$tmp/bad-integrity.err"; then
  fail "integrity mismatch was accepted"
fi
grep -q 'integrity' "$tmp/bad-integrity.err" || fail "integrity error was unclear"
other=0123456789abcdef0123456789abcdef01234567
if sb_gbrain_verify_install "$tmp/bun" "$other" "$integrity" >/dev/null 2>"$tmp/bad-commit.err"; then
  fail "commit mismatch was accepted"
fi

users_dir=$(printf '%s%s' / Users)
stored_path="${users_dir}/Sam Rivera/Applications/Obsidian.app"
printf '%s\n' "$stored_path" > "$tmp/location"
stored=$(sb_read_stored_line "$tmp/location")
[[ $stored == "$stored_path" ]] || fail "stored path lost spaces: $stored"

data="$tmp/Sam's \$HOME 100%"
state="$tmp/state dir"
mkdir -p "$data/bin" "$state"
program="$data/bin/sync-index.sh"
marker="$tmp/ran ok"
marker_q=$(sb_shell_quote "$marker")
cat > "$program" <<EOF
#!/bin/sh
printf '%s\n' ok > $marker_q
EOF
chmod +x "$program"
logfile="$state/sync-job.log"
line=$(sb_jobs_cron_line "*/15 * * * *" "$program" "$logfile" "$SB_JOB_SYNC")
printf '%s\n' "$line" | grep -q 'second-brain-' || fail "cron line would not match doctor.sh"
unquoted="$program >> $logfile 2>&1"
if sh -c "$unquoted" 2>/dev/null; then
  fail "an unquoted path with spaces ran"
fi
[[ ! -e $marker ]] || fail "unquoted command wrote the marker"
rest=${line#\*\/15 \* \* \* \* }
command=${rest%% #*}
decoded=$(printf '%s' "$command" | python3 -c '
import sys
text = sys.stdin.read()
out = []
index = 0
while index < len(text):
    if text[index] == "\\" and index + 1 < len(text) and text[index + 1] == "%":
        out.append("%")
        index += 2
    elif text[index] == "%":
        break
    else:
        out.append(text[index])
        index += 1
sys.stdout.write("".join(out))
')
sh -c "$decoded"
[[ $(cat "$marker") == ok ]] || fail "quoted cron command did not run"
rm -f "$marker"

unit_script="$tmp/Sam Rivera/bin/sync-index.sh"
mkdir -p "$(dirname "$unit_script")"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$unit_script"
chmod +x "$unit_script"
sb_systemd_oneshot_unit "Sync the second-brain vault into gbrain" "$unit_script" > "$tmp/space.service"
grep -F "ExecStart=\"$unit_script\"" "$tmp/space.service" >/dev/null || fail "systemd unit did not quote the path"
pct_script="$tmp/bin/sync%h.sh"
mkdir -p "$(dirname "$pct_script")"
cp "$unit_script" "$pct_script"
chmod +x "$pct_script"
sb_systemd_oneshot_unit "Sync the second-brain vault into gbrain" "$pct_script" > "$tmp/percent.service"
grep -F 'sync%%h.sh' "$tmp/percent.service" >/dev/null || fail "systemd unit did not escape %h"
if command -v systemd-analyze >/dev/null 2>&1; then
  systemd-analyze verify "$tmp/space.service"
  systemd-analyze verify "$tmp/percent.service"
elif [[ $(uname -s) == Linux ]]; then
  fail "systemd-analyze is required on Linux"
fi

plist_path="$data/bin/sync-index.sh"
sb_launchd_plist "$SB_JOB_SYNC" "$plist_path" '  <key>StartInterval</key>
  <integer>900</integer>' > "$tmp/sync.plist"
python3 - "$plist_path" "$tmp/sync.plist" <<'PY'
import plistlib
import sys

expected, path = sys.argv[1], sys.argv[2]
with open(path, "rb") as handle:
    data = plistlib.load(handle)
program = data.get("ProgramArguments")
if program != [expected]:
    sys.exit(f"launchd program {program!r} != {[expected]!r}")
if data.get("StartInterval") != 900:
    sys.exit(f"launchd interval {data.get('StartInterval')!r}")
PY

amp="$tmp/A & B <C>/sync.sh"
mkdir -p "$(dirname "$amp")"
sb_launchd_plist "$SB_JOB_UPDATE" "$amp" '  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>4</integer>
    <key>Minute</key>
    <integer>15</integer>
  </dict>' > "$tmp/update.plist"
python3 - "$amp" "$tmp/update.plist" <<'PY'
import plistlib
import sys

expected, path = sys.argv[1], sys.argv[2]
with open(path, "rb") as handle:
    data = plistlib.load(handle)
if data.get("ProgramArguments") != [expected]:
    sys.exit(f"launchd xml program {data.get('ProgramArguments')!r}")
interval = data.get("StartCalendarInterval") or {}
if interval.get("Hour") != 4 or interval.get("Minute") != 15:
    sys.exit(f"launchd calendar {interval!r}")
PY

if command -v pwsh >/dev/null 2>&1; then
  home_dir=$(printf '%s%s' / home)
  win_script="${home_dir}/Sam Rivera/.local/share/second-brain/bin/sync-index.sh"
  quoted=$(SB_QUOTE_TASK_SCRIPT="$win_script" pwsh -NoProfile -File "$ROOT/scripts/install.ps1")
  expected="-d Ubuntu -- bash -lc \"'${win_script}'\""
  [[ $quoted == "$expected" ]] || fail "windows task argument: $quoted"
fi

echo "test-lib: passed"
