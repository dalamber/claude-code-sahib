#!/usr/bin/env python3
"""Generate per-character TTS via ElevenLabs.

Reads voice settings from characters/<id>/character.json and phrases from
characters/<id>/<lang>/phrases.json. Writes MP3s to
characters/<id>/<lang>/sounds/<category>/<category>_NN.mp3.

Example:
  export ELEVENLABS_API_KEY=sk_...
  python scripts/generate_elevenlabs.py --character butler --language en
  python scripts/generate_elevenlabs.py --character gopnik --language ru --category done --force
"""
import argparse
import os
import sys
from pathlib import Path

from _common import (
    load_character,
    load_phrases,
    resolve_categories,
    sound_dir,
)

EL_MODEL = "eleven_multilingual_v2"
EL_FORMAT = "mp3_44100_128"


def generate_one(api_key: str, voice_id: str, voice_settings: dict, text: str, out_path: Path) -> None:
    import requests
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
    resp = requests.post(
        url,
        headers={"xi-api-key": api_key, "Content-Type": "application/json"},
        json={
            "text": text,
            "model_id": EL_MODEL,
            "output_format": EL_FORMAT,
            "voice_settings": voice_settings,
        },
        timeout=30,
    )
    if resp.status_code != 200:
        raise RuntimeError(f"HTTP {resp.status_code}: {resp.text[:200]}")
    out_path.write_bytes(resp.content)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate character voice MP3s using ElevenLabs.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--character", required=True, help="character id (e.g. sahib, butler)")
    parser.add_argument("--language", required=True, help="language code (e.g. en, ru)")
    parser.add_argument("--category", help="only this category (start, acknowledge, working, done, error, waiting)")
    parser.add_argument("--force", action="store_true", help="regenerate existing files")
    args = parser.parse_args()

    api_key = os.environ.get("ELEVENLABS_API_KEY")
    if not api_key:
        sys.exit("ERROR: ELEVENLABS_API_KEY not set in environment")

    char = load_character(args.character)
    if args.language not in char.get("languages", []):
        sys.exit(f"ERROR: language '{args.language}' not declared in {args.character}/character.json "
                 f"(have: {', '.join(char.get('languages', []))})")

    voice_cfg = char.get("voice_suggestions", {}).get(args.language)
    if not voice_cfg:
        sys.exit(f"ERROR: no voice_suggestions[{args.language}] in character.json")

    voice_id = voice_cfg.get("voice_id", "")
    if not voice_id or voice_id.startswith("PLACEHOLDER"):
        sys.exit(f"ERROR: voice_id for {args.character}/{args.language} is a placeholder. "
                 f"Edit characters/{args.character}/character.json first.")

    voice_settings = {
        "stability": voice_cfg.get("stability", 0.5),
        "similarity_boost": voice_cfg.get("similarity_boost", 0.75),
        "style": voice_cfg.get("style", 0.4),
        "use_speaker_boost": voice_cfg.get("use_speaker_boost", True),
    }

    phrases = load_phrases(args.character, args.language)
    categories = resolve_categories(phrases, args.category)

    print(f"Character: {args.character} ({args.language})  |  Voice: {voice_id}")
    print(f"Categories: {', '.join(categories)}")

    generated = skipped = chars = 0
    for category in categories:
        print(f"\n[{category}]")
        out_dir = sound_dir(args.character, args.language, category)
        for i, text in enumerate(phrases[category]):
            out_path = out_dir / f"{category}_{i + 1:02d}.mp3"
            if out_path.exists() and not args.force:
                print(f"  skip {out_path.name} (exists)")
                skipped += 1
                continue
            print(f"  gen  {out_path.name} ({len(text)} chars) \"{text}\"")
            try:
                generate_one(api_key, voice_id, voice_settings, text, out_path)
                generated += 1
                chars += len(text)
            except Exception as e:
                print(f"  ERROR {out_path.name}: {e}")

    print(f"\n{'-' * 50}")
    print(f"Generated: {generated}  |  Skipped: {skipped}  |  Chars used: {chars}")


if __name__ == "__main__":
    main()
