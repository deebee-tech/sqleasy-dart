import 'package:sqleasy/sqleasy.dart';
import 'package:test/test.dart';

void main() {
  group('INSERT...SELECT', () {
    test('renders SELECT in place of VALUES', () {
      final builder = PostgresQuery().newBuilder()
        ..insertInto('archive')
        ..insertColumns(['id', 'total'])
        ..insertSelect((sub) => sub
          ..selectColumn('o', 'id')
          ..selectColumn('o', 'total')
          ..fromTable('orders', alias: 'o')
          ..where('o', 'archived', WhereOperator.equals, true));

      expect(
        builder.parseRaw(),
        'INSERT INTO "public"."archive" ("id", "total") SELECT "o"."id", "o"."total" FROM "public"."orders" AS "o" WHERE "o"."archived" = true;',
      );
    });

    test('throws when combined with insertValues', () {
      final builder = SqliteQuery().newBuilder()
        ..insertInto('archive')
        ..insertColumns(['id'])
        ..insertValues([1])
        ..insertSelect((sub) => sub
          ..selectColumn('o', 'id')
          ..fromTable('orders', alias: 'o'));

      expect(() => builder.parseRaw(), throwsA(isA<ParserError>()));
    });
  });
}
