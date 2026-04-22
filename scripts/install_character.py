#!/usr/bin/env python3
"""Install a character into ~/.claude/.

Copies the character's MP3s into ~/.claude/sounds/active/ and merges its
spinnerVerbs into ~/.claude/settings.json (with a timestamped backup). Hook
wiring is NOT done here yet — use setup.sh / setup.ps1 for Sahib hooks until
the unified installer lands in the next milestone.

Example:
  python scripts/install_character.py --character sahib --language en
  python scripts/install_character.py --character gopnik --language ru
  python scripts/install_character.py                         # interactive
"""
import argparse
import json
import shutil
import sys
import time
from pathlib import Path

from _common import CHARACTERS_DIR

CLAUDE_DIR = Path.home() / ".claude"
SETTINGS = CLAUDE_DIR / "settings.json"
ACTIVE_SOUNDS = CLAUDE_DIR / "sounds" / "active"


def list_characters() -> list[dict]:
    out = []
    for d in sorted(CHARACTERS_DIR.glob("*/character.json")):
        out.append(json.loads(d.read_text()))
    return out


def prompt_choice(label: str, options: list[str]) -> str:
    print(f"\nAvailable {label}:")
    for i, o in enumerate(options, 1):
        print(f"  {i}. {o}")
    while True:
        raw = input(f"Select {label} [1-{len(options)}]: ").strip()
        if raw.isdigit() and 1 <= int(raw) <= len(options):
            return options[int(raw) - 1]
        if raw in options:
            return raw


def confirm(prompt: str) -> bool:
    return input(f"{prompt} [y/N]: ").strip().lower() in ("y", "yes")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Install a character's sounds and spinnerVerbs into ~/.claude/.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--character", help="character id (e.g. sahib, butler)")
    parser.add_argument("--language", help="language code (e.g. en, ru)")
    args = parser.parse_args()

    characters = list_characters()
    if not characters:
        sys.exit(f"ERROR: no characters found in {CHARACTERS_DIR}")

    char_ids = [c["id"] for c in characters]
    char_id = args.character or prompt_choice("character", char_ids)
    char = next((c for c in characters if c["id"] == char_id), None)
    if not char:
        sys.exit(f"ERROR: unknown character '{char_id}'. Available: {', '.join(char_ids)}")

    langs = char.get("languages", [])
    language = args.language or (langs[0] if len(langs) == 1 else prompt_choice("language", langs))
    if language not in langs:
        sys.exit(f"ERROR: language '{language}' not available for {char_id}. Have: {', '.join(langs)}")

    warning = char.get("content_warning")
    if warning:
        print(f"\nCONTENT WARNING: {warning}")
        if not confirm("Proceed with installation?"):
            sys.exit("Aborted.")

    src_sounds = CHARACTERS_DIR / char_id / language / "sounds"
    src_verbs = CHARACTERS_DIR / char_id / language / "spinner-verbs.json"

    if not src_verbs.exists():
        sys.exit(f"ERROR: missing {src_verbs}")

    mp3s = list(src_sounds.rglob("*.mp3"))
    if not mp3s:
        print(f"WARNING: no MP3s found under {src_sounds}. "
              f"Run scripts/generate_edge_tts.py or generate_elevenlabs.py first.")

    CLAUDE_DIR.mkdir(parents=True, exist_ok=True)

    if SETTINGS.exists():
        backup = SETTINGS.with_suffix(f".json.backup.{int(time.time())}")
        shutil.copy2(SETTINGS, backup)
        print(f"Backed up existing settings to {backup}")
        settings = json.loads(SETTINGS.read_text())
    else:
        settings = {}

    verbs_payload = json.loads(src_verbs.read_text())
    settings["spinnerVerbs"] = verbs_payload["spinnerVerbs"]

    # TODO: wire hooks here in the next milestone — will inject category
    # triggers into settings["hooks"] based on the active character's
    # categories and play.sh / play.ps1.

    SETTINGS.write_text(json.dumps(settings, indent=2, ensure_ascii=False) + "\n")
    print(f"Updated {SETTINGS}")

    if ACTIVE_SOUNDS.exists():
        shutil.rmtree(ACTIVE_SOUNDS)
    ACTIVE_SOUNDS.mkdir(parents=True, exist_ok=True)
    copied = 0
    for mp3 in mp3s:
        rel = mp3.relative_to(src_sounds)
        dst = ACTIVE_SOUNDS / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(mp3, dst)
        copied += 1

    print(f"\nInstalled {char_id} ({language}):")
    print(f"  spinnerVerbs → {SETTINGS}")
    print(f"  {copied} MP3(s) → {ACTIVE_SOUNDS}/")
    print("\nNote: hook wiring is coming in the next release. For now, "
          "use `bash setup.sh` (Sahib-only) to wire Claude Code hooks.")


if __name__ == "__main__":
    main()
