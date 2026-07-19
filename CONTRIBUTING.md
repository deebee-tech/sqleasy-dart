# Contributing to sqleasy-dart

This package is the Dart port of [`@deebeetech/sqleasy`](https://github.com/deebee-tech/sqleasy).
**TypeScript owns API design, emission, and the golden corpus.** Port behaviour here after each
corpus bump — do not invent dialect SQL in Dart first.

## Workflow

1. Land the change in the TypeScript repo (with corpus ops / `pnpm goldens` as needed).
2. Bump `corpusVersion` in `tool/fetch_goldens.dart`.
3. `dart run tool/fetch_goldens.dart` (or copy the sister repo’s `goldens/corpus.json`).
4. `dart run tool/embed_goldens.dart`
5. Extend `test/conformance/driver.dart` if new ops were added.
6. Port builders/parsers to match TypeScript.
7. `dart analyze --fatal-infos && dart format --set-exit-if-changed . && dart test && dart test -p chrome`

## Local checks (match CI)

```bash
dart pub get
dart analyze --fatal-infos
dart format --output=none --set-exit-if-changed .
dart run tool/fetch_goldens.dart --verify
dart run tool/verify_embed.dart
dart test
dart test -p chrome
dart run example/sqleasy_example.dart
```

Chrome tests need a Chrome/Chromium host. See `goldens/README.md` for the corpus contract.
