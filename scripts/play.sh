#!/usr/bin/env bash
CATEGORY="${1:?Usage: play.sh <category>}"
FLAG="$HOME/.claude/sounds/indian/.disabled"
[[ -f "$FLAG" ]] && exit 0
DIR="$HOME/.claude/sounds/indian/$CATEGORY"
mapfile -t files < <(find "$DIR" -name '*.mp3' 2>/dev/null)
count=${#files[@]}
(( count == 0 )) && exit 0
file="${files[$((RANDOM % count))]}"
afplay "$file" &
