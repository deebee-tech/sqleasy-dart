import 'package:sqleasy/sqleasy.dart';
import 'package:test/test.dart';

/// The `Fn` scalar surface. These assert the exact SQL string per dialect — byte-identical to the
/// TypeScript port's `tests/shared/scalar.test.ts`, so any divergence between the two implementations
/// shows up as one of these expectations going red.
void main() {
  group('Fn.concat', () {
    test('MSSQL uses native CONCAT', () {
      expect(Fn.concat(['a', 'b'], DatabaseType.mssql), 'CONCAT(a, b)');
    });
    test('Postgres casts each operand to text and coalesces', () {
      expect(Fn.concat(['a', 'b'], DatabaseType.postgres),
          "(COALESCE(CAST(a AS text), '') || COALESCE(CAST(b AS text), ''))");
    });
    test('MySQL wraps coalesced operands in CONCAT', () {
      expect(Fn.concat(['a', 'b'], DatabaseType.mysql),
          "CONCAT(COALESCE(a, ''), COALESCE(b, ''))");
    });
    test('SQLite joins coalesced operands with ||', () {
      expect(Fn.concat(['a', 'b'], DatabaseType.sqlite),
          "(COALESCE(a, '') || COALESCE(b, ''))");
    });
  });

  group('Fn.charLength', () {
    test('LEN / CHAR_LENGTH / LENGTH (characters, not bytes)', () {
      expect(Fn.charLength('c', DatabaseType.mssql), 'LEN(c)');
      expect(Fn.charLength('c', DatabaseType.mysql), 'CHAR_LENGTH(c)');
      expect(Fn.charLength('c', DatabaseType.postgres), 'LENGTH(c)');
      expect(Fn.charLength('c', DatabaseType.sqlite), 'LENGTH(c)');
    });
  });

  group('Fn.round', () {
    test('Postgres casts to numeric; others round directly', () {
      expect(Fn.round('x', 2, DatabaseType.postgres),
          'ROUND(CAST(x AS numeric), 2)');
      expect(Fn.round('x', 2, DatabaseType.mysql), 'ROUND(x, 2)');
      expect(Fn.round('x', '0', DatabaseType.sqlite), 'ROUND(x, 0)');
      expect(Fn.round('x', 0, DatabaseType.mssql), 'ROUND(x, 0)');
    });
  });

  group('Fn.now', () {
    test('emits each dialect current-timestamp expression', () {
      expect(Fn.now(DatabaseType.mssql), 'GETDATE()');
      expect(Fn.now(DatabaseType.mysql), 'NOW()');
      expect(Fn.now(DatabaseType.sqlite), "datetime('now')");
      expect(Fn.now(DatabaseType.postgres), 'CURRENT_TIMESTAMP');
      expect(Fn.now(DatabaseType.unknown), 'CURRENT_TIMESTAMP');
    });
  });

  group('Fn.divide', () {
    test(
        'forces fractional division on integer-division dialects, leaves MySQL a plain /',
        () {
      expect(Fn.divide('n', 'd', DatabaseType.postgres),
          '(CAST(n AS numeric) / d)');
      expect(Fn.divide('n', 'd', DatabaseType.mssql),
          '(CAST(n AS decimal(38, 10)) / d)');
      expect(Fn.divide('n', 'd', DatabaseType.sqlite), '(CAST(n AS REAL) / d)');
      expect(Fn.divide('n', 'd', DatabaseType.mysql), '(n / d)');
    });
  });
}
