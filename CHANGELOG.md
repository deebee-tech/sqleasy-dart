# Changelog

## 7.0.0

Tracks the TypeScript `@deebeetech/sqleasy` **13.0.0** golden corpus (was pinned to 12.0.0). Mirrors
the "Milestone 5 / Tier 3" feature set exactly: 314 golden cases (was 290).

**New features:**

- **JSON operators** — `selectJsonExtract()`, `whereJsonExtract()`/`whereJsonContains()`, and
  `havingJsonExtract()`/`havingJsonContains()` with dialect-aware `->`/`->>`/`JSON_EXTRACT`/
  `JSON_VALUE`/`json_extract` emission.
- **Full-text search** — `whereMatch()`/`havingMatch()` with `FullTextMode` (Postgres tsvector,
  MySQL MATCH … AGAINST, MSSQL FREETEXT/CONTAINS, SQLite FTS MATCH); `whereMatchRaw()` escape hatch.
- **MSSQL MERGE upsert** — `onConflictDoNothing()`/`onConflictDoUpdate()` on INSERT now emit
  `MERGE INTO … WHEN NOT MATCHED … WHEN MATCHED THEN UPDATE SET …` on MSSQL.
- **LATERAL / APPLY** — `fromLateral()`, `joinCrossApply()`/`joinOuterApply()`/`joinLateral()` with
  dialect mapping (CROSS/OUTER APPLY on MSSQL, LATERAL on Postgres/MySQL).
- **Table-valued functions** — `fromTableFunction()`/`fromTableFunctionWithOwner()`/`fromFunctionRaw()`.
- **GROUPING SETS / CUBE / ROLLUP** — `groupByRollup()`/`groupByCube()`/`groupByGroupingSets()`.
- **FETCH WITH TIES** — `limitWithTies()`/`clearLimitWithTies()` (`FETCH FIRST n ROWS WITH TIES`).
- **Query hints** — `hintUseIndex()`/`hintForceIndex()` (MySQL), `hintMssqlOption()` (MSSQL
  `OPTION (...)`), `hintRaw()`, and `clearHints()`.

New public API: `JsonExtractMode`, `FullTextMode`, `MatchColumnRef`, and `GroupBySetRef`, exported
from `package:sqleasy/sqleasy.dart`.

Nothing to migrate: the addition above is purely additive — no previously emitted SQL changes.

## 6.0.0

Tracks the TypeScript `@deebeetech/sqleasy` **12.0.0** golden corpus (was pinned to 11.0.0). Mirrors
the "Milestone 4 / Tier 2" feature set exactly: 290 golden cases (was 253).

**New features:**

- **Window functions** — `selectWindow()` with a structured `WindowBuilder` for `PARTITION BY`,
  `ORDER BY` (including `NULLS FIRST`/`NULLS LAST`), and optional `ROWS`/`RANGE` frames (`frame()` /
  `frameRaw()`).
- **`DISTINCT ON (...)`** — Postgres-only via `distinctOn()` / `clearDistinctOn()`.
- **`INSERT ... SELECT`** — `insertSelect()` as an alternative row source to `insertValues()`.
- **`ORDER BY NULLS FIRST/LAST`** — optional fourth argument on `orderByColumn()`; native on
  Postgres/SQLite, emulated on MySQL/MSSQL.
- **CTE column lists** — optional `columns` parameter on `cte()` / `cteRecursive()`.
- **Null-safe comparisons** — `WhereOperator.isDistinctFrom` / `isNotDistinctFrom` (MSSQL throws).
- **Richer JOIN ON** — `onIn`/`onNotIn`/`onBetween`/`onNotBetween`, plus `JoinOperator.like` /
  `notLike` on `on`/`onValue`.
- **Join-backed UPDATE/DELETE** — `.join(...)` combined with `.updateTable()` / `.deleteFrom()` on
  MySQL, MSSQL, and Postgres (Postgres translates ON conditions into a `WHERE` predicate).

New public API: `WindowBuilder`, `NullsOrder`, `FrameBoundType`, `FrameUnit`, and `DistinctOnRef`,
exported from `package:sqleasy/sqleasy.dart`.

Nothing to migrate: the addition above is purely additive — no previously emitted SQL changes.

## 5.0.0

Tracks the TypeScript `@deebeetech/sqleasy` **11.0.0** golden corpus (was pinned to 10.0.0). Mirrors
the "Milestone 3 / stored procedures & functions" feature set exactly: 253 golden cases (was 230).

**New features:**

- **First-class stored procedures/functions** — a new statement family, not a raw escape.
  `callProcedure()`/`callProcedureWithOwner()` and `callFunction()`/`callFunctionWithOwner()` start
  a call; `procParam()`/`procParams()`/`procParamNamed()`/`procParamRaw()` add arguments, and
  `procParamOut()`/`procParamInOut()` add procedure-only output parameters; `clearCall()` removes
  it. Postgres emits `CALL name(...)` for procedures and `SELECT name(...)`/`SELECT * FROM
  name(...)` for functions (scalar vs. set-returning, via `CallReturnIntent`); MySQL emits `CALL
  name(...)` for procedures and `SELECT name(...)` for functions (it has no table-valued functions
  — `CallReturnIntent.resultSet` throws there); MSSQL emits `EXEC name ...`, with `DECLARE`d local
  variables prepended for OUT/INOUT parameters. SQLite has no stored procedures or functions at all
  and throws a clear `ParserError`. Named arguments (Postgres `name := value`, MSSQL `@name =
  value`) are supported everywhere except MySQL, which has no named-argument syntax; a positional
  argument after a named one throws, matching the underlying SQL's own ordering rule. A call
  integrates with `parse()`/`parsePrepared()`/`parseRaw()` and `MultiBuilder` like any other
  statement, but refuses to be combined with a CTE or `returning()`.

New public API: `CallKind`, `CallParamDirection`, and `CallReturnIntent` enums, exported from
`package:sqleasy/sqleasy.dart`.

Nothing to migrate: the addition above is purely additive — no previously emitted SQL changes.

## 4.0.0

Tracks the TypeScript `@deebeetech/sqleasy` **10.0.0** golden corpus (was pinned to 9.0.0). Mirrors
the "Milestone 2 / Tier 1" feature set exactly: 230 golden cases (was 189).

**New features:**

- **HAVING now has full parity with WHERE** — `havingBetween`, `havingInValues`/
  `havingInWithBuilder`, `havingNotInValues`/`havingNotInWithBuilder`, `havingNull`/
  `havingNotNull`, `havingExists`/`havingNotExists`, and `havingGroup`, sharing WHERE's
  combinator/spacing rules term for term. `HavingState` gained a `subquery` field to carry the
  nested builder state, mirroring `WhereState`.
- **`WhereOperator.ilike`/`notIlike`** — case-insensitive `LIKE`, usable on both WHERE and HAVING.
  Postgres emits native `ILIKE`/`NOT ILIKE`; MySQL, SQLite, and MSSQL (none of which have `ILIKE`)
  get an equivalent `LOWER(col) LIKE LOWER(?)` rewrite.
- **`whereExists`/`whereNotExists`** — a cleaner EXISTS API without the unused table/column
  parameters `whereExistsWithBuilder`/`whereNotExistsWithBuilder` never use. Both forms render
  identically and the `*WithBuilder` forms remain available for wire parity with the golden corpus.
- **`returning()`/`returningRaw()`/`clearReturning()`** on INSERT/UPDATE/DELETE. Postgres/SQLite
  emit a trailing `RETURNING`; MSSQL emits an inline `OUTPUT INSERTED.…`/`OUTPUT DELETED.…`. MySQL
  has no equivalent and throws a `ParserError` rather than silently dropping the requested columns.
- **Upsert on INSERT** — `onConflictDoNothing()`, `onConflictDoUpdate()`, `onConflictDoUpdateRaw()`,
  `clearUpsert()`. Postgres/SQLite emit `ON CONFLICT (...) DO NOTHING`/`DO UPDATE SET ...`; MySQL
  emits `INSERT IGNORE`/`ON DUPLICATE KEY UPDATE` instead. MSSQL upsert (`MERGE`) is deferred to a
  future release and throws a clear unsupported-feature error.
- **Row locks on SELECT** — `forUpdate()`/`forShare()`, plus `forUpdateNowait`/
  `forUpdateSkipLocked`/`forShareNowait`/`forShareSkipLocked` wait variants, and `clearRowLock()`.
  Postgres/MySQL append a trailing `FOR UPDATE`/`FOR SHARE`; MSSQL has no such clause and gets an
  equivalent `WITH (UPDLOCK, ROWLOCK)`/`WITH (HOLDLOCK, ROWLOCK)` table hint on every base table
  instead. SQLite has no row-level locking and throws a `ParserError`.

New public API: `RowLockMode`, `RowLockWait`, and `UpsertAction` enums, exported from
`package:sqleasy/sqleasy.dart`.

Nothing to migrate: every addition above is purely additive — no previously emitted SQL changes.

## 3.0.0

Tracks the TypeScript `@deebeetech/sqleasy` **9.0.0** golden corpus (was pinned to 8.0.0). Mirrors
the "M1 foundation fixes" milestone exactly.

**Breaking — the emitted SQL and some error paths change:**

- **Consecutive predicates without an explicit combinator now auto-AND.** `.where().where()` and,
  inside a JOIN, `.on().on()` (or a mix with `.onValue()`/`.onRaw()`/`.onGroup()`) used to render the
  two predicates back to back with no operator between them — invalid SQL. They now render `AND`,
  matching how HAVING already behaved.
- **`limit(0)` and negative limits now throw** `ParserError(LimitOffset, 'LIMIT must be a positive
  integer')` instead of silently emitting a limit-less/negative-limit query.
- **An empty `whereGroup(() => {})` now throws** `ParserError(Where, 'WHERE group cannot be empty')`
  instead of rendering as empty parentheses (`WHERE ()`), which no dialect accepts.
- **`clearUpdate` now removes the UPDATE-owned FROM target**, not just the SET assignments — calling
  it leaves `fromStates` empty, the same as never having called `updateTable`.
- **New `clearDelete`** clears the DELETE target and resets the sticky `queryType` back to `select`,
  mirroring `clearUpdate`/`clearInsert`. Calling any `select*` method now also clears a sticky
  DELETE/UPDATE/INSERT `queryType` (it already did for INSERT).
- **`clearHaving` now resets the `and()`/`or()` combinator target back to WHERE.** Previously, calling
  `and()`/`or()` after `clearHaving()` could still append to the (now-cleared) HAVING list instead of
  WHERE.
- **`updateTable`/`deleteFrom` now win over a prior `fromTable`** for the mutation target, tracked
  internally via a new `mutationTargetIndex`, instead of always rendering the first FROM entry.
  `builder.fromTable('users', alias: 'u').updateTable('orders', alias: 'o')` now updates `orders`, not
  `users`.
- **`insertColumns`, `insertValues`, `whereInValues`, and `whereNotInValues` now copy their input
  list** instead of holding a reference to the caller's list — mutating the list you passed in no
  longer mutates the builder's state after the fact.

Nothing to migrate for well-formed queries: every changed case above was either invalid SQL, a
one-token gap the caller almost certainly meant to fill with `and()`, or an ambiguity the caller had
no way to resolve before now.

## 2.0.0

Tracks the TypeScript `@deebeetech/sqleasy` **8.0.0** golden corpus (was pinned to 7.0.0).

**Breaking — the emitted SQL changed.** SQLEasy no longer applies an automatic row cap, on any
dialect, and `RuntimeConfiguration.maxRowsReturned` is removed along with it. A row limit is the
caller's policy: deciding how many rows are too many needs to know what the query is _for_, and only
the caller knows that. A cap the builder adds on its own is a truncation you never wrote and cannot
see in your own code — the query looks complete, the results look complete, and rows are quietly
missing.

It was never coherent either. `selectAll().fromTable('users', alias: 'u')` picked up a `TOP (1000)`
on SQL Server while the identical query on Postgres, MySQL and SQLite returned every row — and then
adding an `offset()` made those three cap at `LIMIT 1000` after all.

What changed, mirroring the TypeScript port exactly (51 golden cases move):

- **`RuntimeConfiguration.maxRowsReturned` is gone.** Setting it is now a compile error. Replace it
  with an explicit `limit()` at your call sites.
- **MSSQL** emits no `TOP (1000)` on an unbounded `SELECT`, and an `offset()` without a `limit()` no
  longer appends `FETCH NEXT 1000 ROWS ONLY` — it is now a bare `OFFSET n ROWS`.
- **Postgres / MySQL / SQLite** no longer emit `LIMIT 1000` for an `offset()` without a `limit()`.

Unchanged, deliberately:

- **`top(n)`** — that IS you asking for a cap. Still SQL-Server-only.
- **The MySQL/SQLite sentinel limits** (`LIMIT 18446744073709551615` and `LIMIT -1`) on an offset
  without a limit. Those are grammar, not a cap: neither dialect can spell a bare `OFFSET`, so each
  needs its own way to say "no upper bound". They bound nothing.

If you relied on the implicit cap, your queries now return every matching row. Add `limit()`.

## 1.0.0

Tracks the TypeScript `@deebeetech/sqleasy` **6.0.1** golden corpus (was pinned to 6.0.0). No
behaviour change: 6.0.1 was a documentation release, so all 189 cases are byte-identical to 6.0.0's
and only the corpus `version` moved. The pin is bumped to keep the two ports on the same tag.

**This is the 1.0.0 release, and it is a versioning change rather than a code change.** The port has
mirrored the TypeScript source since 0.1.0 and conforms to the shared corpus case-for-case, so the
`0.x` prefix was understating it. It also cost a signal: under `0.x`, pub's convention makes the
*minor* the breaking slot, so 0.2.0 spent a minor to say what the rest of the family says with a
major — `@deebeetech/sqleasy` cut a 6.0.0 for the very same change. From here this package versions
by the same rules as the TypeScript one: breaking changes take the major, and a shared corpus bump
that moves emitted SQL is breaking in both languages at once.

Nothing to migrate. If you are on 0.2.0, 1.0.0 emits identical SQL.

**Breaking — the emitted SQL changed.** 6.0.0 fixed three dialect-emission bugs, each of which
produced SQL the real engine rejected. This port mirrors all three, and the shared corpus pins them:
seven golden expectations moved across five cases, and Postgres changed nowhere.

- **MSSQL `limit()` without an `orderByColumn()` now throws.** It rendered
  `OFFSET 0 ROWS FETCH NEXT n ROWS ONLY`, which T-SQL refuses without an ORDER BY (Msg 102). MSSQL
  renders every limit as OFFSET/FETCH pagination, so pagination without an order to page against is
  a caller error. It deliberately does not fall back to `TOP`: `top(n)` is the explicit,
  SQL-Server-only row cap, and `limit()` is pagination.
- **MSSQL no longer emits `TOP` alongside an `OFFSET`.** T-SQL rejects the combination (Msg 10741),
  which made every `offset()` on an unfiltered query invalid. The automatic `maxRowsReturned` cap now
  rides in the FETCH — `... OFFSET 5 ROWS FETCH NEXT 1000 ROWS ONLY`. With no offset, the safety net
  still emits `TOP`.
- **MySQL and SQLite `offset()` without a `limit()` no longer emit a bare `OFFSET`.** Neither grammar
  has a standalone OFFSET (MySQL ERROR 1064, SQLite `near "OFFSET"`). Each now emits its own
  "no upper bound" idiom first: `LIMIT 18446744073709551615` and `LIMIT -1`. Postgres accepts a bare
  OFFSET and is untouched.

Conformance passes on the Dart VM and under dart2js.

## 0.2.0

**Breaking — pagination emission.** Tracks the TypeScript package’s pagination hardening that later
landed as majors on both sides. Historical note for readers of early `0.x` tags:

- MSSQL `limit()` without `orderBy` throws (OFFSET/FETCH requires ORDER BY).
- MSSQL no longer emits `TOP` alongside `OFFSET`.
- MySQL/SQLite `offset()` without `limit()` emit dialect “unbounded” LIMIT sentinels instead of a
  bare `OFFSET`.

See **1.0.0** for the corpus pin that froze those expectations for pub consumers. Prefer jumping
straight to the current major rather than installing `0.2.0`.

## 0.1.3

Tracks the TypeScript `@deebeetech/sqleasy` **4.0.1** golden corpus (was pinned to 3.0.0).

**No behavior change.** The 4.0.0/4.0.1 releases were refactors and API cleanup — the corpus cases
are byte-identical across v3.0.0 → v4.0.1, so the emitted SQL is unchanged, and conformance still
passes on the Dart VM and under dart2js. The API cleanups were already reflected here: the removed
`Datatype` enum and `JoinOnBuilder.newJoinOnBuilder` were never ported, and
`MultiBuilder.preparedStatements()` was already present.

## 0.1.2

- Docs: rework the README to match the SQLEasy house style — logo lockup, badges, and a full example
  tour (SELECT / WHERE / JOIN / INSERT / UPDATE / DELETE / GROUP BY / CTE / UNION, plus multi-builder
  batches) written in idiomatic Dart. No code changes.

## 0.1.1

- Docs: correct the README, which still described the package as a work in progress after the port
  was already complete. No code changes.

## 0.1.0

First release. A complete Dart port of [`@deebeetech/sqleasy`](https://github.com/deebee-tech/sqleasy),
held to that implementation byte-for-byte by a shared golden corpus.

- **Pure Dart** — no Flutter SDK dependency, no `dart:io`, no `dart:html`. Runs on Flutter mobile,
  desktop and web, and on plain Dart servers.
- **Four dialects** — Postgres, MySQL, SQL Server, and SQLite, each with correct identifier quoting,
  placeholder style, default schema, and transaction wrappers.
- **Fluent builder** — SELECT / INSERT / UPDATE / DELETE, plus joins, groups, subqueries, CTEs,
  unions, and batched transactions. Every mutator returns the builder, so chaining and cascades both
  work. `parsePrepared()` hands you the SQL string and its ordered bound parameters.
- **Idiomatic API** — named/optional parameters instead of empty-string sentinels, Dart 3 records for
  batch methods, `Object?` value slots.
- **Verified against the corpus** — all 189 golden cases replayed across all four dialects, passing
  on the Dart VM *and* under dart2js. That cross-platform equality is what guarantees the package
  emits identical SQL on Flutter mobile and Flutter web; see `goldens/README.md`.
