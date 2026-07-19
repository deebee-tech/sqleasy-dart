import 'package:sqleasy/sqleasy.dart';
import 'package:test/test.dart';

void main() {
  group('Tier 3 — JSON operators', () {
    test('Postgres whereJsonExtract text mode', () {
      final b = PostgresQuery().newBuilder()
        ..selectAll()
        ..fromTable('users', alias: 'u')
        ..whereJsonExtract(
          'u',
          'meta',
          'email',
          JsonExtractMode.text,
          WhereOperator.equals,
          'a@b.c',
        );
      expect(b.parseRaw(), contains('"u"."meta"->>\'email\' = a@b.c'));
    });

    test('MySQL whereJsonContains', () {
      final b = MysqlQuery().newBuilder()
        ..selectAll()
        ..fromTable('users', alias: 'u')
        ..whereJsonContains('u', 'meta', {'role': 'admin'});
      expect(b.parseRaw(), contains('JSON_CONTAINS(`u`.`meta`,'));
    });

    test('selectJsonExtract on MSSQL uses JSON_VALUE', () {
      final b = MssqlQuery().newBuilder()
        ..selectJsonExtract(
          'u',
          'meta',
          r'$.email',
          JsonExtractMode.text,
          alias: 'email',
        )
        ..fromTable('users', alias: 'u');
      expect(
        b.parseRaw(),
        contains(r'JSON_VALUE([u].[meta], "$.email") AS [email]'),
      );
    });
  });

  group('Tier 3 — full-text search', () {
    test('Postgres whereMatch natural mode', () {
      final b = PostgresQuery().newBuilder()
        ..selectAll()
        ..fromTable('docs', alias: 'd')
        ..whereMatch([(table: 'd', column: 'body')], 'hello world');
      expect(b.parseRaw(), contains('plainto_tsquery'));
      expect(b.parseRaw(), contains('@@'));
    });

    test('MySQL whereMatch boolean mode', () {
      final b = MysqlQuery().newBuilder()
        ..selectAll()
        ..fromTable('docs', alias: 'd')
        ..whereMatch(
          [(table: 'd', column: 'body')],
          '+hello',
          FullTextMode.boolean,
        );
      expect(b.parseRaw(), contains('IN BOOLEAN MODE'));
    });

    test('SQLite FTS MATCH', () {
      final b = SqliteQuery().newBuilder()
        ..selectAll()
        ..fromTable('docs_fts', alias: 'd')
        ..whereMatch([(table: 'd', column: 'body')], 'hello');
      expect(b.parseRaw(), contains('"d"."body" MATCH hello'));
    });
  });

  group('Tier 3 — MSSQL MERGE upsert', () {
    test('emits MERGE for onConflictDoUpdate', () {
      final b = MssqlQuery().newBuilder()
        ..insertInto('users')
        ..insertColumns(['email', 'name'])
        ..insertValues(['a@b.c', 'Ada'])
        ..onConflictDoUpdate(
          ['email'],
          [(column: 'name', value: 'Grace')],
        );
      final sql = b.parseRaw();
      expect(sql, contains('MERGE INTO'));
      expect(sql, contains('WHEN MATCHED THEN UPDATE SET'));
    });
  });

  group('Tier 3 — LATERAL / APPLY', () {
    test('Postgres joinCrossApply maps to CROSS JOIN LATERAL', () {
      final b = PostgresQuery().newBuilder()
        ..selectAll()
        ..fromTable('orders', alias: 'o')
        ..joinCrossApply('x', (sub) {
          sub
            ..selectColumn('li', 'sku')
            ..fromTable('line_items', alias: 'li');
        });
      expect(b.parseRaw(), contains('CROSS JOIN LATERAL'));
    });

    test('MSSQL joinOuterApply', () {
      final b = MssqlQuery().newBuilder()
        ..selectAll()
        ..fromTable('orders', alias: 'o')
        ..joinOuterApply('x', (sub) {
          sub
            ..selectColumn('li', 'sku')
            ..fromTable('line_items', alias: 'li');
        });
      expect(b.parseRaw(), contains('OUTER APPLY'));
    });

    test('SQLite fromLateral throws', () {
      final b = SqliteQuery().newBuilder()
        ..selectAll()
        ..fromTable('orders', alias: 'o')
        ..fromLateral('x', (sub) {
          sub.selectAll().fromTable('line_items', alias: 'li');
        });
      expect(() => b.parseRaw(), throwsA(isA<ParserError>()));
    });
  });

  group('Tier 3 — table functions', () {
    test('Postgres fromTableFunction', () {
      final b = PostgresQuery().newBuilder()
        ..selectAll()
        ..fromTableFunction('generate_series', 'g', [1, 3]);
      expect(
        b.parseRaw(),
        contains('FROM "public"."generate_series"(1, 3) AS "g"'),
      );
    });

    test('SQLite json_each TVF', () {
      final b = SqliteQuery().newBuilder()
        ..selectAll()
        ..fromTableFunction('json_each', 'j', ['{"a":1}']);
      expect(b.parseRaw(), contains('json_each({"a":1})'));
    });
  });

  group('Tier 3 — grouping sets', () {
    test('Postgres groupByRollup', () {
      final b = PostgresQuery().newBuilder()
        ..selectColumn('o', 'region')
        ..fromTable('orders', alias: 'o')
        ..groupByRollup([(table: 'o', column: 'region')]);
      expect(b.parseRaw(), contains('GROUP BY ROLLUP ("o"."region")'));
    });

    test('MySQL groupByRollup uses WITH ROLLUP', () {
      final b = MysqlQuery().newBuilder()
        ..selectColumn('o', 'region')
        ..fromTable('orders', alias: 'o')
        ..groupByColumn('o', 'region')
        ..groupByRollup();
      expect(b.parseRaw(), contains('GROUP BY `o`.`region` WITH ROLLUP'));
    });
  });

  group('Tier 3 — WITH TIES', () {
    test('Postgres limitWithTies', () {
      final b = PostgresQuery().newBuilder()
        ..selectColumn('o', 'id')
        ..fromTable('orders', alias: 'o')
        ..orderByColumn('o', 'total', OrderByDirection.descending)
        ..limitWithTies(5);
      expect(b.parseRaw(), contains('FETCH FIRST 5 ROWS WITH TIES'));
    });

    test('SQLite limitWithTies throws', () {
      final b = SqliteQuery().newBuilder()
        ..selectAll()
        ..fromTable('orders', alias: 'o')
        ..orderByColumn('o', 'total', OrderByDirection.descending)
        ..limitWithTies(5);
      expect(() => b.parseRaw(), throwsA(isA<ParserError>()));
    });
  });

  group('Tier 3 — hints', () {
    test('MySQL hintUseIndex', () {
      final b = MysqlQuery().newBuilder()
        ..selectAll()
        ..fromTable('users', alias: 'u')
        ..hintUseIndex('u', 'users_email_idx');
      expect(b.parseRaw(), contains('USE INDEX (`users_email_idx`)'));
    });

    test('MSSQL hintMssqlOption', () {
      final b = MssqlQuery().newBuilder()
        ..selectAll()
        ..fromTable('users', alias: 'u')
        ..orderByColumn('u', 'id', OrderByDirection.ascending)
        ..limit(10)
        ..hintMssqlOption('RECOMPILE');
      expect(b.parseRaw(), contains('OPTION (RECOMPILE)'));
    });
  });
}
