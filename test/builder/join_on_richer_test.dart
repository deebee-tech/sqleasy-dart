import 'package:sqleasy/sqleasy.dart';
import 'package:test/test.dart';

void main() {
  group('richer JOIN ON predicates', () {
    test('supports LIKE between two columns', () {
      final builder = PostgresQuery().newBuilder()
        ..selectAll()
        ..fromTable('products', alias: 'p')
        ..joinTable(JoinType.inner, 'categories', (j) {
          j.on('p', 'name', JoinOperator.like, 'c', 'name_pattern');
        }, alias: 'c');

      expect(builder.parseRaw(),
          contains('ON "p"."name" LIKE "c"."name_pattern"'));
    });

    test('onIn renders and binds an IN list', () {
      final builder = PostgresQuery().newBuilder()
        ..selectAll()
        ..fromTable('orders', alias: 'o')
        ..joinTable(JoinType.inner, 'customers', (j) {
          j.onIn('c', 'tier', [1, 2, 3]);
        }, alias: 'c');

      final prepared = builder.parsePrepared();
      expect(prepared.sql, contains('ON "c"."tier" IN (\$1, \$2, \$3)'));
      expect(prepared.params, [1, 2, 3]);
    });

    test('onNotBetween composes with implicit AND', () {
      final builder = PostgresQuery().newBuilder()
        ..selectAll()
        ..fromTable('orders', alias: 'o')
        ..joinTable(JoinType.inner, 'customers', (j) {
          j
              .on('o', 'customer_id', JoinOperator.equals, 'c', 'id')
              .onNotBetween('c', 'tier', 1, 3);
        }, alias: 'c');

      expect(
        builder.parseRaw(),
        contains(
          'ON "o"."customer_id" = "c"."id" AND "c"."tier" NOT BETWEEN 1 AND 3',
        ),
      );
    });
  });
}
