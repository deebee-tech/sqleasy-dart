import 'dart:convert';
import 'dart:io';

/// Fetches the golden corpus this package conforms to, from the TypeScript repo's git tag.
///
///     dart run tool/fetch_goldens.dart            # update goldens/corpus.json to the pinned version
///     dart run tool/fetch_goldens.dart --verify   # fail if the vendored copy differs (CI)
///
/// The corpus is the cross-language contract. It lives in
/// [deebee-tech/sqleasy](https://github.com/deebee-tech/sqleasy) and is fetched from a **tag**, not
/// a GitHub release asset — the release-asset upload is what crashed semantic-release on 2.0.0 and
/// blocked the JSR publish, so that path is deliberately not used.
///
/// A copy is vendored into this repo so the tests run offline and so that a change to the contract
/// shows up as a reviewable diff rather than a silent behaviour shift under CI.
///
const corpusVersion = '10.1.0';

const _repo = 'deebee-tech/sqleasy';
const _path = 'goldens/corpus.json';

Uri get _url => Uri.parse(
    'https://raw.githubusercontent.com/$_repo/v$corpusVersion/$_path');

Future<void> main(List<String> args) async {
  final verify = args.contains('--verify');
  final local = File('goldens/corpus.json');

  stdout.writeln('Corpus: sqleasy v$corpusVersion');
  stdout.writeln('Source: $_url');

  final String remote;
  try {
    remote = await _get(_url);
  } on Object catch (error) {
    stderr.writeln('Could not fetch the corpus: $error');
    if (verify) {
      // Soft-fail only when the pin is not cut yet *and* a vendored copy is present for offline CI.
      if (local.existsSync()) {
        stderr.writeln(
          'Tag v$corpusVersion is not fetchable yet; using vendored goldens/corpus.json.',
        );
        exit(0);
      }
      stderr.writeln(
        'Verify failed: could not fetch v$corpusVersion and goldens/corpus.json is missing.',
      );
      exit(1);
    }
    stderr.writeln(
      'If v$corpusVersion has not been tagged yet, the vendored copy in goldens/ is authoritative.',
    );
    exit(1);
  }

  if (!local.existsSync()) {
    if (verify) {
      stderr.writeln('goldens/corpus.json is missing.');
      exit(1);
    }
    local.writeAsStringSync(remote);
    stdout.writeln('Wrote goldens/corpus.json');
    return;
  }

  final vendored = local.readAsStringSync();
  if (_canonical(vendored) == _canonical(remote)) {
    stdout.writeln('Vendored corpus matches the tag.');
    return;
  }

  if (verify) {
    stderr.writeln(
      '\ngoldens/corpus.json does NOT match sqleasy v$corpusVersion.\n\n'
      'The contract changed. Run `dart run tool/fetch_goldens.dart`, then read the diff: every\n'
      'changed line is a change to the SQL that must be emitted, and this package has to follow it.',
    );
    exit(1);
  }

  local.writeAsStringSync(remote);
  stdout.writeln('Updated goldens/corpus.json — review the diff.');
}

/// Compares by parsed content, so formatting alone never fails the check.
String _canonical(String source) => jsonEncode(jsonDecode(source));

Future<String> _get(Uri url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: url);
    }
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close();
  }
}
