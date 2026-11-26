# Contributing

SillyTavern V2 uses a clean product contract. Before changing user-visible behavior, update the matching product, safety or architecture document in the same change.

## Rules

- Commit directly to `main`; do not create feature branches.
- Use repository-local `.tmp/` for every temporary file. Do not use system `/tmp`.
- Never commit API keys, signing keys, service tokens, private paths or user conversations.
- V1 data migration and compatibility are intentionally unsupported.
- Do not introduce external users, cloud accounts, telemetry, Lorebook or SillyTavern card support.
- Group chat is reserved for V2.2; the data model must remain participant-aware.

## Required checks

```bash
flutter analyze
flutter test
flutter build web --release --base-href "/SillyTavern/"
flutter build apk --release --split-per-abi
flutter build ios --release --no-codesign
```

## UI acceptance

- The three root tabs are messages, contacts and moments only.
- Secondary pages never show the root bottom navigation.
- No empty chat bubble may be rendered.
- Scrolling, keyboard inset handling and route transitions must be verified in release/profile builds.
- Light and dark themes must both be checked.
