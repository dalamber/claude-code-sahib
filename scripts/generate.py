#!/usr/bin/env python3
"""
Generate Indian-accent TTS phrases for Claude Code hooks.

Backends:
  edge        — Microsoft Edge TTS (free, en-IN-PrabhatNeural)
  elevenlabs  — ElevenLabs API (paid Starter+, requires ELEVENLABS_API_KEY
                and ELEVENLABS_VOICE_ID env vars or --voice-id flag)

Usage:
  python generate.py                              # edge, all categories
  python generate.py --backend elevenlabs         # ElevenLabs, all categories
  python generate.py --category done --force      # regenerate one category
  python generate.py --backend elevenlabs --voice-id <ID> --category acknowledge
"""
import asyncio
import argparse
import os
import sys
from pathlib import Path

SOUNDS_DIR = Path(__file__).parent.parent / "sounds"

# ── Edge TTS settings ────────────────────────────────────────────────────────
EDGE_VOICE = "en-IN-PrabhatNeural"
EDGE_RATE = "+30%"

# ── ElevenLabs settings ──────────────────────────────────────────────────────
EL_MODEL = "eleven_multilingual_v2"
EL_FORMAT = "mp3_44100_128"
EL_VOICE_SETTINGS = {
    "stability": 0.5,
    "similarity_boost": 0.75,
    "style": 0.4,
    "use_speaker_boost": True,
}

# ── Phrases ──────────────────────────────────────────────────────────────────
PHRASES = {
    "start": [
        "Good morning sir, ready to write some code",
        "Welcome back boss, let us begin",
        "Namaste sir, I am at your service",
    ],
    "acknowledge": [
        "Okay sir, one moment please",
        "Yes boss, let me see",
        "Right away sir",
        "Understood, most excellent request",
    ],
    "working": [
        "Working on it sir",
        "Doing the needful",
        "One second boss, processing",
        "Let me check this for you",
    ],
    "done": [
        "Done sir",
        "Task completed, very good",
        "Finished boss, most excellent",
        "Bahut accha, all done",
        "Everything is working, sir",
        "Please sir, kindly review",
        "I am done, what next boss",
        "Absolutely magnificent, finished",
    ],
    "error": [
        "Oh no sir, something went wrong",
        "Sorry boss, there is a problem",
        "Apologies sir, shall we try again",
        "Hai Ram, this is not working",
    ],
    "waiting": [
        "Sir, are you still there",
        "I am still waiting boss",
        "Hello sir, any update",
    ],
}


# ── Edge TTS backend ─────────────────────────────────────────────────────────
SEM = asyncio.Semaphore(3)


async def _edge_generate(text: str, out_path: Path) -> None:
    import edge_tts
    async with SEM:
        communicate = edge_tts.Communicate(text, EDGE_VOICE, rate=EDGE_RATE)
        await communicate.save(str(out_path))


async def generate_edge(category: str, index: int, text: str, force: bool) -> tuple[bool, int]:
    out_path = SOUNDS_DIR / category / f"{category}_{index:02d}.mp3"
    if out_path.exists() and not force:
        print(f"  skip {out_path.name} (exists)")
        return False, 0
    print(f"  gen  {out_path.name} ({len(text)} chars) \"{text}\"")
    for attempt in range(3):
        try:
            await _edge_generate(text, out_path)
            return True, len(text)
        except Exception as e:
            if attempt == 2:
                print(f"  ERROR {out_path.name}: {e}")
                return False, 0
            await asyncio.sleep(2 ** attempt)
    return False, 0


async def run_edge(categories: list[str], force: bool) -> tuple[int, int, int]:
    generated = skipped = chars = 0
    for category in categories:
        print(f"\n[{category}]")
        tasks = [
            generate_edge(category, i + 1, text, force)
            for i, text in enumerate(PHRASES[category])
        ]
        for did_gen, ch in await asyncio.gather(*tasks):
            if did_gen:
                generated += 1
                chars += ch
            else:
                skipped += 1
    return generated, skipped, chars


# ── ElevenLabs backend ───────────────────────────────────────────────────────
def _el_generate(api_key: str, voice_id: str, text: str, out_path: Path) -> None:
    import requests
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
    resp = requests.post(
        url,
        headers={"xi-api-key": api_key, "Content-Type": "application/json"},
        json={
            "text": text,
            "model_id": EL_MODEL,
            "output_format": EL_FORMAT,
            "voice_settings": EL_VOICE_SETTINGS,
        },
        timeout=30,
    )
    if resp.status_code != 200:
        raise RuntimeError(f"HTTP {resp.status_code}: {resp.text[:200]}")
    out_path.write_bytes(resp.content)


def run_elevenlabs(categories: list[str], force: bool, voice_id: str) -> tuple[int, int, int]:
    api_key = os.environ.get("ELEVENLABS_API_KEY")
    if not api_key:
        print("ERROR: ELEVENLABS_API_KEY not set in environment", file=sys.stderr)
        sys.exit(1)

    generated = skipped = chars = 0
    for category in categories:
        print(f"\n[{category}]")
        for i, text in enumerate(PHRASES[category]):
            out_path = SOUNDS_DIR / category / f"{category}_{i + 1:02d}.mp3"
            if out_path.exists() and not force:
                print(f"  skip {out_path.name} (exists)")
                skipped += 1
                continue
            print(f"  gen  {out_path.name} ({len(text)} chars) \"{text}\"")
            try:
                _el_generate(api_key, voice_id, text, out_path)
                generated += 1
                chars += len(text)
            except Exception as e:
                print(f"  ERROR {out_path.name}: {e}")

    return generated, skipped, chars


# ── Main ─────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="Generate Indian-accent TTS phrases for Claude Code hooks",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--backend", choices=["edge", "elevenlabs"], default="edge",
                        help="TTS backend (default: edge)")
    parser.add_argument("--voice-id", metavar="ID",
                        help="ElevenLabs voice ID (overrides ELEVENLABS_VOICE_ID env var)")
    parser.add_argument("--force", action="store_true",
                        help="Regenerate files even if they already exist")
    parser.add_argument("--category", metavar="NAME",
                        help=f"Generate only one category: {', '.join(PHRASES)}")
    args = parser.parse_args()

    if args.category:
        if args.category not in PHRASES:
            print(f"Unknown category '{args.category}'. Valid: {', '.join(PHRASES)}")
            sys.exit(1)
        categories = [args.category]
    else:
        categories = list(PHRASES.keys())

    for cat in categories:
        (SOUNDS_DIR / cat).mkdir(parents=True, exist_ok=True)

    print(f"Backend: {args.backend}  |  Categories: {', '.join(categories)}")

    if args.backend == "edge":
        generated, skipped, chars = asyncio.run(run_edge(categories, args.force))
    else:
        voice_id = args.voice_id or os.environ.get("ELEVENLABS_VOICE_ID", "")
        if not voice_id:
            print(
                "ERROR: ElevenLabs voice ID required.\n"
                "  Set ELEVENLABS_VOICE_ID env var or pass --voice-id <ID>",
                file=sys.stderr,
            )
            sys.exit(1)
        generated, skipped, chars = run_elevenlabs(categories, args.force, voice_id)

    print(f"\n{'─' * 50}")
    print(f"Generated: {generated}  |  Skipped: {skipped}  |  Chars used: {chars}")
    print(f"Output:    {SOUNDS_DIR}")


if __name__ == "__main__":
    main()
