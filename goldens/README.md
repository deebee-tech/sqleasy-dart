# The golden corpus

`corpus.json` is the **cross-language contract** for SQLEasy. This Dart package and the TypeScript
package in [`deebee-tech/sqleasy`](https://github.com/deebee-tech/sqleasy) must reproduce its output
byte-for-byte, for every dialect.

The authoritative documentation lives in the TypeScript repo:

[`goldens/README.md` in deebee-tech/sqleasy](https://github.com/deebee-tech/sqleasy/blob/main/goldens/README.md)

## How this repo consumes it

1. Pin a corpus version in [`tool/fetch_goldens.dart`](../tool/fetch_goldens.dart) (`corpusVersion`).
2. Fetch (or vendor) `goldens/corpus.json` from the matching TypeScript git tag.
3. Embed it for dart2js with `dart run tool/embed_goldens.dart`.
4. CI verifies the vendored file matches the tag (when published) and that the embed matches the
   vendored file, then replays conformance on the Dart VM and Chrome.

```bash
dart run tool/fetch_goldens.dart            # update vendored corpus to the pin
dart run tool/fetch_goldens.dart --verify   # CI: fail on mismatch / hard fetch failure
dart run tool/embed_goldens.dart            # refresh test/conformance/corpus_data.dart
dart run tool/verify_embed.dart             # CI: fail if embed ≠ goldens/corpus.json
```

## Value tags

Input values in the corpus carry an explicit type tag (`int` vs `double`, UTC datetimes, etc.).
See the TypeScript goldens README for why that matters on Flutter web vs mobile.
