#!/usr/bin/env bash
# claude-code-sahib setup — macOS / Linux
# Usage: bash setup.sh [--install|--uninstall]   (default: --install)
set -euo pipefail

ACTION="install"
for arg in "$@"; do
  case "$arg" in
    --uninstall) ACTION="uninstall" ;;
    --install)   ACTION="install"   ;;
    *) echo "Usage: $0 [--install|--uninstall]"; exit 1 ;;
  esac
done

REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE="$HOME/.claude"
SOUNDS="$CLAUDE/sounds/indian"
SETTINGS="$CLAUDE/settings.json"
PLAY="$CLAUDE/sounds/play.sh"
TOGGLE="$CLAUDE/sounds/toggle.sh"

# ── Install ───────────────────────────────────────────────────────────────────
do_install() {
  echo "=== claude-code-sahib: install ==="

  echo ""
  echo "Copying sounds → $SOUNDS"
  mkdir -p "$SOUNDS"
  cp -r "$REPO/sounds/"* "$SOUNDS/"
  count=$(find "$SOUNDS" -name '*.mp3' | wc -l | tr -d ' ')
  echo "  ✓ $count MP3 files"

  echo "Installing scripts → $CLAUDE/sounds/"
  cp "$REPO/scripts/play.sh"   "$PLAY"   && chmod +x "$PLAY"
  cp "$REPO/scripts/toggle.sh" "$TOGGLE" && chmod +x "$TOGGLE"
  echo "  ✓ play.sh, toggle.sh"

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

  SHELL_RC=""
  if [[ "$SHELL" == */zsh ]];   then SHELL_RC="$HOME/.zshrc"
  elif [[ "$SHELL" == */bash ]]; then SHELL_RC="$HOME/.bashrc"
  fi
  if [[ -n "$SHELL_RC" ]]; then
    if grep -q 'toggle.sh' "$SHELL_RC" 2>/dev/null; then
      echo "  ~ sahib alias already in $SHELL_RC, skipping"
    else
      printf '\n# claude-code-sahib toggle\nalias sahib="bash ~/.claude/sounds/toggle.sh"\n' >> "$SHELL_RC"
      echo "  + sahib alias → $SHELL_RC"
    fi
  fi

  mkdir -p "$CLAUDE/commands"
  cp "$REPO/commands/sahib.md" "$CLAUDE/commands/sahib.md"
  echo "  + /sahib slash command"

  echo ""
  echo "All done, sir. Restart Claude Code to hear Aditya."
  echo ""
  echo "  sahib / sahib on / sahib off   — toggle the voice"
  echo "  /sahib                         — same from inside Claude Code"
}

# ── Uninstall ─────────────────────────────────────────────────────────────────
do_uninstall() {
  echo "=== claude-code-sahib: uninstall ==="

  echo ""
  echo "Removing sounds and scripts..."
  rm -rf "$CLAUDE/sounds/indian"
  rm -f  "$PLAY" "$TOGGLE"
  echo "  ✓ sounds and scripts removed"

  rm -f "$CLAUDE/commands/sahib.md"
  echo "  ✓ /sahib slash command removed"

  if [[ -f "$SETTINGS" ]] && command -v jq &>/dev/null; then
    echo "Removing hooks from $SETTINGS..."
    jq '
      .hooks |= (
        to_entries |
        map(.value |= map(select(
          (.hooks // [] | map(.command) | any(contains("play.sh"))) | not
        ))) |
        map(select(.value | length > 0)) |
        from_entries
      )
    ' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    echo "  ✓ sahib hooks removed"
  else
    echo "  ! Skipping hooks cleanup (jq not found or settings.json missing)"
    echo "    Remove entries containing 'play.sh' from $SETTINGS manually"
  fi

  for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [[ -f "$RC" ]] && grep -q 'toggle.sh' "$RC"; then
      sed -i.bak '/# claude-code-sahib toggle/d; /toggle\.sh/d' "$RC"
      rm -f "$RC.bak"
      echo "  ✓ sahib alias removed from $RC"
    fi
  done

  echo ""
  echo "Uninstalled. Restart Claude Code to apply hook changes."
}

case "$ACTION" in
  install)   do_install   ;;
  uninstall) do_uninstall ;;
esac
