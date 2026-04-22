#!/usr/bin/env bash
# claude-code-sahib installer — macOS / Linux
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE="$HOME/.claude"
SOUNDS="$CLAUDE/sounds/indian"
SETTINGS="$CLAUDE/settings.json"
PLAY="$CLAUDE/sounds/play.sh"
TOGGLE="$CLAUDE/sounds/toggle.sh"

echo "=== claude-code-sahib installer ==="

# ── Sounds ───────────────────────────────────────────────────────────────────
echo ""
echo "Copying sounds → $SOUNDS"
mkdir -p "$SOUNDS"
cp -r "$REPO/sounds/"* "$SOUNDS/"
count=$(find "$SOUNDS" -name '*.mp3' | wc -l | tr -d ' ')
echo "  ✓ $count MP3 files"

# ── play.sh / toggle.sh ──────────────────────────────────────────────────────
echo "Installing scripts → $CLAUDE/sounds/"
cp "$REPO/scripts/play.sh"   "$PLAY"   && chmod +x "$PLAY"
cp "$REPO/scripts/toggle.sh" "$TOGGLE" && chmod +x "$TOGGLE"
echo "  ✓ play.sh, toggle.sh"

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

# ── Shell alias ───────────────────────────────────────────────────────────────
ALIAS_LINE='alias sahib="bash ~/.claude/sounds/toggle.sh"'
SHELL_RC=""
if [[ "$SHELL" == */zsh ]];  then SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == */bash ]]; then SHELL_RC="$HOME/.bashrc"
fi

if [[ -n "$SHELL_RC" ]]; then
  if grep -q 'toggle.sh' "$SHELL_RC" 2>/dev/null; then
    echo "  ~ sahib alias already in $SHELL_RC, skipping"
  else
    echo "" >> "$SHELL_RC"
    echo "# claude-code-sahib toggle" >> "$SHELL_RC"
    echo "$ALIAS_LINE" >> "$SHELL_RC"
    echo "  + sahib alias → $SHELL_RC (run 'source $SHELL_RC' or open a new terminal)"
  fi
fi

# ── /sahib slash command ──────────────────────────────────────────────────────
COMMANDS_DIR="$CLAUDE/commands"
mkdir -p "$COMMANDS_DIR"
cp "$REPO/commands/sahib.md" "$COMMANDS_DIR/sahib.md"
echo "  + /sahib slash command → $COMMANDS_DIR/sahib.md"

echo ""
echo "All done, sir. Restart Claude Code to hear Aditya."
echo ""
echo "Toggle the voice anytime:"
echo "  sahib        # shell alias: toggle on/off"
echo "  sahib off    # silence"
echo "  sahib on     # back in business"
echo "  /sahib       # same, as a Claude Code slash command"
