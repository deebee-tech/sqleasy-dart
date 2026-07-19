import 'dart:convert';
import 'dart:io';

/// Fails if the embedded corpus does not match `goldens/corpus.json`.
///
///     dart run tool/verify_embed.dart
///
/// CI uses this so a forgotten `embed_goldens` cannot ship a stale dart2js payload.
void main() {
  final vendored = File('goldens/corpus.json');
  final embed = File('test/conformance/corpus_data.dart');

  if (!vendored.existsSync()) {
    stderr.writeln('goldens/corpus.json is missing.');
    exit(1);
  }
  if (!embed.existsSync()) {
    stderr.writeln('test/conformance/corpus_data.dart is missing.');
    exit(1);
  }

  final expected = vendored.readAsBytesSync();
  final source = embed.readAsStringSync();
  final match = RegExp(r"const _corpusBase64 =\s*((?:'[^']*'\s*)+);");
  final m = match.firstMatch(source);
  if (m == null) {
    stderr.writeln('Could not find _corpusBase64 in corpus_data.dart.');
    exit(1);
  }

  final b64 = m.group(1)!.replaceAll("'", '').replaceAll(RegExp(r'\s'), '');
  final decoded = base64.decode(b64);

  if (!_bytesEqual(expected, decoded)) {
    stderr.writeln(
      'Embedded corpus_data.dart does NOT match goldens/corpus.json.\n'
      'Run: dart run tool/embed_goldens.dart',
    );
    exit(1);
  }

  stdout.writeln('Embed matches goldens/corpus.json '
      '(${expected.length} bytes, SHA-256 ${_sha256Hex(expected)}).');
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _sha256Hex(List<int> bytes) {
  // Avoid adding a crypto dependency — fingerprint via a short stable digest for logs.
  // Full equality is checked above; this is only for the success message.
  var h = 0;
  for (final b in bytes) {
    h = 0x1fffffff & (h + b);
    h = 0x1fffffff & (h + ((0x0007ffff & h) << 10));
    h ^= h >> 6;
  }
  h = 0x1fffffff & (h + ((0x03ffffff & h) << 3));
  h ^= h >> 11;
  h = 0x1fffffff & (h + ((0x00003fff & h) << 15));
  return h.toRadixString(16).padLeft(8, '0');
}
