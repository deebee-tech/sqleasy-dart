import 'package:sqleasy/sqleasy.dart';
import 'package:test/test.dart';

void main() {
  group('window functions', () {
    test('renders PARTITION BY and ORDER BY', () {
      final builder = PostgresQuery().newBuilder()
        ..selectColumn('o', 'id')
        ..selectWindow(
          'ROW_NUMBER()',
          (w) => w
              .partitionByColumn('o', 'customer_id')
              .orderByColumn('o', 'created_at'),
          alias: 'rn',
        )
        ..fromTable('orders', alias: 'o');

      expect(
        builder.parseRaw(),
        contains(
          'ROW_NUMBER() OVER (PARTITION BY "o"."customer_id" ORDER BY "o"."created_at") AS "rn"',
        ),
      );
    });

    test('omits the alias when none is given', () {
      final builder = PostgresQuery().newBuilder()
        ..selectWindow('ROW_NUMBER()', (w) => w)
        ..fromTable('orders', alias: 'o');

      expect(builder.parseRaw(),
          'SELECT ROW_NUMBER() OVER () FROM "public"."orders" AS "o";');
    });

    test('renders a ROWS BETWEEN frame with numeric offsets', () {
      final builder = MysqlQuery().newBuilder()
        ..selectColumn('o', 'id')
        ..selectWindow(
          'AVG(`o`.`total`)',
          (w) => w.orderByColumn('o', 'created_at').frame(
                FrameUnit.rows,
                FrameBoundType.preceding,
                1,
                FrameBoundType.following,
                1,
              ),
          alias: 'moving_avg',
        )
        ..fromTable('orders', alias: 'o');

      expect(builder.parseRaw(),
          contains('ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING'));
    });

    test('renders single-bound frame shorthand', () {
      final builder = PostgresQuery().newBuilder()
        ..selectWindow(
          'SUM("o"."total")',
          (w) => w.frame(FrameUnit.rows, FrameBoundType.unboundedPreceding),
          alias: 's',
        )
        ..fromTable('orders', alias: 'o');

      expect(builder.parseRaw(), contains('ROWS UNBOUNDED PRECEDING'));
      expect(builder.parseRaw(), isNot(contains('BETWEEN')));
    });
  });
}
