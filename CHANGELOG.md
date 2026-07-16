# Changelog

## 2.0.0

Tracks the TypeScript `@deebeetech/sqleasy` **7.0.0** golden corpus (was pinned to 6.0.1).

**Breaking — the emitted SQL changed.** SQLEasy no longer applies an automatic row cap, on any
dialect, and `RuntimeConfiguration.maxRowsReturned` is removed along with it. A row limit is the
caller's policy: deciding how many rows are too many needs to know what the query is _for_, and only
the caller knows that. A cap the builder adds on its own is a truncation you never wrote and cannot
see in your own code — the query looks complete, the results look complete, and rows are quietly
missing.

It was never coherent either. `selectAll().fromTable('users', 'u')` picked up a `TOP (1000)` on SQL
Server while the identical query on Postgres, MySQL and SQLite returned every row — and then adding
an `offset()` made those three cap at `LIMIT 1000` after all.

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
