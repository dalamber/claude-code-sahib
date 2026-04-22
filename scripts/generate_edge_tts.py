#!/usr/bin/env python3
"""Generate per-character TTS via Microsoft Edge TTS (free, no account).

Reads phrases from characters/<id>/<lang>/phrases.json and writes MP3s to
characters/<id>/<lang>/sounds/<category>/<category>_NN.mp3. Voice is picked
from EDGE_VOICES per language; override with --voice.

Example:
  pip install edge-tts
  python scripts/generate_edge_tts.py --character sahib --language en
  python scripts/generate_edge_tts.py --character butler --language ru --voice ru-RU-SvetlanaNeural
"""
import argparse
import asyncio
import sys
from pathlib import Path

from _common import load_phrases, resolve_categories, sound_dir

EDGE_VOICES = {
    "en": "en-IN-PrabhatNeural",
    "ru": "ru-RU-DmitryNeural",
}
EDGE_RATE = "+30%"
SEM = asyncio.Semaphore(3)


async def _gen(text: str, voice: str, out_path: Path) -> None:
    import edge_tts
    async with SEM:
        await edge_tts.Communicate(text, voice, rate=EDGE_RATE).save(str(out_path))


async def generate_one(voice: str, category: str, index: int, text: str, out_path: Path, force: bool) -> tuple[bool, int]:
    if out_path.exists() and not force:
        print(f"  skip {out_path.name} (exists)")
        return False, 0
    print(f"  gen  {out_path.name} ({len(text)} chars) \"{text}\"")
    for attempt in range(3):
        try:
            await _gen(text, voice, out_path)
            return True, len(text)
        except Exception as e:
            if attempt == 2:
                print(f"  ERROR {out_path.name}: {e}")
                return False, 0
            await asyncio.sleep(2 ** attempt)
    return False, 0


async def run(voice: str, character: str, language: str, phrases: dict, categories: list[str], force: bool) -> tuple[int, int, int]:
    generated = skipped = chars = 0
    for category in categories:
        print(f"\n[{category}]")
        out_dir = sound_dir(character, language, category)
        tasks = [
            generate_one(voice, category, i + 1, text, out_dir / f"{category}_{i + 1:02d}.mp3", force)
            for i, text in enumerate(phrases[category])
        ]
        for did_gen, c in await asyncio.gather(*tasks):
            if did_gen:
                generated += 1
                chars += c
            else:
                skipped += 1
    return generated, skipped, chars


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate character voice MP3s using Microsoft Edge TTS.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--character", required=True, help="character id (e.g. sahib, butler)")
    parser.add_argument("--language", required=True, help="language code (e.g. en, ru)")
    parser.add_argument("--category", help="only this category")
    parser.add_argument("--voice", help="override Edge TTS voice (see `edge-tts --list-voices`)")
    parser.add_argument("--force", action="store_true", help="regenerate existing files")
    args = parser.parse_args()

    voice = args.voice or EDGE_VOICES.get(args.language)
    if not voice:
        sys.exit(f"ERROR: no default Edge voice for language '{args.language}'. Pass --voice.")

    phrases = load_phrases(args.character, args.language)
    categories = resolve_categories(phrases, args.category)

    print(f"Character: {args.character} ({args.language})  |  Voice: {voice}")
    print(f"Categories: {', '.join(categories)}")

    generated, skipped, chars = asyncio.run(
        run(voice, args.character, args.language, phrases, categories, args.force)
    )

    print(f"\n{'-' * 50}")
    print(f"Generated: {generated}  |  Skipped: {skipped}  |  Chars used: {chars}")


if __name__ == "__main__":
    main()
