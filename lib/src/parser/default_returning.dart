import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';

void _emitColumnList(
  SqlHelper sqlHelper,
  Dialect config,
  List<String> columns,
  String? prefix,
) {
  for (var i = 0; i < columns.length; i++) {
    if (prefix != null) {
      sqlHelper.addSqlSnippet('$prefix.');
    }
    sqlHelper.addSqlSnippet(
        quoteIdentifier(columns[i], config.identifierDelimiters));

    if (i < columns.length - 1) {
      sqlHelper.addSqlSnippet(', ');
    }
  }
}

void _emitColumnsOrRaw(
  SqlHelper sqlHelper,
  Dialect config,
  ReturningState returningState,
  String? prefix,
  ParserArea area,
) {
  if ((returningState.raw ?? '').isNotEmpty) {
    sqlHelper.addSqlSnippet(returningState.raw!);
    return;
  }

  if (returningState.columns.isEmpty) {
    throw ParserError(area, 'RETURNING/OUTPUT requires at least one column');
  }

  _emitColumnList(sqlHelper, config, returningState.columns, prefix);
}

/// MSSQL's `OUTPUT` clause. Placed inline by the caller — before `VALUES` for INSERT, before
/// `FROM`/`WHERE` for UPDATE, before `WHERE` for DELETE — because, unlike PG/SQLite's trailing
/// `RETURNING`, T-SQL requires `OUTPUT` in the middle of the statement.
void emitMssqlOutputClause(
  SqlHelper sqlHelper,
  Dialect config,
  ReturningState returningState,
  String prefix,
  ParserArea area,
) {
  sqlHelper.addSqlSnippet(' OUTPUT ');
  _emitColumnsOrRaw(sqlHelper, config, returningState, prefix, area);
}

/// PG/SQLite's trailing `RETURNING` clause, appended after the whole INSERT/UPDATE/DELETE
/// statement (including its WHERE). MySQL has no equivalent and refuses it here with a clear
/// error rather than silently dropping the columns the caller asked for.
void emitTrailingReturningClause(
  SqlHelper sqlHelper,
  Dialect config,
  ReturningState returningState,
  ParserArea area,
) {
  if (config.databaseType == DatabaseType.mysql) {
    throw ParserError(area, 'MySQL does not support RETURNING');
  }

  sqlHelper.addSqlSnippet(' RETURNING ');
  _emitColumnsOrRaw(sqlHelper, config, returningState, null, area);
}
