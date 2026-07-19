import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';

/// MySQL spells "skip conflicting rows" as an `INSERT IGNORE` prefix, not a trailing clause —
/// `defaultInsert` calls this to decide whether to emit `IGNORE` right after `INSERT `.
bool isMysqlInsertIgnore(UpsertState? upsertState, Dialect config) =>
    config.databaseType == DatabaseType.mysql &&
    upsertState != null &&
    upsertState.action == UpsertAction.doNothing;

void _emitSetList(
  SqlHelper sqlHelper,
  Dialect config,
  UpsertState upsertState,
  ParserArea area,
) {
  if ((upsertState.updateRaw ?? '').isNotEmpty) {
    sqlHelper.addSqlSnippet(upsertState.updateRaw!);
    return;
  }

  if (upsertState.updateColumns.isEmpty) {
    throw ParserError(
        area, 'Upsert DO UPDATE requires at least one SET column');
  }

  for (var i = 0; i < upsertState.updateColumns.length; i++) {
    final column = upsertState.updateColumns[i];
    sqlHelper.addSqlSnippet(
        quoteIdentifier(column.columnName, config.identifierDelimiters));
    sqlHelper.addSqlSnippet(' = ');
    sqlHelper.addDynamicValue(column.value);

    if (i < upsertState.updateColumns.length - 1) {
      sqlHelper.addSqlSnippet(', ');
    }
  }
}

void _emitConflictColumns(
    SqlHelper sqlHelper, Dialect config, List<String> columns) {
  sqlHelper.addSqlSnippet('(');
  for (var i = 0; i < columns.length; i++) {
    sqlHelper.addSqlSnippet(
        quoteIdentifier(columns[i], config.identifierDelimiters));
    if (i < columns.length - 1) {
      sqlHelper.addSqlSnippet(', ');
    }
  }
  sqlHelper.addSqlSnippet(')');
}

/// Emits the trailing conflict clause after `VALUES (...)`: PG/SQLite `ON CONFLICT ...`, MySQL
/// `ON DUPLICATE KEY UPDATE ...` (its [UpsertAction.doNothing] case is instead an `INSERT IGNORE`
/// prefix — see [isMysqlInsertIgnore] — and emits nothing here). MSSQL upsert is emitted as
/// `MERGE` by [defaultInsert] via [emitMssqlMergeInsert]; this helper throws if called on MSSQL.
void emitUpsertClause(
  SqlHelper sqlHelper,
  Dialect config,
  UpsertState upsertState,
  ParserArea area,
) {
  if (config.databaseType == DatabaseType.mssql) {
    throw ParserError(
      area,
      'MSSQL upsert is handled by MERGE — configure onConflictDoNothing/onConflictDoUpdate on INSERT',
    );
  }

  if (config.databaseType == DatabaseType.mysql) {
    if (upsertState.action == UpsertAction.doNothing) {
      // Handled by the `INSERT IGNORE` prefix — see `isMysqlInsertIgnore`.
      return;
    }

    sqlHelper.addSqlSnippet(' ON DUPLICATE KEY UPDATE ');
    _emitSetList(sqlHelper, config, upsertState, area);
    return;
  }

  // Postgres / SQLite.
  sqlHelper.addSqlSnippet(' ON CONFLICT');

  if (upsertState.conflictColumns.isNotEmpty) {
    sqlHelper.addSqlSnippet(' ');
    _emitConflictColumns(sqlHelper, config, upsertState.conflictColumns);
  }

  if (upsertState.action == UpsertAction.doNothing) {
    sqlHelper.addSqlSnippet(' DO NOTHING');
    return;
  }

  if (upsertState.conflictColumns.isEmpty) {
    throw ParserError(
        area, 'ON CONFLICT DO UPDATE requires at least one conflict column');
  }

  sqlHelper.addSqlSnippet(' DO UPDATE SET ');
  _emitSetList(sqlHelper, config, upsertState, area);
}
