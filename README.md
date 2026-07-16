<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/deebee-tech/sqleasy-dart/main/assets/sqleasy-lockup-dark.svg">
    <img alt="SQLEasy" src="https://raw.githubusercontent.com/deebee-tech/sqleasy-dart/main/assets/sqleasy-lockup-light.png" width="440">
  </picture>
</p>

<p align="center"><strong>A dialect-aware SQL builder for Postgres, MySQL, SQL Server &amp; SQLite — pure Dart, Flutter-ready, bring your own connection.</strong></p>

<p align="center">
  <a href="https://pub.dev/packages/sqleasy"><img alt="pub" src="https://img.shields.io/pub/v/sqleasy?logo=dart&color=0175C2"></a>
  <a href="https://pub.dev/packages/sqleasy/score"><img alt="pub points" src="https://img.shields.io/pub/points/sqleasy?color=0175C2"></a>
  <a href="./LICENSE"><img alt="license" src="https://img.shields.io/badge/license-MIT-blue"></a>
</p>

SQLEasy is a lightweight, **zero-dependency** SQL query _builder_. It composes dialect-correct
SELECT / INSERT / UPDATE / DELETE — plus CTEs, unions, and batched transactions — with a fluent API,
and hands you the SQL string and its bound parameters.

It is **not** a driver or an ORM. You bring your own connection (`postgres`, `mysql_client`,
`sqflite`, `drift`, …) and run what SQLEasy generates. That focus is the point: correct SQL for four
dialects — identifier quoting, placeholder style, default schemas, and transaction wrappers — and
nothing you have to wire around.

**Pure Dart.** No Flutter SDK dependency, no `dart:io`, no `dart:html` — it runs on Flutter mobile,
desktop **and web**, and on plain Dart servers. It is the Dart port of
[`@deebeetech/sqleasy`](https://github.com/deebee-tech/sqleasy), held to that implementation
byte-for-byte by a [shared golden corpus](#correctness-across-flutter-web-and-mobile).

Part of the [DeeBee](https://github.com/deebee-tech) ecosystem.

## Installation

```bash
dart pub add sqleasy
# or, in a Flutter app:
flutter pub add sqleasy
```

## Quick Start

```dart
import 'package:sqleasy/sqleasy.dart';

final builder = PostgresQuery().newBuilder()
  ..selectColumn('u', 'id')
  ..selectColumn('u', 'name', alias: 'userName')
  ..fromTable('users', alias: 'u')
  ..where('u', 'active', WhereOperator.equals, true);

final prepared = builder.parsePrepared();
// prepared.sql:    SELECT "u"."id", "u"."name" AS "userName" FROM "public"."users" AS "u" WHERE "u"."active" = $1;
// prepared.params: [true]   ← hand straight to your driver: conn.execute(prepared.sql, prepared.params)
```

Every mutator returns the builder, so cascades (`..`) and plain chaining both read cleanly. "No
alias" and "no owner" are optional named parameters — there are no empty-string sentinels.

## Database Support

Each dialect has its own entry point that handles identifier quoting, placeholder syntax, default
schemas, and transaction delimiters automatically.

```dart
final mssql = MssqlQuery(); // [dbo].[table], sp_executesql (values inlined, params empty), BEGIN/COMMIT TRANSACTION
final mysql = MysqlQuery(); // `table`, ? placeholders, START TRANSACTION/COMMIT
final postgres = PostgresQuery(); // "public"."table", $1 placeholders, BEGIN/COMMIT
final sqlite = SqliteQuery(); // "table", ? placeholders, BEGIN/COMMIT
```

## Query Examples

### SELECT

```dart
final builder = PostgresQuery().newBuilder();

// Select all columns
builder..selectAll()..fromTable('users', alias: 'u');
// SELECT * FROM "public"."users" AS "u";

// Specific columns (alias is an optional named parameter)
builder.clearAll();
builder
  ..selectColumn('u', 'id')
  ..selectColumn('u', 'name', alias: 'userName')
  ..fromTable('users', alias: 'u');
// SELECT "u"."id", "u"."name" AS "userName" FROM "public"."users" AS "u";

// DISTINCT
builder.clearAll();
builder..distinct()..selectColumn('u', 'name')..fromTable('users', alias: 'u');
// SELECT DISTINCT "u"."name" FROM "public"."users" AS "u";

// Raw expression
builder.clearAll();
builder..selectRaw('COUNT(*) AS total')..fromTable('users', alias: 'u');
// SELECT COUNT(*) AS total FROM "public"."users" AS "u";

// Scalar sub-query in SELECT
builder.clearAll();
builder
  ..selectAll()
  ..selectWithBuilder('orderCount', (sb) => sb
    ..selectRaw('COUNT(*)')
    ..fromTable('orders', alias: 'o'))
  ..fromTable('users', alias: 'u');
// SELECT *, (SELECT COUNT(*) FROM "public"."orders" AS "o") AS "orderCount" FROM "public"."users" AS "u";
```

### WHERE

```dart
final builder = PostgresQuery().newBuilder();

// Comparison operators
builder
  ..selectAll()
  ..fromTable('users', alias: 'u')
  ..where('u', 'age', WhereOperator.greaterThanOrEquals, 18);

// AND / OR
builder.clearAll();
builder
  ..selectAll()
  ..fromTable('users', alias: 'u')
  ..where('u', 'active', WhereOperator.equals, true)
  ..and()
  ..where('u', 'age', WhereOperator.greaterThan, 21);
// ... WHERE "u"."active" = $1 AND "u"."age" > $2;   params: [true, 21]

// BETWEEN
builder.clearAll();
builder..selectAll()..fromTable('users', alias: 'u')..whereBetween('u', 'age', 18, 65);

// IS NULL / IS NOT NULL
builder.clearAll();
builder..selectAll()..fromTable('users', alias: 'u')..whereNotNull('u', 'email');

// IN (values)
builder.clearAll();
builder..selectAll()..fromTable('users', alias: 'u')..whereInValues('u', 'role', ['admin', 'moderator']);
// ... WHERE "u"."role" IN ($1, $2);   params: [admin, moderator]

// IN (sub-query)
builder.clearAll();
builder
  ..selectAll()
  ..fromTable('users', alias: 'u')
  ..whereInWithBuilder('u', 'id', (sb) => sb
    ..selectColumn('o', 'user_id')
    ..fromTable('orders', alias: 'o'));

// Grouped conditions
builder.clearAll();
builder
  ..selectAll()
  ..fromTable('users', alias: 'u')
  ..where('u', 'active', WhereOperator.equals, true)
  ..and()
  ..whereGroup((gb) => gb
    ..where('u', 'role', WhereOperator.equals, 'admin')
    ..or()
    ..where('u', 'role', WhereOperator.equals, 'moderator'));
// ... WHERE "u"."active" = $1 AND ("u"."role" = $2 OR "u"."role" = $3);
```

### JOIN

`joinTable` takes the ON-condition callback as its third argument; the table alias is an optional
named parameter.

```dart
final builder = PostgresQuery().newBuilder();

builder
  ..selectAll()
  ..fromTable('users', alias: 'u')
  ..joinTable(JoinType.inner, 'orders', (jb) {
    jb.on('u', 'id', JoinOperator.equals, 'o', 'user_id');
  }, alias: 'o');
// SELECT * FROM "public"."users" AS "u"
//   INNER JOIN "public"."orders" AS "o" ON "u"."id" = "o"."user_id";

// Multiple ON conditions
builder.clearAll();
builder
  ..selectAll()
  ..fromTable('users', alias: 'u')
  ..joinTable(JoinType.inner, 'orders', (jb) {
    jb
      ..on('u', 'id', JoinOperator.equals, 'o', 'user_id')
      ..and()
      ..on('u', 'tenant_id', JoinOperator.equals, 'o', 'tenant_id');
  }, alias: 'o');

// Join to a sub-query
builder.clearAll();
builder
  ..selectAll()
  ..fromTable('users', alias: 'u')
  ..joinWithBuilder(
    JoinType.inner,
    'recent_orders',
    (sb) => sb
      ..selectAll()
      ..fromTable('orders', alias: 'o')
      ..where('o', 'created_at', WhereOperator.greaterThan, '2024-01-01'),
    (jb) => jb.on('u', 'id', JoinOperator.equals, 'recent_orders', 'user_id'),
  );
```

### INSERT

```dart
final builder = PostgresQuery().newBuilder()
  ..insertInto('users')
  ..insertColumns(['name', 'email', 'age'])
  ..insertValues(['John', 'john@example.com', 30]);
// INSERT INTO "public"."users" ("name", "email", "age") VALUES ($1, $2, $3);
// params: [John, john@example.com, 30]

// Multi-row insert: call insertValues once per row.
```

### UPDATE

```dart
final builder = PostgresQuery().newBuilder()
  ..updateTable('users', alias: 'u')
  ..set('name', 'John Updated')
  ..set('age', 31)
  ..where('u', 'id', WhereOperator.equals, 1);
// UPDATE "public"."users" AS "u" SET "name" = $1, "age" = $2 WHERE "u"."id" = $3;

// Raw SET expression: ..setRaw('"login_count" = "login_count" + 1')
```

### DELETE

```dart
final builder = PostgresQuery().newBuilder()
  ..deleteFrom('users', alias: 'u')
  ..where('u', 'id', WhereOperator.equals, 1);
// DELETE FROM "public"."users" AS "u" WHERE "u"."id" = $1;
```

### ORDER BY / LIMIT / OFFSET

```dart
final builder = PostgresQuery().newBuilder()
  ..selectAll()
  ..fromTable('users', alias: 'u')
  ..orderByColumn('u', 'name', OrderByDirection.ascending)
  ..limit(10)
  ..offset(20);
```

`limit()` is **pagination**: on MSSQL it renders as `OFFSET … ROWS FETCH NEXT … ROWS ONLY`, which
T-SQL accepts only alongside an `ORDER BY` — so paginating without one throws rather than emitting
SQL the server would reject. `top(n)` is the separate, SQL-Server-only **manual row cap**, and the
tool to reach for when you want `TOP (n)` and no ordering. The two are not interchangeable, and
`limit()` never silently becomes a `TOP`.

### GROUP BY / HAVING

```dart
final builder = PostgresQuery().newBuilder()
  ..selectColumn('u', 'role')
  ..selectRaw('COUNT(*) AS cnt')
  ..fromTable('users', alias: 'u')
  ..groupByColumn('u', 'role')
  ..having('u', 'role', WhereOperator.notEquals, 'guest');
```

### Common Table Expressions (CTEs)

```dart
final builder = PostgresQuery().newBuilder()
  ..cte('active_users', (cb) => cb
    ..selectAll()
    ..fromTable('users', alias: 'u')
    ..where('u', 'active', WhereOperator.equals, true))
  ..selectAll()
  ..fromRaw('"active_users" AS "au"');
// WITH "active_users" AS (SELECT * FROM "public"."users" AS "u" WHERE "u"."active" = $1)
//   SELECT * FROM "active_users" AS "au";

// Recursive: ..cteRecursive('hierarchy', (cb) { ... })
```

### UNION / INTERSECT / EXCEPT

```dart
final builder = PostgresQuery().newBuilder()
  ..selectColumn('u', 'name')
  ..fromTable('users', alias: 'u')
  ..union((ub) => ub
    ..selectColumn('c', 'name')
    ..fromTable('customers', alias: 'c'));

// Also available: unionAll(), intersect(), except()
```

## Multi-Builder (Batched Statements)

Compose multiple statements into a single SQL string, optionally wrapped in a transaction.

```dart
final multi = PostgresQuery().newMultiBuilder();

multi.addBuilder('insert_user')
  ..insertInto('users')
  ..insertColumns(['name', 'email'])
  ..insertValues(['John', 'john@example.com']);

multi.addBuilder('update_count')
  ..updateTable('stats', alias: 's')
  ..set('user_count', 100)
  ..where('s', 'id', WhereOperator.equals, 1);

print(multi.parseRaw());
// BEGIN; INSERT INTO "public"."users" ("name", "email") VALUES (John, john@example.com);UPDATE "public"."stats" AS "s" SET "user_count" = 100 WHERE "s"."id" = 1;COMMIT;

// Named builders can be removed or reordered before rendering.
multi.reorderBuilders(['update_count', 'insert_user']);

// Disable transaction wrapping (statements emitted back-to-back, no BEGIN/COMMIT).
multi.setTransactionState(MultiBuilderTransactionState.transactionOff);
```

### Executing a batch

`parse()` / `parseRaw()` render the batch as **one string for display or logging** — they carry no
bound parameters, and placeholder numbering restarts per statement, so on Postgres, MySQL, and SQLite
that single string is **not** an execution-safe prepared call.

To **run** a batch, use `preparedStatements()` — the executable unit — and execute each in order
inside a transaction on your own connection:

```dart
await conn.execute('BEGIN');
try {
  for (final stmt in multi.preparedStatements()) {
    await conn.execute(stmt.sql, stmt.params);
  }
  await conn.execute('COMMIT');
} catch (_) {
  await conn.execute('ROLLBACK');
  rethrow;
}
```

## Prepared Statements vs Raw SQL

Every builder offers three renderings:

- **`parsePrepared()`** — the execution-safe one. Returns a `PreparedSql` (`.sql`, `.params`), whose
  shape is dialect-specific:
  - **Postgres** — `$1`/`$2`/… placeholders + the ordered `params`.
  - **MySQL / SQLite** — positional `?` placeholders + the ordered `params`.
  - **MSSQL** — a self-contained `exec sp_executesql …` batch with the values inlined as escaped
    arguments, so `params` is **empty**. It is still injection-safe: values are escaped and passed as
    sp_executesql arguments, never concatenated into the statement text.
- **`parse()`** — the SQL string with placeholders, without the values (handy for logging the shape).
- **`parseRaw()`** — values inlined into the SQL. **Debug / display only** — not escaped, not
  execution-safe. Never run `parseRaw()` output against a database.

```dart
final builder = PostgresQuery().newBuilder()
  ..selectAll()
  ..fromTable('users', alias: 'u')
  ..where('u', 'id', WhereOperator.equals, 42);

builder.parsePrepared(); // .sql: '... WHERE "u"."id" = $1;'  .params: [42]
builder.parse();         // SELECT * FROM "public"."users" AS "u" WHERE "u"."id" = $1;
builder.parseRaw();      // SELECT * FROM "public"."users" AS "u" WHERE "u"."id" = 42;   (debug only)
```

## Configuration

Pass a `RuntimeConfiguration` to carry host-defined settings alongside a query:

```dart
final rc = RuntimeConfiguration()..customConfiguration = {'timeout': 30};

final query = PostgresQuery(rc);
```

### SQLEasy never caps your rows

There is no automatic row limit. `selectAll().fromTable('users', 'u')` compiles to exactly that, on
every dialect, and will happily return every row in the table. If you want a bound, say so —
`limit()` to paginate, or `top(n)` on SQL Server for an unordered cap.

This is deliberate. A cap the builder applies on its own is a truncation the caller never wrote and
cannot see in their own code: the query looks complete, the results look complete, and the rows are
simply missing. Deciding how many rows are too many needs to know what the query is _for_, which is
something only the caller knows.

> Removed in **2.0.0** (mirroring TypeScript 7.0.0), along with
> `RuntimeConfiguration.maxRowsReturned`, which drove it. Before that a default cap of 1000 applied —
> but only ever coherently on SQL Server, where an unbounded `SELECT` collected a `TOP (1000)` while
> the identical query on Postgres returned everything. If you set `maxRowsReturned`, replace it with
> an explicit `limit()` at your call sites.

## Correctness across Flutter web and mobile

Every query this package produces is verified against a shared golden corpus — 189 cases across all
four dialects — that both this package and the TypeScript original must reproduce **byte-for-byte**.
That is not decoration; it defends against a real, silent trap.

JavaScript has one number type. Dart has `int` and `double` — **and Dart does not agree with itself
across platforms:**

| expression | Dart VM (Flutter mobile/desktop) | dart2js (Flutter **web**) |
|---|---|---|
| `5.0 is int` | `false` | **`true`** |
| `(5.0).toString()` | `"5.0"` | **`"5"`** |
| `double.infinity is int` | `false` | **`true`** |

So a naive builder emits **different SQL on Flutter web than on Flutter mobile**, from the same
source, with nothing thrown and nothing logged: `5.0` binds as `@p0 tinyint` / `= 5` on the web and
`@p0 float` / `= 5.0` on mobile. Every value here passes through one platform-independent rendering
layer, and the test suite runs on **both** platforms — `dart test` (the VM) and `dart test -p chrome`
(dart2js) — so the two can never diverge. See [`goldens/README.md`](goldens/README.md).

## Development

```bash
dart pub get
dart analyze
dart test               # the Dart VM — Flutter mobile and desktop
dart test -p chrome     # dart2js — Flutter web. Not redundant, not optional.

dart run tool/fetch_goldens.dart    # pull the pinned corpus from the TypeScript repo's tag
dart run tool/embed_goldens.dart    # re-embed it for the dart2js test run
```

## License

MIT © DeeBee Tech
