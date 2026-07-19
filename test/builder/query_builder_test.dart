import 'package:sqleasy/sqleasy.dart';
import 'package:sqleasy/src/enums.dart' show QueryType;
import 'package:test/test.dart';

/// Mirrors the "M1 foundation fixes" describe block in the TypeScript port's
/// tests/shared/builder.test.ts, plus a Dart-only case for the equivalent JOIN ON auto-AND (the
/// TypeScript suite exercises that behavior only through `defaultJoin`, not `builder.test.ts`).
///
/// `builder.state` is whitebox — it returns the same [QueryState] the parser reads — so these tests
/// reach into it the same way the TypeScript tests call `builder.state()`.
void main() {
  final query = MssqlQuery();

  group('M1 foundation fixes', () {
    test('auto-ANDs consecutive WHERE predicates', () {
      final builder = query.newBuilder();
      builder
          .selectAll()
          .fromTable('users', alias: 'u')
          .where('u', 'a', WhereOperator.equals, 1)
          .where('u', 'b', WhereOperator.equals, 2);

      expect(builder.parsePrepared().sql,
          contains('WHERE [u].[a] = @p0 AND [u].[b] = @p1'));
    });

    test('auto-ANDs consecutive JOIN ON predicates', () {
      final builder = query.newBuilder();
      builder.selectAll().fromTable('users', alias: 'u').joinTable(
            JoinType.inner,
            'orders',
            (j) => j
                .on('u', 'id', JoinOperator.equals, 'o', 'user_id')
                .onValue('o', 'active', JoinOperator.equals, true),
            alias: 'o',
          );

      expect(
        builder.parsePrepared().sql,
        contains('ON [u].[id] = [o].[user_id] AND [o].[active] = @p0'),
      );
    });

    test('clearUpdate removes the UPDATE-owned FROM target', () {
      final builder = query.newBuilder();
      builder.updateTable('users', alias: 'u').set('name', 'Ada');
      expect(builder.state.fromStates.length, 1);

      builder.clearUpdate();
      expect(builder.state.fromStates, isEmpty);
      expect(builder.state.mutationTargetIndex, isNull);
      expect(builder.state.queryType, QueryType.select);
    });

    test('clearDelete clears sticky DELETE query type and target', () {
      final builder = query.newBuilder();
      builder.deleteFrom('users', alias: 'u');
      expect(builder.state.queryType, QueryType.delete);

      builder.clearDelete();
      expect(builder.state.queryType, QueryType.select);
      expect(builder.state.fromStates, isEmpty);
    });

    test('selectAll resets sticky DELETE query type', () {
      final builder = query.newBuilder();
      builder
          .deleteFrom('users', alias: 'u')
          .selectAll()
          .fromTable('orders', alias: 'o');

      expect(builder.state.queryType, QueryType.select);
      expect(builder.parsePrepared().sql,
          matches(RegExp(r'^SET NOCOUNT ON;.*SELECT \*')));
    });

    test('clearHaving resets combinator target to WHERE', () {
      final builder = query.newBuilder();
      builder
          .selectAll()
          .fromTable('users', alias: 'u')
          .groupByColumn('u', 'status')
          .having('u', 'status', WhereOperator.equals, 'a')
          .clearHaving()
          .where('u', 'id', WhereOperator.equals, 1)
          .and()
          .where('u', 'active', WhereOperator.equals, true);

      expect(builder.state.havingStates, isEmpty);
      final sql = builder.parsePrepared().sql;
      expect(sql, contains('WHERE [u].[id] = @p0 AND [u].[active] = @p1'));
      expect(sql, isNot(contains('HAVING')));
    });

    test(
        'defensively copies insertColumns / insertValues / whereInValues lists',
        () {
      final cols = ['name'];
      final vals = ['Ada'];
      final ids = [1, 2];

      final builder = query.newBuilder();
      builder.insertInto('users').insertColumns(cols).insertValues(vals);
      cols.add('x');
      vals.add('y');
      expect(builder.state.insertState?.columns, ['name']);
      expect(builder.state.insertState?.values[0], ['Ada']);

      final select = query.newBuilder();
      select
          .selectAll()
          .fromTable('users', alias: 'u')
          .whereInValues('u', 'id', ids);
      ids.add(3);
      expect(select.state.whereStates[0].values, [1, 2]);
    });

    test('also defensively copies whereNotInValues', () {
      final ids = [1, 2];
      final builder = query.newBuilder();
      builder
          .selectAll()
          .fromTable('users', alias: 'u')
          .whereNotInValues('u', 'id', ids);
      ids.add(3);
      expect(builder.state.whereStates[0].values, [1, 2]);
    });

    test('UPDATE prefers updateTable target over a prior fromTable', () {
      final builder = query.newBuilder();
      builder
          .fromTable('users', alias: 'u')
          .updateTable('orders', alias: 'o')
          .set('total', 1);

      final sql = builder.parsePrepared().sql;
      expect(sql, contains('UPDATE [o] SET'));
      expect(sql, contains('FROM [dbo].[orders] AS [o]'));
    });

    test('DELETE prefers deleteFrom target over a prior fromTable', () {
      final builder = query.newBuilder();
      builder.fromTable('users', alias: 'u').deleteFrom('orders', alias: 'o');

      expect(builder.parsePrepared().sql,
          contains('DELETE [o] FROM [dbo].[orders] AS [o]'));
    });

    test('rejects empty whereGroup', () {
      final builder = query.newBuilder();
      expect(
        () => builder
            .selectAll()
            .fromTable('users', alias: 'u')
            .whereGroup((b) {}),
        throwsA(
          isA<ParserError>().having((e) => e.toString(), 'message',
              contains('WHERE group cannot be empty')),
        ),
      );
    });

    test('rejects non-positive limit', () {
      final builder = query.newBuilder();
      expect(
        () => builder.limit(0),
        throwsA(
          isA<ParserError>().having((e) => e.toString(), 'message',
              contains('LIMIT must be a positive integer')),
        ),
      );
      expect(
        () => builder.limit(-1),
        throwsA(
          isA<ParserError>().having((e) => e.toString(), 'message',
              contains('LIMIT must be a positive integer')),
        ),
      );
    });

    test('HAVING First/Last/Consecutive AND/OR rules', () {
      final builder = query.newBuilder()
        ..selectAll()
        ..fromTable('users', alias: 'u')
        ..groupByColumn('u', 'status');

      expect(
        () => builder
            .and()
            .having('u', 'status', WhereOperator.equals, 'a')
            .parsePrepared(),
        throwsA(isA<ParserError>()),
      );

      final ok = query.newBuilder()
        ..selectAll()
        ..fromTable('users', alias: 'u')
        ..groupByColumn('u', 'status')
        ..having('u', 'status', WhereOperator.equals, 'a')
        ..or()
        ..having('u', 'status', WhereOperator.equals, 'b');
      expect(ok.parsePrepared().sql, contains('HAVING'));
      expect(ok.parsePrepared().sql, contains(' OR '));
    });
  });

  group('M2 Tier 1 features', () {
    test('clearReturning removes a previously set clause', () {
      final pg = PostgresQuery();
      final builder = pg.newBuilder()
        ..insertInto('users')
        ..insertColumns(['name'])
        ..insertValues(['Ada'])
        ..returning(['id']);

      builder.clearReturning();

      expect(builder.parseRaw(),
          'INSERT INTO "public"."users" ("name") VALUES (Ada);');
    });

    test('clearUpsert removes a previously configured conflict clause', () {
      final pg = PostgresQuery();
      final builder = pg.newBuilder()
        ..insertInto('users')
        ..insertColumns(['email'])
        ..insertValues(['ada@example.com'])
        ..onConflictDoNothing(['email']);

      builder.clearUpsert();

      expect(builder.parseRaw(),
          'INSERT INTO "public"."users" ("email") VALUES (ada@example.com);');
    });

    test('clearInsert also clears the upsert clause', () {
      final pg = PostgresQuery();
      final builder = pg.newBuilder()
        ..insertInto('users')
        ..insertColumns(['email'])
        ..insertValues(['ada@example.com'])
        ..onConflictDoNothing(['email']);

      builder.clearInsert();

      expect(builder.state.upsertState, isNull);
    });

    test('clearRowLock removes a previously configured lock', () {
      final pg = PostgresQuery();
      final builder = pg.newBuilder()
        ..selectAll()
        ..fromTable('users', alias: 'u')
        ..forUpdate();

      builder.clearRowLock();

      expect(builder.parseRaw(), 'SELECT * FROM "public"."users" AS "u";');
    });

    test('RETURNING/OUTPUT is refused on a SELECT', () {
      final pg = PostgresQuery();
      final builder = pg.newBuilder()
        ..selectAll()
        ..fromTable('users', alias: 'u')
        ..returning(['id']);

      expect(
        () => builder.parsePrepared(),
        throwsA(isA<ParserError>().having((e) => e.toString(), 'message',
            contains('RETURNING/OUTPUT requires INSERT, UPDATE, or DELETE'))),
      );
    });

    test('upsert requires INSERT', () {
      final pg = PostgresQuery();
      final builder = pg.newBuilder()
        ..selectAll()
        ..fromTable('users', alias: 'u')
        ..onConflictDoNothing();

      expect(
        () => builder.parsePrepared(),
        throwsA(isA<ParserError>().having((e) => e.toString(), 'message',
            contains('Upsert (ON CONFLICT) requires INSERT'))),
      );
    });

    test('FOR UPDATE/FOR SHARE is refused outside a SELECT', () {
      final pg = PostgresQuery();
      final builder = pg.newBuilder()
        ..insertInto('users')
        ..insertColumns(['name'])
        ..insertValues(['Ada'])
        ..forUpdate();

      expect(
        () => builder.parsePrepared(),
        throwsA(isA<ParserError>().having((e) => e.toString(), 'message',
            contains('FOR UPDATE/FOR SHARE requires a SELECT query'))),
      );
    });

    test('defensively copies returning columns / conflict columns lists', () {
      final pg = PostgresQuery();
      final cols = ['id'];
      final conflictCols = ['email'];

      final builder = pg.newBuilder()
        ..insertInto('users')
        ..insertColumns(['email'])
        ..insertValues(['ada@example.com'])
        ..onConflictDoNothing(conflictCols)
        ..returning(cols);

      cols.add('name');
      conflictCols.add('id');

      expect(builder.state.returningState?.columns, ['id']);
      expect(builder.state.upsertState?.conflictColumns, ['email']);
    });

    test('defensively copies havingInValues / havingNotInValues lists', () {
      final pg = PostgresQuery();
      final inValues = [1, 2];
      final notInValues = [3, 4];

      final builder = pg.newBuilder()
        ..selectAll()
        ..fromTable('users', alias: 'u')
        ..groupByColumn('u', 'status')
        ..havingInValues('u', 'id', inValues)
        ..havingNotInValues('u', 'id', notInValues);

      inValues.add(5);
      notInValues.add(6);

      expect(builder.state.havingStates[0].values, [1, 2]);
      expect(builder.state.havingStates[1].values, [3, 4]);
    });

    test('havingGroup rejects an empty group', () {
      final pg = PostgresQuery();
      final builder = pg.newBuilder()
        ..selectAll()
        ..fromTable('users', alias: 'u')
        ..groupByColumn('u', 'status');

      expect(
        () => builder.havingGroup((b) {}),
        throwsA(isA<ParserError>().having((e) => e.toString(), 'message',
            contains('HAVING group cannot be empty'))),
      );
    });

    test('ILIKE is native on Postgres and rewritten to LOWER() elsewhere', () {
      final pgBuilder = PostgresQuery().newBuilder()
        ..selectAll()
        ..fromTable('users', alias: 'u')
        ..where('u', 'name', WhereOperator.ilike, '%ada%');
      expect(pgBuilder.parsePrepared().sql, contains('ILIKE'));

      final sqliteBuilder = SqliteQuery().newBuilder()
        ..selectAll()
        ..fromTable('users', alias: 'u')
        ..where('u', 'name', WhereOperator.ilike, '%ada%');
      expect(sqliteBuilder.parsePrepared().sql,
          contains('LOWER("u"."name") LIKE LOWER(?)'));
    });

    test('whereExists / whereNotExists build without a table/column', () {
      final builder = PostgresQuery().newBuilder()
        ..selectAll()
        ..fromTable('users', alias: 'u')
        ..whereExists((sub) => sub
          ..selectAll()
          ..fromTable('orders', alias: 'o')
          ..where('o', 'user_id', WhereOperator.equals, 1));

      expect(builder.parsePrepared().sql, contains('WHERE EXISTS ('));
    });
  });
}
