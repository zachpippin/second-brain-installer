#!/usr/bin/env bash
# Official Obsidian downloads and health checks. Notes are not modified.

sb_obsidian_dir() {
  printf '%s\n' "$SB_DATA_DIR/obsidian"
}

sb_obsidian_app() {
  local recorded os
  if [[ -f $(sb_obsidian_dir)/location ]]; then
    recorded=$(tr -d '[:space:]' < "$(sb_obsidian_dir)/location")
    if [[ -n $recorded ]]; then
      printf '%s\n' "$recorded"
      return 0
    fi
  fi
  os=$(sb_os)
  case "$os" in
    macos) printf '%s\n' "$HOME/Applications/Obsidian.app" ;;
    *) printf '%s\n' "$(sb_obsidian_dir)/Obsidian.AppImage" ;;
  esac
}

sb_obsidian_managed() {
  if [[ -f $(sb_obsidian_dir)/managed ]]; then
    tr -d '[:space:]' < "$(sb_obsidian_dir)/managed"
  fi
}

sb_obsidian_mark_owned() {
  local app
  app=$(sb_realpath "$1")
  mkdir -p "$SB_STATE_DIR"
  printf '%s\n' "$app" > "$SB_STATE_DIR/obsidian-owned"
}

sb_obsidian_is_owned() {
  local owned target
  [[ -f $SB_STATE_DIR/obsidian-owned ]] || return 1
  owned=$(tr -d '[:space:]' < "$SB_STATE_DIR/obsidian-owned")
  target=$(sb_realpath "$1")
  [[ -n $owned && $owned == "$target" ]]
}

sb_obsidian_remember() {
  local app=$1 managed=$2
  local dir
  dir=$(sb_obsidian_dir)
  mkdir -p "$dir"
  printf '%s\n' "$app" > "$dir/location"
  printf '%s\n' "$managed" > "$dir/managed"
  if [[ $managed == installer ]]; then
    sb_obsidian_mark_owned "$app"
  fi
}

sb_obsidian_find_existing() {
  local candidate ours system_app
  case "$(sb_os)" in
    macos)
      system_app=${SB_OBSIDIAN_SYSTEM_APP:-/Applications/Obsidian.app}
      if [[ -x $system_app/Contents/MacOS/Obsidian ]]; then
        printf '%s\n' "$system_app"
        return 0
      fi
      candidate="$HOME/Applications/Obsidian.app"
      if [[ -x $candidate/Contents/MacOS/Obsidian ]] && ! sb_obsidian_is_owned "$candidate"; then
        printf '%s\n' "$candidate"
        return 0
      fi
      ;;
    linux)
      ours="$(sb_obsidian_dir)/Obsidian.AppImage"
      if command -v obsidian >/dev/null 2>&1; then
        candidate=$(command -v obsidian)
        if [[ $(sb_realpath "$candidate") != $(sb_realpath "$ours") ]]; then
          printf '%s\n' "$candidate"
          return 0
        fi
      fi
      for candidate in /opt/Obsidian/obsidian /usr/lib/obsidian/obsidian "$HOME/.local/bin/obsidian"; do
        if [[ -x $candidate ]]; then
          printf '%s\n' "$candidate"
          return 0
        fi
      done
      if command -v flatpak >/dev/null 2>&1 && flatpak info md.obsidian.Obsidian >/dev/null 2>&1; then
        printf '%s\n' "flatpak:md.obsidian.Obsidian"
        return 0
      fi
      if command -v snap >/dev/null 2>&1 && snap list obsidian >/dev/null 2>&1; then
        printf '%s\n' "snap:obsidian"
        return 0
      fi
      ;;
  esac
  return 1
}

sb_obsidian_use_existing() {
  local existing version
  existing=$1
  sb_obsidian_remember "$existing" existing
  version=""
  if [[ -r $existing/Contents/Info.plist ]]; then
    version=$(sb_obsidian_plist_version "$existing/Contents/Info.plist")
  fi
  if [[ -n $version ]]; then
    printf '%s\n' "$version" > "$(sb_obsidian_dir)/VERSION"
  fi
  echo "obsidian: using existing install at $existing${version:+ ($version)}"
  echo "obsidian: leaving updates to Obsidian's own updater"
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
  export SB_OBSIDIAN_FRESH=1
  echo "obsidian: installed test stub 0.0.0-test"
}

sb_obsidian_plist_version() {
  python3 - "$1" <<'PY'
import sys
try:
    import plistlib
    with open(sys.argv[1], "rb") as handle:
        data = plistlib.load(handle)
    sys.stdout.write(str(data.get("CFBundleShortVersionString") or ""))
except Exception:
    sys.stdout.write("")
PY
}

sb_obsidian_installed_version() {
  local app plist version
  app=$(sb_obsidian_app)
  if [[ -d $app && -r $app/Contents/Info.plist ]]; then
    version=$(sb_obsidian_plist_version "$app/Contents/Info.plist")
    if [[ -n $version ]]; then
      printf '%s\n' "$version"
      return 0
    fi
  fi
  if [[ -f $(sb_obsidian_dir)/VERSION ]]; then
    tr -d '[:space:]' < "$(sb_obsidian_dir)/VERSION"
  fi
}

sb_obsidian_quarantined() {
  local target=$1
  [[ $(sb_os) == macos ]] || return 1
  command -v xattr >/dev/null 2>&1 || return 1
  [[ -e $target ]] || return 1
  xattr -p com.apple.quarantine "$target" >/dev/null 2>&1
}

sb_obsidian_restore_previous() {
  local app=$1
  if [[ ! -e $app.previous ]]; then
    echo "obsidian: no previous copy to restore" >&2
    return 1
  fi
  rm -rf "$app"
  mv "$app.previous" "$app"
  echo "update: restored the previous Obsidian app"
}

sb_obsidian_health() {
  local app=$1
  local version_file size version bin plist managed
  version_file="$(sb_obsidian_dir)/VERSION"
  managed=$(sb_obsidian_managed || true)
  if [[ $managed == existing && ( $app == flatpak:* || $app == snap:* ) ]]; then
    echo "obsidian: health ok existing $app"
    return 0
  fi
  if [[ $managed == existing && -f $app && -x $app && ! -d $app ]]; then
    echo "obsidian: health ok existing $app"
    return 0
  fi
  if [[ -d $app ]]; then
    bin="$app/Contents/MacOS/Obsidian"
    plist="$app/Contents/Info.plist"
    if [[ ! -x $bin ]]; then
      echo "obsidian: health failed, bundle executable missing: $bin" >&2
      return 1
    fi
    if [[ ! -r $plist ]]; then
      echo "obsidian: health failed, Info.plist is not readable" >&2
      return 1
    fi
    version=$(sb_obsidian_plist_version "$plist")
    if [[ -z $version ]]; then
      echo "obsidian: health failed, Info.plist has no version" >&2
      return 1
    fi
    echo "obsidian: health ok bundle $version"
    return 0
  fi
  if [[ ! -f $app || ! -x $app ]]; then
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
  if [[ -z $size || "$size" -lt 1000000 ]]; then
    echo "obsidian: health failed, binary is unexpectedly small (${size:-0} bytes)" >&2
    return 1
  fi
  if [[ -n ${DISPLAY:-} || -n ${WAYLAND_DISPLAY:-} ]] && command -v timeout >/dev/null 2>&1; then
    if ! timeout 25 "$app" --version >/dev/null 2>&1; then
      echo "obsidian: health failed, launch returned an error" >&2
      return 1
    fi
    echo "obsidian: health ok launched $version"
    return 0
  fi
  if [[ -n ${DISPLAY:-} || -n ${WAYLAND_DISPLAY:-} ]]; then
    echo "obsidian: health ok version $version (launch skipped, timeout is not installed)"
    return 0
  fi
  echo "obsidian: health ok version $version (launch skipped, no display)"
}

sb_obsidian_force_fail() {
  local app=$1
  if [[ ! -e $app ]]; then
    echo "update: Obsidian app is missing, cannot simulate failure" >&2
    return 1
  fi
  rm -rf "$app.previous"
  mv "$app" "$app.previous"
  printf '%s\n' '#!/bin/sh' 'exit 1' > "$app"
  chmod +x "$app"
  if sb_obsidian_health "$app"; then
    sb_obsidian_restore_previous "$app" || true
    echo "update: force-fail did not fail the Obsidian health check" >&2
    return 1
  fi
  if ! sb_obsidian_restore_previous "$app"; then
    return 1
  fi
  if ! sb_obsidian_health "$app"; then
    echo "update: Obsidian health failed after rollback" >&2
    return 1
  fi
  echo "update: obsidian rollback ok"
}

sb_obsidian_remove_if_owned() {
  local owned
  if [[ ! -f $SB_STATE_DIR/obsidian-owned ]]; then
    echo "uninstall: left Obsidian in place; this installer did not record installing it"
    return 0
  fi
  owned=$(tr -d '[:space:]' < "$SB_STATE_DIR/obsidian-owned")
  if [[ -z $owned || ! -e $owned ]]; then
    echo "uninstall: owned Obsidian path is already gone"
    return 0
  fi
  rm -rf "$owned" "$owned.previous"
  echo "uninstall: removed $owned"
}

sb_obsidian_install_linux() {
  local dest current meta version url name tmp app
  export SB_OBSIDIAN_FRESH=0
  if [[ ${SECOND_BRAIN_OBSIDIAN_STUB:-} == 1 ]]; then
    sb_obsidian_write_stub
    sb_obsidian_remember "$(sb_obsidian_dir)/Obsidian.AppImage" installer
    return 0
  fi
  dest=$(sb_obsidian_dir)
  mkdir -p "$dest"
  app="$dest/Obsidian.AppImage"
  if existing=$(sb_obsidian_find_existing); then
    sb_obsidian_use_existing "$existing"
    return 0
  fi
  meta=$(sb_obsidian_release linux "$(uname -m)")
  version=$(printf '%s\n' "$meta" | sed -n '1p')
  url=$(printf '%s\n' "$meta" | sed -n '2p')
  name=$(printf '%s\n' "$meta" | sed -n '3p')
  current=""
  if [[ -f $dest/VERSION ]]; then
    current=$(tr -d '[:space:]' < "$dest/VERSION")
  fi
  if [[ -n $current && $current == "$version" && -x $app ]]; then
    sb_obsidian_remember "$app" installer
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
  if [[ -e $app ]]; then
    rm -rf "$app.previous"
    mv "$app" "$app.previous"
  fi
  mv "$tmp" "$app"
  printf '%s\n' "$version" > "$dest/VERSION"
  sb_obsidian_remember "$app" installer
  export SB_OBSIDIAN_FRESH=1
  if ! sb_obsidian_health "$app"; then
    sb_obsidian_restore_previous "$app" || true
    return 1
  fi
  echo "obsidian: installed $version"
}

sb_obsidian_install_macos() {
  local dest meta version url name tmp mount app plist current
  export SB_OBSIDIAN_FRESH=0
  dest="$HOME/Applications"
  mkdir -p "$dest"
  app="$dest/Obsidian.app"
  meta=$(sb_obsidian_release macos "$(uname -m)")
  version=$(printf '%s\n' "$meta" | sed -n '1p')
  url=$(printf '%s\n' "$meta" | sed -n '2p')
  name=$(printf '%s\n' "$meta" | sed -n '3p')
  if existing=$(sb_obsidian_find_existing); then
    sb_obsidian_use_existing "$existing"
    return 0
  fi
  current=$(sb_obsidian_installed_version || true)
  if [[ -n $current && $current == "$version" && -x $app/Contents/MacOS/Obsidian ]]; then
    sb_obsidian_remember "$app" installer
    echo "obsidian: already installed $version ($name)"
    return 0
  fi
  echo "obsidian: downloading $name"
  mkdir -p "$(sb_obsidian_dir)"
  tmp=$(mktemp "$(sb_obsidian_dir)/download.XXXXXX.dmg")
  if ! curl -fL --retry 3 -o "$tmp" "$url"; then
    rm -f "$tmp"
    echo "obsidian: download failed" >&2
    return 1
  fi
  mount=$(mktemp -d)
  if ! hdiutil attach -nobrowse -mountpoint "$mount" "$tmp"; then
    rm -f "$tmp"
    rm -rf "$mount"
    echo "obsidian: could not mount the disk image" >&2
    return 1
  fi
  local bundle staged
  bundle=$(find "$mount" -maxdepth 2 -name 'Obsidian.app' -type d | head -n 1)
  if [[ -z $bundle ]]; then
    hdiutil detach "$mount" >/dev/null || true
    rm -f "$tmp"
    rm -rf "$mount"
    echo "obsidian: disk image did not contain Obsidian.app" >&2
    return 1
  fi
  staged="$(sb_obsidian_dir)/Obsidian.app.staging"
  rm -rf "$staged"
  cp -R "$bundle" "$staged"
  hdiutil detach "$mount" >/dev/null || true
  rm -f "$tmp"
  rmdir "$mount" 2>/dev/null || true
  if ! sb_obsidian_health "$staged"; then
    rm -rf "$staged"
    echo "obsidian: staged app failed the health check; the previous app was left in place" >&2
    return 1
  fi
  if [[ -e $app ]]; then
    rm -rf "$app.previous"
    mv "$app" "$app.previous"
  fi
  if ! mv "$staged" "$app"; then
    sb_obsidian_restore_previous "$app" || true
    rm -rf "$staged"
    return 1
  fi
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
  sb_obsidian_remember "$app" installer
  export SB_OBSIDIAN_FRESH=1
  if ! sb_obsidian_health "$app"; then
    sb_obsidian_restore_previous "$app" || true
    return 1
  fi
  echo "obsidian: installed $version in $app"
}
