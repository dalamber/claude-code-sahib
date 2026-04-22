#!/usr/bin/env bash
# claude-code-sahib setup — macOS / Linux
# Installs a character's sounds, spinnerVerbs, and Claude Code hooks.
#
# Usage:
#   bash setup.sh                                      # sahib/en (default)
#   bash setup.sh --character butler --language en
#   bash setup.sh -c gopnik -l ru
#   bash setup.sh --uninstall
set -euo pipefail

ACTION="install"
CHAR=""
LANG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uninstall)      ACTION="uninstall"; shift ;;
    --install)        ACTION="install";   shift ;;
    --character|-c)   CHAR="$2";          shift 2 ;;
    --language|-l)    LANG="$2";          shift 2 ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# *//'; exit 0 ;;
    *) echo "Unknown arg: $1"; echo "Run: $0 --help"; exit 1 ;;
  esac
done

REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE="$HOME/.claude"
SOUNDS="$CLAUDE/sounds/active"
SETTINGS="$CLAUDE/settings.json"
PLAY="$CLAUDE/sounds/play.sh"
TOGGLE="$CLAUDE/sounds/toggle.sh"

need_jq() {
  if ! command -v jq &>/dev/null; then
    echo "ERROR: jq required for JSON wiring."
    echo "  macOS:   brew install jq"
    echo "  Debian:  sudo apt install jq"
    echo "  Fedora:  sudo dnf install jq"
    exit 1
  fi
}

# ── Install ───────────────────────────────────────────────────────────────────
pick_character() {
  local chars=() i=1
  echo ""
  echo "What would you like to do?"
  for d in "$REPO"/characters/*/; do
    local id name langs warn marker
    id="$(basename "$d")"
    name="$(jq -r '.name | to_entries[0].value' "$d/character.json")"
    langs="$(jq -r '.languages | join(", ")' "$d/character.json")"
    warn="$(jq -r '.content_warning // empty' "$d/character.json")"
    marker=""; [[ -n "$warn" ]] && marker=" [!]"
    printf "  %d. Install %-12s %s [%s]%s\n" "$i" "$id" "$name" "$langs" "$marker"
    chars+=("$id"); i=$((i+1))
  done
  printf "  %d. Uninstall\n" "$i"
  local max=$i
  while :; do
    read -r -p "Select [1-$max]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= max )); then
      if (( choice == max )); then
        ACTION="uninstall"; return
      fi
      CHAR="${chars[$((choice-1))]}"; return
    fi
  done
}

pick_language() {
  local langs=() i=1
  while IFS= read -r l; do langs+=("$l"); done < <(jq -r '.languages[]' "$CHAR_JSON")
  if (( ${#langs[@]} == 1 )); then
    LANG="${langs[0]}"; return
  fi
  echo ""
  echo "Available languages for $CHAR:"
  for l in "${langs[@]}"; do
    printf "  %d. %s\n" "$i" "$l"; i=$((i+1))
  done
  while :; do
    read -r -p "Select language [1-${#langs[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#langs[@]} )); then
      LANG="${langs[$((choice-1))]}"; return
    fi
  done
}

do_install() {
  need_jq

  if [[ -z "$CHAR" ]]; then
    pick_character
    if [[ "$ACTION" == "uninstall" ]]; then
      do_uninstall
      return
    fi
  fi

  CHAR_JSON="$REPO/characters/$CHAR/character.json"
  if [[ ! -f "$CHAR_JSON" ]]; then
    echo "ERROR: unknown character '$CHAR'. Available:"
    ls -1 "$REPO/characters" | sed 's/^/  /'
    exit 1
  fi

  if [[ -z "$LANG" ]]; then
    pick_language
  fi
  LANG_DIR="$REPO/characters/$CHAR/$LANG"
  if [[ ! -d "$LANG_DIR" ]]; then
    echo "ERROR: language '$LANG' not available for '$CHAR'. Have:"
    jq -r '.languages[] | "  " + .' "$CHAR_JSON"
    exit 1
  fi

  WARN="$(jq -r '.content_warning // empty' "$CHAR_JSON")"
  if [[ -n "$WARN" ]]; then
    echo ""
    echo "CONTENT WARNING: $WARN"
    read -r -p "Proceed? [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
  fi

  echo "=== claude-code-sahib: install $CHAR ($LANG) ==="

  # --- Sounds ---------------------------------------------------------------
  echo ""
  echo "Copying sounds → $SOUNDS"
  rm -rf "$SOUNDS"
  mkdir -p "$SOUNDS"
  cp -r "$LANG_DIR/sounds/"* "$SOUNDS/" 2>/dev/null || true
  find "$SOUNDS" -name '.gitkeep' -delete 2>/dev/null || true
  count=$(find "$SOUNDS" -name '*.mp3' | wc -l | tr -d ' ')
  echo "  ✓ $count MP3 files"
  if [[ "$count" == "0" ]]; then
    echo "  ! No MP3s found for $CHAR/$LANG."
    echo "    Generate with: python scripts/generate_elevenlabs.py --character $CHAR --language $LANG"
  fi

  echo "Installing scripts → $CLAUDE/sounds/"
  cp "$REPO/scripts/play.sh"   "$PLAY"   && chmod +x "$PLAY"
  cp "$REPO/scripts/toggle.sh" "$TOGGLE" && chmod +x "$TOGGLE"
  echo "  ✓ play.sh, toggle.sh"

  # --- Settings: backup, spinnerVerbs, hooks -------------------------------
  echo "Wiring settings → $SETTINGS"
  mkdir -p "$CLAUDE"
  [[ ! -f "$SETTINGS" ]] && echo '{}' > "$SETTINGS"
  cp "$SETTINGS" "$SETTINGS.backup.$(date +%s)"

  VERBS_JSON="$LANG_DIR/spinner-verbs.json"
  if [[ -f "$VERBS_JSON" ]]; then
    jq --slurpfile v "$VERBS_JSON" '.spinnerVerbs = $v[0].spinnerVerbs' \
      "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    echo "  ✓ spinnerVerbs"
  fi

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
  if   [[ "$SHELL" == */zsh  ]]; then SHELL_RC="$HOME/.zshrc"
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
  echo "Installed $CHAR ($LANG). Restart Claude Code to apply."
  echo ""
  echo "  sahib / sahib on / sahib off   — toggle the voice"
  echo "  /sahib                         — same from inside Claude Code"
}

# ── Uninstall ─────────────────────────────────────────────────────────────────
do_uninstall() {
  echo "=== claude-code-sahib: uninstall ==="

  echo ""
  echo "Removing sounds and scripts..."
  rm -rf "$CLAUDE/sounds/active" "$CLAUDE/sounds/indian"
  rm -f  "$PLAY" "$TOGGLE"
  echo "  ✓ sounds and scripts removed"

  rm -f "$CLAUDE/commands/sahib.md"
  echo "  ✓ /sahib slash command removed"

  if [[ -f "$SETTINGS" ]] && command -v jq &>/dev/null; then
    echo "Removing hooks and spinnerVerbs from $SETTINGS..."
    jq '
      (.hooks |= (
        to_entries |
        map(.value |= map(select(
          (.hooks // [] | map(.command) | any(contains("play.sh"))) | not
        ))) |
        map(select(.value | length > 0)) |
        from_entries
      )) | del(.spinnerVerbs)
    ' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    echo "  ✓ hooks and spinnerVerbs removed"
  else
    echo "  ! Skipping settings cleanup (jq or settings.json missing)"
  fi

  for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [[ -f "$RC" ]] && grep -q 'toggle.sh' "$RC"; then
      sed -i.bak '/# claude-code-sahib toggle/d; /toggle\.sh/d' "$RC"
      rm -f "$RC.bak"
      echo "  ✓ sahib alias removed from $RC"
    fi
  done

  echo ""
  echo "Uninstalled. Restart Claude Code."
}

case "$ACTION" in
  install)   do_install   ;;
  uninstall) do_uninstall ;;
esac
