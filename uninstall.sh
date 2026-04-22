#!/usr/bin/env bash
# claude-code-sahib uninstaller — macOS / Linux
set -euo pipefail

CLAUDE="$HOME/.claude"
SETTINGS="$CLAUDE/settings.json"

echo "=== claude-code-sahib uninstaller ==="

# ── Sounds & scripts ─────────────────────────────────────────────────────────
echo ""
echo "Removing sounds and scripts..."
rm -rf  "$CLAUDE/sounds/indian"
rm -f   "$CLAUDE/sounds/play.sh" "$CLAUDE/sounds/toggle.sh"
echo "  ✓ sounds and scripts removed"

# ── Slash command ─────────────────────────────────────────────────────────────
rm -f "$CLAUDE/commands/sahib.md"
echo "  ✓ /sahib slash command removed"

# ── Hooks ────────────────────────────────────────────────────────────────────
if [[ -f "$SETTINGS" ]] && command -v jq &>/dev/null; then
  echo "Removing hooks from $SETTINGS..."
  jq '
    .hooks |= with_entries(
      .value |= map(select(
        (.hooks // [] | map(.command) | any(contains("play.sh"))) | not
      )) | select(length > 0)
    )
  ' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  echo "  ✓ sahib hooks removed"
else
  echo "  ! Skipping hooks cleanup (jq not found or settings.json missing)"
  echo "    Remove entries containing 'play.sh' from $SETTINGS manually"
fi

# ── Shell alias ───────────────────────────────────────────────────────────────
for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [[ -f "$RC" ]] && grep -q 'toggle.sh' "$RC"; then
    # Remove the comment line and alias line
    sed -i.bak '/# claude-code-sahib toggle/d; /toggle\.sh/d' "$RC"
    rm -f "$RC.bak"
    echo "  ✓ sahib alias removed from $RC"
  fi
done

echo ""
echo "Uninstalled. Restart Claude Code to apply hook changes."
