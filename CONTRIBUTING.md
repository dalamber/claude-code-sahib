# Contributing

This repo is a collection of voice **characters** for Claude Code hooks. Each character lives under `characters/<id>/` and can ship in one or more languages. Two main things you can contribute: a **new language** for an existing character, or an entirely **new character**.

## Adding a new language to an existing character

1. Copy the folder of an existing language to start from a working shape:
   ```bash
   cp -r characters/butler/en characters/butler/<newlang>
   rm -rf characters/butler/<newlang>/sounds/*/*.mp3
   ```
2. Translate `phrases.json` and `spinner-verbs.json` **in the spirit of the character**, not word-for-word. Butler in English says "Shan't be a moment, sir" — the Russian version says "Сию минуту-с", not a literal translation. Match the tone.
3. Add the new language to `characters/<id>/character.json`:
   - `"languages": [..., "<newlang>"]`
   - add a `"voice_suggestions": { "<newlang>": { ... } }` entry with a `"PLACEHOLDER_<LANG>_<CHAR>"` voice id.
4. Also translate `name` and `description` in `character.json` so the installer can display them.
5. Generate audio with a real voice id (`scripts/generate_elevenlabs.py`) or Edge TTS (`scripts/generate_edge_tts.py`), commit the MP3s, and open a PR.

## Adding a new character

1. Create `characters/<id>/character.json` with at least one language in `languages` and matching `voice_suggestions`. Use `PLACEHOLDER_*` for voice ids.
2. For each language: write `phrases.json` (all six categories: `start`, `acknowledge`, `working`, `done`, `error`, `waiting`) and `spinner-verbs.json` in the Claude Code shape: `{"spinnerVerbs":{"mode":"replace","verbs":[...]}}`.
3. Minimum content bar: **15+ spinner verbs**, **3+ phrases per category** (≥ 20 total).
4. If the character contains adult language or strong tone, set `"content_warning"` in `character.json` — `scripts/install_character.py` will prompt the user before installing.
5. Generate MP3s into `characters/<id>/<lang>/sounds/<category>/<category>_NN.mp3` (the scripts do this automatically — phrase order in `phrases.json` defines the file index).
6. Open a PR with the new folder plus a short note about the archetype and the voice you used.

## Tone guidelines

- Characters are **archetypes**, not ethnic/racial/religious stereotypes. Sahib is a warm stylization of Indian-English corporate politeness. Butler is a Jeeves-style aristocrat. Gopnik is the Russian street-kid archetype. Govnokoder is a burnt-out developer. The character is the thing being affectionate — not the nationality.
- **Profanity is allowed** when authentic to the archetype (Gopnik, Govnokoder). A character with strong language must declare a `content_warning` in `character.json`.
- **No gendered or sexual content.**
- When in doubt, think "affectionate parody" — you're playing the archetype *with* it, not laughing *at* a group.

Open an issue first if you're unsure whether an idea fits. Feedback welcome.
