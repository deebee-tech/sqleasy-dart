import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../sql_helper.dart';
import '../state.dart';

/// Trailing `FOR UPDATE`/`FOR SHARE` clause for Postgres/MySQL, appended after the whole SELECT
/// (including ORDER BY/LIMIT). SQLite has no row-level locking at all and refuses it. MSSQL emits
/// nothing here — its locking is a `WITH (...)` table hint on each FROM table; see
/// [mssqlRowLockHint].
void emitTrailingRowLockClause(
  SqlHelper sqlHelper,
  Dialect config,
  RowLockState rowLock,
) {
  if (config.databaseType == DatabaseType.sqlite) {
    throw ParserError(
      ParserArea.general,
      'SQLite does not support row locking (FOR UPDATE/FOR SHARE)',
    );
  }

  if (config.databaseType == DatabaseType.mssql) {
    return;
  }

  sqlHelper.addSqlSnippet(' ');
  sqlHelper.addSqlSnippet(
      rowLock.mode == RowLockMode.forUpdate ? 'FOR UPDATE' : 'FOR SHARE');

  if (rowLock.wait == RowLockWait.nowait) {
    sqlHelper.addSqlSnippet(' NOWAIT');
  } else if (rowLock.wait == RowLockWait.skipLocked) {
    sqlHelper.addSqlSnippet(' SKIP LOCKED');
  }
}

/// MSSQL has no `FOR UPDATE`/`FOR SHARE` clause — the nearest equivalent is a `WITH (...)`
/// locking hint on the table reference itself. `UPDLOCK`/`HOLDLOCK` approximate `FOR
/// UPDATE`/`FOR SHARE`; `ROWLOCK` asks for row- (not page/table-) granularity; `NOWAIT`/
/// `READPAST` approximate `NOWAIT`/`SKIP LOCKED`.
String mssqlRowLockHint(RowLockState rowLock) {
  final strength = rowLock.mode == RowLockMode.forUpdate
      ? 'UPDLOCK, ROWLOCK'
      : 'HOLDLOCK, ROWLOCK';

  if (rowLock.wait == RowLockWait.nowait) {
    return ' WITH ($strength, NOWAIT)';
  }

  if (rowLock.wait == RowLockWait.skipLocked) {
    return ' WITH ($strength, READPAST)';
  }

  return ' WITH ($strength)';
}
