#!/usr/bin/env bash
# Usage: toggle.sh [on|off]   (no args = toggle)
FLAG="$HOME/.claude/sounds/active/.disabled"

case "${1:-}" in
  on)  rm -f "$FLAG";   echo "sahib: ON  — Namaste sir, I am at your service" ;;
  off) touch "$FLAG";   echo "sahib: OFF — Going silent, boss" ;;
  *)
    if [[ -f "$FLAG" ]]; then
      rm -f "$FLAG";  echo "sahib: ON  — Namaste sir, I am at your service"
    else
      touch "$FLAG";  echo "sahib: OFF — Going silent, boss"
    fi
    ;;
esac
