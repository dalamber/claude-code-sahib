# claude-code-sahib

> Your Claude Code assistant, now with an Indian accent.

[![Demo — click to watch with sound](https://img.shields.io/badge/▶_Demo-YouTube-red?style=flat-square)](https://youtube.com)
<!-- Replace the URL above with your actual YouTube link once you have it. -->

---

**A note on tone.** This is an affectionate parody built with love for the Indian developer community, which has shaped so much of the software we all use every day. The phrases ("sahib", "bahut accha", "kindly review") are a warm stylisation, not a caricature. If anything here lands wrong for you, please open an issue — feedback genuinely welcome.

---

## What it does

Hooks into Claude Code's event system to play a random voice line whenever something happens: session starts, a tool runs, Claude finishes, or the session goes idle. The voice is Indian English — warm, slightly formal, occasionally delightful. Every "done sir" deserves to be heard.

## Installation

**macOS / Linux**

```bash
git clone https://github.com/antonshpak/claude-code-sahib
cd claude-code-sahib
bash setup.sh
```

Requires `jq` for hook wiring (`brew install jq` / `apt install jq`). Idempotent, safe to re-run.

**Windows (PowerShell)**

```powershell
git clone https://github.com/antonshpak/claude-code-sahib
cd claude-code-sahib
powershell -ExecutionPolicy Bypass -File setup.ps1
```

Uses `%APPDATA%\Claude\settings.json`. Plays audio via the system's default MP3 handler.

Restart Claude Code after installation.

**Uninstall**

```bash
bash setup.sh --uninstall
# or on Windows:
powershell -ExecutionPolicy Bypass -File setup.ps1 -Uninstall
```

### Toggling the voice

The installer adds a `sahib` command to your shell:

```bash
sahib        # toggle on/off
sahib off    # silence — going silent, boss
sahib on     # back in business
```

Works by dropping a `.disabled` flag file that `play.sh` checks before playing. No settings.json edits, no restart needed.

## Generating your own phrases

**Option A — Free (Microsoft Edge TTS)**

```bash
pip install edge-tts
python scripts/generate.py
```

Uses `en-IN-PrabhatNeural`. No account needed.

**Option B — Premium (ElevenLabs)**

Requires a Starter+ subscription. The included MP3s were generated with [Aditya Rao — Motivated, Clear and Smooth](https://elevenlabs.io/app/voice-library?voiceId=HAbWfLBk6HVxg0scLcvE).

```bash
pip install requests
export ELEVENLABS_API_KEY=your_key_here
export ELEVENLABS_VOICE_ID=HAbWfLBk6HVxg0scLcvE  # or any voice ID from the library

python scripts/generate.py --backend elevenlabs
```

**Option C — Just use the MP3s**

Clone and skip generation. The `sounds/` directory has all 26 phrases ready to go.

## Phrase catalog

| Category | # | Phrase |
|----------|---|--------|
| `start` | 1 | Good morning sir, ready to write some code |
| `start` | 2 | Welcome back boss, let us begin |
| `start` | 3 | Namaste sir, I am at your service |
| `acknowledge` | 1 | Okay sir, one moment please |
| `acknowledge` | 2 | Yes boss, let me see |
| `acknowledge` | 3 | Right away sir |
| `acknowledge` | 4 | Understood, most excellent request |
| `working` | 1 | Working on it sir |
| `working` | 2 | Doing the needful |
| `working` | 3 | One second boss, processing |
| `working` | 4 | Let me check this for you |
| `done` | 1 | Done sir |
| `done` | 2 | Task completed, very good |
| `done` | 3 | Finished boss, most excellent |
| `done` | 4 | Bahut accha, all done |
| `done` | 5 | Everything is working, sir |
| `done` | 6 | Please sir, kindly review |
| `done` | 7 | I am done, what next boss |
| `done` | 8 | Absolutely magnificent, finished |
| `error` | 1 | Oh no sir, something went wrong |
| `error` | 2 | Sorry boss, there is a problem |
| `error` | 3 | Apologies sir, shall we try again |
| `error` | 4 | Hai Ram, this is not working |
| `waiting` | 1 | Sir, are you still there |
| `waiting` | 2 | I am still waiting boss |
| `waiting` | 3 | Hello sir, any update |

## Tuning the voice

Add or change phrases in the `PHRASES` dict in `scripts/generate.py`, then regenerate:

```bash
python scripts/generate.py --category done --force
```

For ElevenLabs, tune the feel in `EL_VOICE_SETTINGS` at the top of the script:

```python
EL_VOICE_SETTINGS = {
    "stability": 0.5,         # 0–1: lower = more expressive
    "similarity_boost": 0.75, # 0–1: voice fidelity
    "style": 0.4,             # 0–1: higher = more stylised
    "use_speaker_boost": True,
}
```

## Voice credits

| Backend | Voice |
|---------|-------|
| Microsoft Edge TTS | [`en-IN-PrabhatNeural`](https://azure.microsoft.com/en-us/products/ai-services/text-to-speech) |
| ElevenLabs | [Aditya Rao — Motivated, Clear and Smooth](https://elevenlabs.io/app/voice-library?voiceId=HAbWfLBk6HVxg0scLcvE) |

## Contributing

PRs welcome, especially new phrases and new categories. Please keep the same warm-and-silly tone — think affectionate parody, not mockery. New voices are welcome too.

## License

MIT — see [LICENSE](LICENSE).
