#!/usr/bin/env bash
# claude-code-sahib installer — macOS / Linux
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE="$HOME/.claude"
SOUNDS="$CLAUDE/sounds/indian"
SETTINGS="$CLAUDE/settings.json"
PLAY="$CLAUDE/sounds/play.sh"

echo "=== claude-code-sahib installer ==="

# ── Sounds ───────────────────────────────────────────────────────────────────
echo ""
echo "Copying sounds → $SOUNDS"
mkdir -p "$SOUNDS"
cp -r "$REPO/sounds/"* "$SOUNDS/"
count=$(find "$SOUNDS" -name '*.mp3' | wc -l | tr -d ' ')
echo "  ✓ $count MP3 files"

# ── play.sh ──────────────────────────────────────────────────────────────────
echo "Installing play.sh → $PLAY"
cp "$REPO/scripts/play.sh" "$PLAY"
chmod +x "$PLAY"
echo "  ✓ done"

# ── Hooks ────────────────────────────────────────────────────────────────────
echo "Wiring Claude Code hooks → $SETTINGS"

if ! command -v jq &>/dev/null; then
  echo ""
  echo "  jq not found — cannot auto-wire hooks."
  echo "  Install jq and re-run, or add hooks manually (see README)."
  echo "    macOS:   brew install jq"
  echo "    Debian:  sudo apt install jq"
  echo "    Fedora:  sudo dnf install jq"
  exit 1
fi

mkdir -p "$CLAUDE"
[[ ! -f "$SETTINGS" ]] && echo '{}' > "$SETTINGS"

# Ensure .hooks key exists
jq 'if .hooks == null then . + {"hooks": {}} else . end' \
  "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"

add_hook() {
  local event="$1" cmd="$2"
  if jq -e --arg e "$event" \
    '.hooks[$e] // [] | .[].hooks // [] | .[].command | contains("play.sh")' \
    "$SETTINGS" &>/dev/null; then
    echo "  ~ $event already wired, skipping"
    return
  fi
  local entry
  entry=$(jq -n --arg cmd "$cmd" '{"hooks":[{"type":"command","command":$cmd}]}')
  jq --arg e "$event" --argjson entry "$entry" \
    '.hooks[$e] = ((.hooks[$e] // []) + [$entry])' \
    "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  echo "  + $event"
}

add_hook "SessionStart"     "bash ~/.claude/sounds/play.sh start"
add_hook "UserPromptSubmit" "bash ~/.claude/sounds/play.sh acknowledge"
add_hook "PreToolUse"       '[ $((RANDOM % 3)) -eq 0 ] && bash ~/.claude/sounds/play.sh working; true'
add_hook "Stop"             "bash ~/.claude/sounds/play.sh done & cat > /dev/null"
add_hook "Notification"     "bash ~/.claude/sounds/play.sh waiting & cat > /dev/null"

echo ""
echo "All done, sir. Restart Claude Code to hear Aditya."
