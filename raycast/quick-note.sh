#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Quick Note
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📝
# @raycast.packageName Mitumine
# @raycast.description Mitumineに自動保存するクイックメモ

set -euo pipefail

NOTE_DIR="$HOME/Library/CloudStorage/Dropbox/Mitumine/inbox"
TEMPLATE="$HOME/Library/CloudStorage/Dropbox/Mitumine/_temp/unique.md"
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
TODAY=$(date +"%Y-%m-%d")
FILE="$NOTE_DIR/$TIMESTAMP.md"
PLACEHOLDER='<% tp.date.now("YYYY-MM-DD") %>'

canon_path() {
  local dir base
  dir=$(dirname -- "$1")
  base=$(basename -- "$1")
  if [ ! -d "$dir" ]; then
    printf '%s\n' "$1"
    return
  fi
  printf '%s/%s\n' "$(cd -- "$dir" && pwd -P)" "$base"
}

typora_open_paths() {
  osascript -l JavaScript <<'EOF'
const Typora = Application("Typora");
const lines = [];
for (const doc of Typora.documents()) {
  let filePath;
  try {
    filePath = doc.path();
  } catch (e) {
    continue;
  }
  if (filePath) lines.push(filePath);
}
lines.join("\n");
EOF
}

path_is_listed() {
  local target="$1"
  local paths="$2"
  local p target_canon
  target_canon=$(canon_path "$target")
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if [ "$(canon_path "$p")" = "$target_canon" ]; then
      return 0
    fi
  done <<< "$paths"
  return 1
}

# frontmatter は本文に数えない。本文が空、または空白だけなら終了コード 0。
body_is_empty() {
  awk '
    BEGIN { found = 0; in_frontmatter = 0; closed = 0 }
    { sub(/\r$/, "") }
    NR == 1 && $0 == "---" { in_frontmatter = 1; next }
    in_frontmatter && $0 == "---" { in_frontmatter = 0; closed = 1; next }
    in_frontmatter { next }
    $0 ~ /[^[:space:]]/ { found = 1; exit }
    END {
      if (in_frontmatter && !closed) exit 1
      exit found ? 1 : 0
    }
  ' "$1"
}

if [ ! -d "$NOTE_DIR" ]; then
  echo "inbox が見つかりません" >&2
  exit 1
fi

if [ ! -f "$TEMPLATE" ]; then
  echo "テンプレートが見つかりません" >&2
  exit 1
fi

# Typora は Templater を展開しないので、日付だけここで埋める。
template_body=$(<"$TEMPLATE")
printf '%s\n' "${template_body//$PLACEHOLDER/$TODAY}" > "$FILE"

if ! open -a Typora "$FILE"; then
  echo "Typoraで開けませんでした" >&2
  exit 1
fi

# 新しいノートが一覧に出るまで待つ。見えないうちに掃除すると、今開いた空ノートまで消す。
open_paths=""
ready=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25; do
  if open_paths=$(typora_open_paths 2>/dev/null) && path_is_listed "$FILE" "$open_paths"; then
    ready=1
    break
  fi
  sleep 0.2
done

if [ "$ready" -ne 1 ]; then
  echo "Typoraで開いているノートを確認できなかったので掃除をスキップしました" >&2
  exit 0
fi

# 今開いているノート以外で、本文が空のものを捨てる。
shopt -s nullglob
for note in "$NOTE_DIR"/*.md; do
  if path_is_listed "$note" "$open_paths"; then
    continue
  fi
  if body_is_empty "$note"; then
    rm -f -- "$note"
  fi
done
