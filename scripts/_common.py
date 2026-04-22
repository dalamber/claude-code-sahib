"""Shared helpers for character-aware TTS generation scripts."""
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CHARACTERS_DIR = REPO_ROOT / "characters"
CATEGORIES = ["start", "acknowledge", "working", "done", "error", "waiting"]


def load_character(character_id: str) -> dict:
    path = CHARACTERS_DIR / character_id / "character.json"
    if not path.exists():
        sys.exit(f"ERROR: character '{character_id}' not found at {path}")
    return json.loads(path.read_text())


def load_phrases(character_id: str, language: str) -> dict:
    path = CHARACTERS_DIR / character_id / language / "phrases.json"
    if not path.exists():
        sys.exit(f"ERROR: phrases.json not found for {character_id}/{language} at {path}")
    return json.loads(path.read_text())


def sound_dir(character_id: str, language: str, category: str) -> Path:
    d = CHARACTERS_DIR / character_id / language / "sounds" / category
    d.mkdir(parents=True, exist_ok=True)
    return d


def resolve_categories(phrases: dict, category_arg: str | None) -> list[str]:
    if category_arg:
        if category_arg not in phrases:
            sys.exit(f"ERROR: category '{category_arg}' not in phrases.json "
                     f"(have: {', '.join(phrases)})")
        return [category_arg]
    return [c for c in CATEGORIES if c in phrases]
