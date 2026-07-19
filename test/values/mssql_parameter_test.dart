import 'dart:typed_data';

import 'package:sqleasy/sqleasy.dart';
import 'package:sqleasy/src/values/mssql_parameter.dart';
import 'package:test/test.dart';

/// MSSQL `sp_executesql` parameter typing/inlining for BigInt and binary values.
///
/// Mirrors TypeScript's `typeof 'bigint'` and `Uint8Array` arms: BigInt → declared `bigint` with a
/// bare decimal literal; `Uint8List` → `varbinary(max)` with a `0x` hex literal.
void main() {
  group('mssqlParameter with a BigInt', () {
    test('mssqlParameterValue inlines a BigInt as a bare decimal', () {
      expect(mssqlParameterValue(BigInt.from(123)), '123');
      expect(
        mssqlParameterValue(BigInt.parse('9007199254740993')),
        '9007199254740993',
      );
    });

    test('mssqlParameterType declares a BigInt as bigint', () {
      expect(mssqlParameterType(BigInt.from(123)), 'bigint');
    });

    test('MssqlQuery emits sp_executesql for a BigInt instead of throwing', () {
      final b = MssqlQuery().newBuilder();
      b
          .selectAll()
          .fromTable('t', alias: 't')
          .where('t', 'x', WhereOperator.equals, BigInt.from(123));

      final prepared = b.parsePrepared();

      expect(prepared.sql, contains('@p0 bigint'));
      expect(prepared.sql, contains('@p0 = 123'));
      expect(prepared.params, isEmpty); // MSSQL inlines
    });
  });

  group('mssqlParameter with binary', () {
    test('mssqlParameterType declares Uint8List as varbinary(max)', () {
      expect(
          mssqlParameterType(Uint8List.fromList([1, 2, 3])), 'varbinary(max)');
    });

    test('mssqlParameterValue inlines Uint8List as a 0x hex literal', () {
      expect(mssqlParameterValue(Uint8List.fromList([1, 2, 3])), '0x010203');
      expect(mssqlParameterValue(Uint8List.fromList([0xde, 0xad])), '0xdead');
    });

    test('MssqlQuery inlines Buffer-equivalent bytes as varbinary hex', () {
      final b = MssqlQuery().newBuilder();
      b.selectAll().fromTable('t', alias: 't').where(
          't', 'blob', WhereOperator.equals, Uint8List.fromList([1, 2, 3]));

      final sql = b.parse();
      expect(sql, contains('@p0 varbinary(max)'));
      expect(sql, contains('@p0 = 0x010203'));
    });
  });
}
