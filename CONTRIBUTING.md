# Contributing

SillyTavern APP uses a mobile-first product contract. Before changing user-visible behavior, update the matching product, safety or architecture document in the same change.

## Rules

- Commit directly to `main`; do not create feature branches.
- Use repository-local `.tmp/` for every temporary file. Do not use system `/tmp`.
- Never commit API keys, signing keys, service tokens, private paths or user conversations.
- V1 data migration and compatibility are intentionally unsupported.
- Do not introduce external users, cloud accounts, telemetry or cloud content storage.
- Character Card V2, World Info / Lorebook, Chat Completion Presets, Prompt Manager and participant-aware group chat are supported. Unknown imported fields must remain inert data.
- Never execute arbitrary JavaScript from SillyTavern extensions, presets or character cards.
- Keep API keys out of source, logs, ordinary backups and release artifacts.

## Required checks

```bash
flutter analyze
flutter test
flutter build web --release --base-href "/SillyTavern/"
flutter build apk --release --split-per-abi
flutter build ios --release --no-codesign
```

## UI acceptance

- The two full-screen root surfaces are conversations (`/`) and the character library (`/characters`).
- There is no permanent root bottom navigation. Secondary pages must remain full-screen.
- No empty chat bubble may be rendered.
- Scrolling, keyboard inset handling and route transitions must be verified in release/profile builds.
- Light and dark themes must both be checked.
- A fresh installation must not contain demo characters, messages, greetings, prompts or fake provider models.
