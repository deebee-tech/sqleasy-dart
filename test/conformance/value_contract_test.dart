import 'package:sqleasy/src/values/mssql_parameter.dart';
import 'package:test/test.dart';

import 'corpus.dart';
import 'corpus_data.dart';

/// Checks the value layer against the **real frozen golden corpus**, before the builder exists.
///
/// The corpus records, for every case, the exact SQL the TypeScript implementation emits. For MSSQL
/// that includes the `sp_executesql` parameter declarations — `N'@p0 tinyint, @p1 float'` — and the
/// inlined values — `@p0 = 5, @p1 = 5.5`. Those two lists are produced *entirely* by the value
/// layer, so they can be verified now, with no parser and no builder in the way.
///
/// This is the cheapest possible place to catch the number/date divergence, and it runs under
/// dart2js as well as the VM. See `goldens/README.md`.
void main() {
  final corpus = Corpus.parse(corpusJson);

  group('golden corpus', () {
    test('parses, and every case declares its expectations', () {
      expect(corpus.cases, isNotEmpty);

      for (final c in corpus.cases) {
        for (final dialect in c.targetDialects) {
          expect(
            c.expect[dialect],
            isNotNull,
            reason: 'case "${c.name}" has no golden for $dialect',
          );
        }
      }
    });

    test('every input value decodes, and doubles stay doubles', () {
      var ints = 0;
      var doubles = 0;

      for (final c in corpus.cases) {
        for (final value in _inputValuesOf(c)) {
          final decoded = decodeInputValue(value);
          final tag = value['t'];

          if (tag == 'int') {
            expect(decoded, isA<int>(), reason: 'in case "${c.name}"');
            ints++;
          } else if (tag == 'double') {
            // The corpus tags `{"t":"double","v":5}` — an INTEGRAL double. A driver that decodes it
            // into an `int` has silently thrown away the exact thing this corpus tests.
            expect(decoded, isA<double>(), reason: 'in case "${c.name}"');
            doubles++;
          }
        }
      }

      expect(ints, greaterThan(0));
      expect(doubles, greaterThan(0),
          reason: 'the corpus must exercise doubles');
    });
  });

  /// The MSSQL golden is the value layer's output, verbatim. Reproduce it from the inputs alone.
  group('MSSQL sp_executesql declarations match the golden', () {
    for (final c in corpus.cases) {
      final golden = c.expect['mssql'];
      if (golden is! Map<String, Object?>) continue;

      final prepared = golden['prepared'];
      if (prepared is! Map<String, Object?>) continue; // a `throws` case

      final sql = prepared['sql']! as String;
      final declarations = _parseDeclarations(sql);
      final assignments = _parseAssignments(sql);

      // Only cases whose values are all scalar top-level inputs can be reconstructed without the
      // parser. Nested sub-builders reorder values, and that ordering is the parser's job — it is
      // verified by the full conformance suite once the builder lands.
      final values = _flatScalarValues(c);
      if (values == null || values.length != declarations.length) continue;
      if (declarations.isEmpty) continue;

      test(c.name, () {
        for (var i = 0; i < values.length; i++) {
          final decoded = decodeInputValue(values[i]);

          expect(
            mssqlParameterType(decoded),
            declarations[i],
            reason:
                '@p$i declared type disagrees with the golden, for input ${values[i]}',
          );
          expect(
            mssqlParameterValue(decoded),
            assignments[i],
            reason:
                '@p$i inlined value disagrees with the golden, for input ${values[i]}',
          );
        }
      });
    }
  });
}

/// `N'@p0 tinyint, @p1 float'` -> `['tinyint', 'float']`.
List<String> _parseDeclarations(String sql) {
  final match = RegExp(r"', N'([^']*)'").firstMatch(sql);
  final body = match?.group(1) ?? '';
  if (body.isEmpty) return const [];

  return body.split(', ').map((d) => d.substring(d.indexOf(' ') + 1)).toList();
}

/// `, @p0 = 5, @p1 = 5.5;` -> `['5', '5.5']`.
List<String> _parseAssignments(String sql) {
  final out = <String>[];
  for (var i = 0;; i++) {
    final marker = '@p$i = ';
    final start = sql.indexOf(marker);
    if (start < 0) break;

    final from = start + marker.length;
    final next = sql.indexOf('@p${i + 1} = ');
    final end = next < 0 ? sql.length - 1 : sql.lastIndexOf(', ', next);
    out.add(sql.substring(from, end < from ? sql.length - 1 : end));
  }
  return out;
}

/// The case's top-level scalar input values, in op order — or null if it nests a sub-builder, whose
/// value ordering only the parser can decide.
List<Map<String, Object?>>? _flatScalarValues(GoldenCase c) {
  final ops = c.ops;
  if (ops == null) return null;

  final out = <Map<String, Object?>>[];
  for (final op in ops) {
    if (op.containsKey('ops') ||
        op.containsKey('on') ||
        op.containsKey('builders')) {
      return null;
    }
    // On MSSQL, `procParamInOut` emits its `DECLARE @name TYPE = value` *before* the
    // EXEC/positional args — so if it is not the first value-bearing op, the emitted parameter
    // order no longer matches declaration order. Reordering it correctly is the parser's job
    // (verified by the full conformance suite); this whitebox helper only handles simple
    // sequential emission.
    if (op['op'] == 'procParamInOut') {
      return null;
    }
    for (final key in const ['value', 'from', 'to']) {
      final v = op[key];
      if (v is Map<String, Object?>) out.add(v);
    }
    final values = op['values'];
    if (values is List) {
      for (final v in values) {
        if (v is Map<String, Object?>) out.add(v);
      }
    }
  }
  return out;
}

Iterable<Map<String, Object?>> _inputValuesOf(GoldenCase c) sync* {
  Iterable<Map<String, Object?>> walk(List<Map<String, Object?>> ops) sync* {
    for (final op in ops) {
      for (final key in const ['value', 'from', 'to']) {
        final v = op[key];
        if (v is Map<String, Object?>) yield v;
      }
      final values = op['values'];
      if (values is List) {
        for (final v in values) {
          if (v is Map<String, Object?>) yield v;
        }
      }
      for (final key in const ['ops', 'on']) {
        final nested = op[key];
        if (nested is List) {
          yield* walk(nested.cast<Map<String, Object?>>());
        }
      }
    }
  }

  if (c.ops != null) yield* walk(c.ops!);
  for (final b in c.builders ?? const <Map<String, Object?>>[]) {
    final ops = b['ops'];
    if (ops is List) yield* walk(ops.cast<Map<String, Object?>>());
  }
}
