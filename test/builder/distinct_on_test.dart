import 'package:sqleasy/sqleasy.dart';
import 'package:test/test.dart';

void main() {
  group('DISTINCT ON', () {
    test('renders a single column', () {
      final builder = PostgresQuery().newBuilder()
        ..distinctOn([(table: 'o', column: 'customer_id')])
        ..selectAll()
        ..fromTable('orders', alias: 'o');

      expect(
        builder.parseRaw(),
        'SELECT DISTINCT ON ("o"."customer_id") * FROM "public"."orders" AS "o";',
      );
    });

    test('throws on MySQL', () {
      final builder = MysqlQuery().newBuilder()
        ..distinctOn([(table: 'o', column: 'customer_id')])
        ..selectAll()
        ..fromTable('orders', alias: 'o');

      expect(() => builder.parseRaw(), throwsA(isA<ParserError>()));
    });
  });
}
