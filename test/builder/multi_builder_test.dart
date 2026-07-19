import 'package:sqleasy/sqleasy.dart';
import 'package:test/test.dart';

/// Mirrors the multi-builder execution contract in the TypeScript port's
/// tests/shared/engine_param_contract.test.ts.
///
/// `preparedStatements()` is the execution-safe handle an executor consumes: each builder rendered
/// as its own `(sql, params)`, in batch order, WITHOUT the BEGIN/COMMIT wrapping — the executor
/// opens the transaction and runs the statements one by one. `parse()`/`parseRaw()` are display-only
/// (no bound params) and, because numbering restarts per statement, are not runnable as one call.
void main() {
  // Fill a batch with the same two statements used on the TypeScript side.
  (QueryBuilder, QueryBuilder) fill(MultiBuilder multi) {
    final b1 = multi.addBuilder('ins');
    b1
        .insertInto('users')
        .insertColumns(['name', 'age']).insertValues(['Ada', 36]);
    final b2 = multi.addBuilder('upd');
    b2
        .updateTable('stats', alias: 's')
        .set('n', 100)
        .where('s', 'id', WhereOperator.equals, 1);
    return (b1, b2);
  }

  group('MultiBuilder.preparedStatements()', () {
    test(
        'returns each builder prepared, in order, without transaction delimiters',
        () {
      final multi = PostgresQuery().newMultiBuilder();
      fill(multi);

      final stmts = multi.preparedStatements();

      expect(stmts, hasLength(2));
      expect(stmts[0].sql,
          'INSERT INTO "public"."users" ("name", "age") VALUES (\$1, \$2);');
      expect(stmts[0].params, equals(['Ada', 36]));
      expect(stmts[1].sql,
          'UPDATE "public"."stats" AS "s" SET "n" = \$1 WHERE "s"."id" = \$2;');
      expect(stmts[1].params, equals([100, 1]));

      // BEGIN/COMMIT wrapping is the executor's job (via transactionState()), never baked in here.
      for (final s in stmts) {
        expect(s.sql, isNot(contains('BEGIN')));
        expect(s.sql, isNot(contains('COMMIT')));
      }
    });

    test(
        'reflects reorder and yields MSSQL self-contained batches with empty params',
        () {
      final multi = MssqlQuery().newMultiBuilder();
      fill(multi);
      multi.reorderBuilders(['upd', 'ins']);

      final stmts = multi.preparedStatements();

      expect(stmts, hasLength(2));
      expect(
          stmts[0].sql, contains('UPDATE [s] SET')); // reordered: update first
      expect(stmts[1].sql, contains('INSERT INTO [dbo].[users]'));
      // MSSQL inlines into sp_executesql, so every statement binds no params.
      expect(stmts.every((s) => s.params.isEmpty), isTrue);
    });

    test('covers MySQL and SQLite placeholder styles across three statements',
        () {
      for (final multi in [
        MysqlQuery().newMultiBuilder(),
        SqliteQuery().newMultiBuilder(),
      ]) {
        fill(multi);
        multi
            .addBuilder('del')
            .deleteFrom('users', alias: 'u')
            .where('u', 'id', WhereOperator.equals, 9);

        final stmts = multi.preparedStatements();
        expect(stmts, hasLength(3));
        expect(stmts[0].params, equals(['Ada', 36]));
        expect(stmts[1].params, equals([100, 1]));
        expect(stmts[2].params, equals([9]));
        expect(stmts.every((s) => s.sql.contains('?')), isTrue);
      }
    });
  });
}
