#!/usr/bin/env bash
CATEGORY="${1:?Usage: play.sh <category>}"
FLAG="$HOME/.claude/sounds/active/.disabled"
[[ -f "$FLAG" ]] && exit 0
DIR="$HOME/.claude/sounds/active/$CATEGORY"
files=()
while IFS= read -r f; do files+=("$f"); done < <(find "$DIR" -name '*.mp3' 2>/dev/null)
count=${#files[@]}
(( count == 0 )) && exit 0
file="${files[$((RANDOM % count))]}"
afplay "$file" &
