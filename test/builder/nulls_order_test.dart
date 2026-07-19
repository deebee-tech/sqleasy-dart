import 'package:sqleasy/sqleasy.dart';
import 'package:test/test.dart';

void main() {
  group('ORDER BY NULLS FIRST/LAST', () {
    test('Postgres renders native NULLS LAST', () {
      final builder = PostgresQuery().newBuilder()
        ..selectAll()
        ..fromTable('orders', alias: 'o')
        ..orderByColumn(
            'o', 'shipped_at', OrderByDirection.ascending, NullsOrder.last);

      expect(builder.parseRaw(),
          contains('ORDER BY "o"."shipped_at" ASC NULLS LAST'));
    });

    test('MySQL emulates NULLS LAST with a CASE sort key', () {
      final builder = MysqlQuery().newBuilder()
        ..selectAll()
        ..fromTable('orders', alias: 'o')
        ..orderByColumn(
            'o', 'shipped_at', OrderByDirection.ascending, NullsOrder.last);

      expect(
        builder.parseRaw(),
        contains(
          'ORDER BY CASE WHEN `o`.`shipped_at` IS NULL THEN 1 ELSE 0 END, `o`.`shipped_at` ASC',
        ),
      );
    });
  });
}
