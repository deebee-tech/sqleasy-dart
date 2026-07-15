import 'package:test/test.dart';

import 'corpus.dart';
import 'corpus_data.dart';
import 'driver.dart';

/// Replays the frozen golden corpus through the idiomatic Dart API and asserts byte-for-byte
/// agreement with the TypeScript implementation, for every dialect.
///
/// This is where the port is proven. It MUST pass on the Dart VM *and* under dart2js:
///
///     dart test test/conformance
///     dart test test/conformance -p chrome
///
/// The two platforms disagree about numbers, so a green run on only one is not enough. See
/// `goldens/README.md`.
void main() {
  final corpus = Corpus.parse(corpusJson);

  test('corpus loaded', () {
    expect(corpus.cases, isNotEmpty);
  });

  for (final c in corpus.cases) {
    group(c.name, () {
      for (final dialect in c.targetDialects) {
        test(dialect, () {
          final golden = c.expect[dialect];
          expect(golden, isNotNull, reason: 'no golden recorded for $dialect');

          expect(runCase(c, dialect), equals(golden));
        });
      }
    });
  }
}
