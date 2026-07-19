// ignore_for_file: avoid_print

import 'package:sqleasy/sqleasy.dart';

/// SQLEasy builds the SQL and its bound parameters. It does not connect to anything — you hand the
/// pair to whatever driver you already use (`postgres`, `mysql_client`, `sqflite`, `drift`, …).
void main() {
  final query = PostgresQuery();

  // A SELECT with a filter. `parsePrepared()` returns the SQL and its ordered bound values — the
  // only execution-safe form. Hand both straight to your driver: `conn.execute(sql, params)`.
  final select = query.newBuilder()
    ..selectColumn('u', 'id')
    ..selectColumn('u', 'name', alias: 'userName')
    ..fromTable('users', alias: 'u')
    ..where('u', 'active', WhereOperator.equals, true)
    ..and()
    ..where('u', 'age', WhereOperator.greaterThan, 21);

  final prepared = select.parsePrepared();
  print(prepared.sql);
  // SELECT "u"."id", "u"."name" AS "userName" FROM "public"."users" AS "u"
  //   WHERE "u"."active" = $1 AND "u"."age" > $2;
  print(prepared.params); // [true, 21]

  // The same builder against a different dialect emits dialect-correct SQL — SQLite here uses `?`
  // placeholders and no schema prefix.
  final sqlite = SqliteQuery().newBuilder()
    ..selectAll()
    ..fromTable('users', alias: 'u')
    ..whereInValues('u', 'id', [10, 20, 30]);

  final sqlitePrepared = sqlite.parsePrepared();
  print(sqlitePrepared
      .sql); // SELECT * FROM "users" AS "u" WHERE "u"."id" IN (?, ?, ?);
  print(sqlitePrepared.params); // [10, 20, 30]

  // An INSERT binds its values in column order.
  final insert = query.newBuilder()
    ..insertInto('users')
    ..insertColumns(['name', 'age'])
    ..insertValues(['Ada', 36]);

  print(insert
      .parsePrepared()
      .sql); // INSERT INTO "public"."users" ("name", "age") VALUES ($1, $2);

  // Stored procedures/functions are their own statement family: `callProcedure`/`callFunction`
  // plus `procParam*` for arguments. Postgres emits CALL; MSSQL prepends DECLAREd variables for
  // OUT/INOUT parameters; SQLite has no stored procedures/functions at all and throws.
  final call = query.newBuilder()
    ..callProcedure('archive_user')
    ..procParam(42)
    ..procParamOut('archived_count');

  print(call
      .parsePrepared()
      .sql); // CALL "public"."archive_user"($1, archived_count := $2);
}
