#!/usr/bin/env bash
# Play a random MP3 from the given category. Exits immediately (afplay runs in background).
CATEGORY="${1:?Usage: play.sh <category>}"
DIR="$HOME/.claude/sounds/indian/$CATEGORY"
mapfile -t files < <(find "$DIR" -name '*.mp3' 2>/dev/null)
count=${#files[@]}
(( count == 0 )) && exit 0
file="${files[$((RANDOM % count))]}"
afplay "$file" &
