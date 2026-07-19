/// A dialect-aware SQL builder for Postgres, MySQL, SQL Server and SQLite.
///
/// Composes dialect-correct SELECT / INSERT / UPDATE / DELETE with a fluent API and hands you the
/// SQL string and its bound parameters. It is **not** a driver and **not** an ORM: you bring your
/// own connection (`postgres`, `mysql_client`, `sqflite`, `drift`, …) and execute what it generates.
///
/// This is a pure Dart package — no Flutter SDK dependency, no `dart:io`, no `dart:html` — so it
/// runs on Flutter mobile, desktop and web, and on plain Dart servers.
///
/// It is the Dart port of [`@deebeetech/sqleasy`](https://github.com/deebee-tech/sqleasy), and is
/// held to that implementation byte-for-byte by a shared golden corpus. See `goldens/README.md`.
library;

export 'src/builder/join_on_builder.dart' show JoinOnBuilder;
export 'src/builder/multi_builder.dart' show MultiBuilder;
export 'src/builder/query_builder.dart'
    show
        QueryBuilder,
        ColumnRef,
        TableRef,
        JoinRef,
        OrderByRef,
        DistinctOnRef,
        GroupByRef,
        GroupBySetRef,
        MatchColumnRef,
        SetRef;
export 'src/builder/window_builder.dart' show WindowBuilder;
export 'src/configuration.dart'
    show ConfigurationDelimiters, Dialect, RuntimeConfiguration;
export 'src/dialects.dart'
    show MssqlQuery, MysqlQuery, PostgresQuery, SqliteQuery;
export 'src/enums.dart'
    show
        WhereOperator,
        JoinType,
        JoinOperator,
        OrderByDirection,
        NullsOrder,
        FrameBoundType,
        FrameUnit,
        MultiBuilderTransactionState,
        DatabaseType,
        RowLockMode,
        RowLockWait,
        UpsertAction,
        JsonExtractMode,
        FullTextMode,
        CallKind,
        CallParamDirection,
        CallReturnIntent;
export 'src/errors/parser_error.dart' show ParserArea, ParserError;
export 'src/expression/scalar.dart' show Fn;
export 'src/parser/to_sql.dart' show PreparedSql;
export 'src/state.dart' show QueryState, JoinOnState;
