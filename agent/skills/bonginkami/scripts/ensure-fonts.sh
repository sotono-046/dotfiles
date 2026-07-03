#!/usr/bin/env bash
set -euo pipefail

# Portable across bash 3.2+ (macOS stock /bin/bash) and bash 4+ (Linux, Homebrew).
# Avoids `declare -A` so the script runs on a fresh macOS without `brew install bash`.

# The system bundles Noto Sans JP (OFL) directly in the repo, so this script
# normally just verifies the bundled woff2 files are present and intact. If
# they are missing or truncated, it rebuilds them from the Google Fonts
# variable font: instance the wght axis at 400 and 500, normalize the name
# table so every weight reports family "Noto Sans JP", and save as woff2.

FONT_DIR="$(cd "$(dirname "$0")/../assets/fonts" && pwd)"
MIN_SIZE=1000000  # 1MB floor, prevents truncated downloads

# Parallel arrays: weight name, OS/2 usWeightClass, bundled woff2 filename.
WEIGHT_NAMES=("Regular" "Medium")
WEIGHT_CLASSES=("400" "500")
LOCAL_NAMES=("NotoSansJP-Regular.woff2" "NotoSansJP-Medium.woff2")

# Upstream OFL source: google/fonts, ofl/notosansjp (variable font).
GF_VF_URL="https://raw.githubusercontent.com/google/fonts/main/ofl/notosansjp/NotoSansJP%5Bwght%5D.ttf"
GF_OFL_URL="https://raw.githubusercontent.com/google/fonts/main/ofl/notosansjp/OFL.txt"

check_size() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  local size
  size=$(wc -c < "$file" | tr -d ' ')
  [[ "$size" -ge "$MIN_SIZE" ]]
}

rebuild_fonts() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  # Pick a Python runner with fonttools + brotli (woff2).
  local runner=""
  if command -v uv >/dev/null 2>&1; then
    runner="uv run --with fonttools --with brotli python"
  elif python3 -c "import fontTools, brotli" >/dev/null 2>&1; then
    runner="python3"
  else
    echo "  ERROR: need 'uv' or python3 with fonttools+brotli to build woff2"
    echo "         install: pip install 'fonttools[woff]' brotli"
    return 1
  fi

  echo "  Downloading Noto Sans JP variable font (OFL) from google/fonts..."
  local vf="$tmpdir/NotoSansJP-VF.ttf"
  if ! curl --retry 2 --connect-timeout 15 --max-time 600 -fSL "$GF_VF_URL" -o "$vf"; then
    echo "  ERROR: download failed: $GF_VF_URL"
    return 1
  fi

  local i
  for i in "${!WEIGHT_NAMES[@]}"; do
    local w="${WEIGHT_NAMES[$i]}"
    local wclass="${WEIGHT_CLASSES[$i]}"
    local out="$FONT_DIR/${LOCAL_NAMES[$i]}"
    # Instance the wght axis, normalize the name table to family
    # "Noto Sans JP" (the upstream named instances would otherwise report
    # weight-specific family names and break CSS font-weight matching),
    # then save as woff2.
    $runner - "$vf" "$out" "$w" "$wclass" <<'PY'
import sys
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
src, dst, w, wclass = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
f = TTFont(src)
instantiateVariableFont(f, {"wght": wclass}, inplace=True)
name = f["name"]
FAMILY = "Noto Sans JP"
for platformID, platEncID, langID in [(3, 1, 0x409), (1, 0, 0)]:
    name.setName(FAMILY, 1, platformID, platEncID, langID)
    name.setName("Regular", 2, platformID, platEncID, langID)
    name.setName(FAMILY, 4, platformID, platEncID, langID)
    name.setName(f"NotoSansJP-{w}", 6, platformID, platEncID, langID)
    name.removeNames(nameID=16)
    name.removeNames(nameID=17)
if "OS/2" in f:
    f["OS/2"].usWeightClass = wclass
    fs = f["OS/2"].fsSelection
    fs &= ~0b100001  # clear ITALIC(0) and BOLD(5)
    fs |= 0x40       # set REGULAR(6)
    f["OS/2"].fsSelection = fs
if "head" in f:
    f["head"].macStyle = 0
f.flavor = "woff2"
f.save(dst)
PY
    echo "  OK: ${LOCAL_NAMES[$i]} rebuilt ($(du -h "$out" | cut -f1))"
  done

  # Refresh the license alongside the fonts.
  curl --retry 2 --connect-timeout 15 --max-time 60 -fSL "$GF_OFL_URL" \
    -o "$FONT_DIR/NotoSansJP-OFL.txt" 2>/dev/null || true
}

mkdir -p "$FONT_DIR"

all_present=true
for local_name in "${LOCAL_NAMES[@]}"; do
  if ! check_size "$FONT_DIR/$local_name"; then
    all_present=false
    break
  fi
done

if $all_present; then
  echo "OK: Noto Sans JP fonts present"
  exit 0
fi

echo "Noto Sans JP fonts missing or truncated; rebuilding..."
if ! rebuild_fonts; then
  echo ""
  echo "Could not rebuild fonts automatically. Alternatives:"
  echo "  1. Install Hiragino Sans / Yu Gothic (system gothic fonts) for local preview"
  echo "  2. Download the variable font from google/fonts ofl/notosansjp and"
  echo "     instance wght 400 / 500 to woff2 into $FONT_DIR"
  exit 1
fi

echo "OK: all fonts ready"
