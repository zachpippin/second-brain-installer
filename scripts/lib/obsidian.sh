#!/usr/bin/env bash
# Official Obsidian downloads and health checks. Notes are not modified.

sb_obsidian_dir() {
  printf '%s\n' "$SB_DATA_DIR/obsidian"
}

sb_obsidian_app() {
  local os
  os=$(sb_os)
  case "$os" in
    macos) printf '%s\n' "$HOME/Applications/Obsidian.app" ;;
    *) printf '%s\n' "$(sb_obsidian_dir)/Obsidian.AppImage" ;;
  esac
}

sb_obsidian_release() {
  local os arch
  os=$1
  arch=$2
  json=$(curl -fsSL -A second-brain-installer \
    "https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest")
  python3 - "$os" "$arch" "$json" <<'PY'
import json
import sys

os_name, arch, raw = sys.argv[1], sys.argv[2], sys.argv[3]
data = json.loads(raw)
tag = data.get("tag_name") or ""
version = tag[1:] if tag.startswith("v") else tag
if not version:
    sys.exit("obsidian: release tag missing")

def pick(predicate):
    for asset in data.get("assets") or []:
        name = asset.get("name") or ""
        if predicate(name):
            return asset
    return None

if os_name == "linux" and arch == "x86_64":
    asset = pick(lambda name: name.endswith(".AppImage") and "arm64" not in name.lower())
elif os_name == "linux" and arch in {"aarch64", "arm64"}:
    asset = pick(lambda name: name.endswith("-arm64.AppImage"))
elif os_name == "macos":
    asset = pick(lambda name: name.endswith(".dmg"))
else:
    sys.exit("obsidian: no official asset for this OS in the bash installer")

if asset is None:
    sys.exit("obsidian: matching release asset was not found")
print(version)
print(asset["browser_download_url"])
print(asset["name"])
PY
}

sb_obsidian_write_stub() {
  local dest
  dest=$(sb_obsidian_dir)
  mkdir -p "$dest"
  cat > "$dest/Obsidian.AppImage" <<'EOF'
#!/bin/sh
# obsidian-stub
echo "obsidian-stub 0.0.0-test"
exit 0
EOF
  chmod +x "$dest/Obsidian.AppImage"
  printf '%s\n' "0.0.0-test" > "$dest/VERSION"
  echo "obsidian: installed test stub 0.0.0-test"
}

sb_obsidian_health() {
  local app=$1
  local version_file size version
  version_file="$(sb_obsidian_dir)/VERSION"
  if [[ ! -x $app ]]; then
    echo "obsidian: health failed, binary is not executable: $app" >&2
    return 1
  fi
  if [[ ! -f $version_file ]]; then
    echo "obsidian: health failed, version file missing" >&2
    return 1
  fi
  version=$(tr -d '[:space:]' < "$version_file")
  if [[ -z $version ]]; then
    echo "obsidian: health failed, version file is empty" >&2
    return 1
  fi
  if head -n 5 "$app" | grep -q 'obsidian-stub'; then
    "$app" --version >/dev/null
    echo "obsidian: health ok stub $version"
    return 0
  fi
  size=$(wc -c < "$app" | tr -d '[:space:]')
  if [[ "$size" -lt 1000000 ]]; then
    echo "obsidian: health failed, binary is unexpectedly small ($size bytes)" >&2
    return 1
  fi
  if [[ -n ${DISPLAY:-} || -n ${WAYLAND_DISPLAY:-} ]]; then
    if ! timeout 25 "$app" --version >/dev/null 2>&1; then
      echo "obsidian: health failed, launch returned an error" >&2
      return 1
    fi
    echo "obsidian: health ok launched $version"
    return 0
  fi
  echo "obsidian: health ok version $version (launch skipped, no display)"
}

sb_obsidian_install_linux() {
  local dest current meta version url name tmp app
  if [[ ${SECOND_BRAIN_OBSIDIAN_STUB:-} == 1 ]]; then
    sb_obsidian_write_stub
    return 0
  fi
  dest=$(sb_obsidian_dir)
  mkdir -p "$dest"
  app="$dest/Obsidian.AppImage"
  meta=$(sb_obsidian_release linux "$(uname -m)")
  version=$(printf '%s\n' "$meta" | sed -n '1p')
  url=$(printf '%s\n' "$meta" | sed -n '2p')
  name=$(printf '%s\n' "$meta" | sed -n '3p')
  current=""
  if [[ -f $dest/VERSION ]]; then
    current=$(tr -d '[:space:]' < "$dest/VERSION")
  fi
  if [[ -n $current && $current == "$version" && -x $app ]]; then
    echo "obsidian: already installed $version ($name)"
    return 0
  fi
  echo "obsidian: downloading $name"
  tmp=$(mktemp "$dest/download.XXXXXX")
  if ! curl -fL --retry 3 -o "$tmp" "$url"; then
    rm -f "$tmp"
    echo "obsidian: download failed" >&2
    return 1
  fi
  chmod +x "$tmp"
  if [[ -f $app ]]; then
    mv "$app" "$app.previous"
  fi
  mv "$tmp" "$app"
  printf '%s\n' "$version" > "$dest/VERSION"
  if ! sb_obsidian_health "$app"; then
    if [[ -f $app.previous ]]; then
      mv "$app.previous" "$app"
      echo "obsidian: restored the previous binary after a failed health check" >&2
    fi
    return 1
  fi
  echo "obsidian: installed $version"
}

sb_obsidian_install_macos() {
  local dest meta version url name tmp mount app plist
  dest="$HOME/Applications"
  mkdir -p "$dest"
  app="$dest/Obsidian.app"
  meta=$(sb_obsidian_release macos "$(uname -m)")
  version=$(printf '%s\n' "$meta" | sed -n '1p')
  url=$(printf '%s\n' "$meta" | sed -n '2p')
  name=$(printf '%s\n' "$meta" | sed -n '3p')
  echo "obsidian: downloading $name"
  mkdir -p "$(sb_obsidian_dir)"
  tmp=$(mktemp "$(sb_obsidian_dir)/download.XXXXXX.dmg")
  if ! curl -fL --retry 3 -o "$tmp" "$url"; then
    rm -f "$tmp"
    echo "obsidian: download failed" >&2
    return 1
  fi
  if [[ -d $app ]]; then
    rm -rf "$app.previous"
    mv "$app" "$app.previous"
  fi
  mount=$(mktemp -d)
  if ! hdiutil attach -nobrowse -mountpoint "$mount" "$tmp"; then
    rm -f "$tmp"
    echo "obsidian: could not mount the disk image" >&2
    return 1
  fi
  local bundle
  bundle=$(find "$mount" -maxdepth 2 -name 'Obsidian.app' -type d | head -n 1)
  if [[ -z $bundle ]]; then
    hdiutil detach "$mount" >/dev/null || true
    echo "obsidian: disk image did not contain Obsidian.app" >&2
    return 1
  fi
  cp -R "$bundle" "$app"
  hdiutil detach "$mount" >/dev/null || true
  rm -f "$tmp"
  rmdir "$mount" 2>/dev/null || true
  plist="$app/Contents/Info.plist"
  if [[ -f $plist ]]; then
    version=$(python3 - "$plist" "$version" <<'PY'
import sys
try:
    import plistlib
    with open(sys.argv[1], "rb") as handle:
        data = plistlib.load(handle)
    print(data.get("CFBundleShortVersionString") or sys.argv[2])
except Exception:
    print(sys.argv[2])
PY
)
  fi
  printf '%s\n' "$version" > "$(sb_obsidian_dir)/VERSION"
  echo "obsidian: installed $version in $app"
  echo "obsidian: first launch may be blocked by Gatekeeper. See docs/permissions-macos.md."
}
