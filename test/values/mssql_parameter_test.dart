import 'package:sqleasy/sqleasy.dart';
import 'package:sqleasy/src/values/mssql_parameter.dart';
import 'package:test/test.dart';

/// A BigInt bound value on the MSSQL sp_executesql inline path.
///
/// TypeScript routes a `bigint` through mssqlParameterValue's `default` branch — `N'<digits>'`,
/// declared `nvarchar(max)`. The Dart port used to fall through to `jsonEncode`, which cannot encode
/// a BigInt and threw `JsonUnsupportedObjectError`. These lock the two implementations to the same
/// behaviour. BigInt is arbitrary-precision on the VM and dart2js alike, so the output is identical
/// on both platforms — run `dart test` and `dart test -p chrome`.
void main() {
  group('mssqlParameter with a BigInt', () {
    test('mssqlParameterValue inlines a BigInt as an N-quoted literal', () {
      expect(mssqlParameterValue(BigInt.from(123)), "N'123'");
      expect(
        mssqlParameterValue(BigInt.parse('9007199254740993')),
        "N'9007199254740993'",
      );
    });

    test('mssqlParameterType declares a BigInt as nvarchar(max), matching TS', () {
      expect(mssqlParameterType(BigInt.from(123)), 'nvarchar(max)');
    });

    test('MssqlQuery emits sp_executesql for a BigInt instead of throwing', () {
      final b = MssqlQuery().newBuilder();
      b
          .selectAll()
          .fromTable('t', alias: 't')
          .where('t', 'x', WhereOperator.equals, BigInt.from(123));

      final prepared = b.parsePrepared();

      expect(prepared.sql, contains('@p0 nvarchar(max)'));
      expect(prepared.sql, contains("@p0 = N'123'"));
      expect(prepared.params, isEmpty); // MSSQL inlines
    });
  });
}
