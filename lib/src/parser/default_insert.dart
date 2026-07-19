import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';
import 'default_returning.dart';
import 'default_upsert.dart';
import 'default_merge.dart';
import 'to_sql.dart';

SqlHelper defaultInsert(
  QueryState state,
  Dialect config,
  ParserMode mode, [
  ToSqlOptions? options,
]) {
  final sqlHelper = SqlHelper(mode);

  final insertState = state.insertState;
  if (insertState == null) {
    throw ParserError(ParserArea.insert, 'No insert state provided');
  }

  if ((insertState.raw ?? '').isNotEmpty) {
    sqlHelper.addSqlSnippet(insertState.raw!);
    return sqlHelper;
  }

  if (state.upsertState != null && config.databaseType == DatabaseType.mssql) {
    return emitMssqlMergeInsert(state, config, mode, options);
  }

  if ((insertState.tableName ?? '').isEmpty) {
    throw ParserError(ParserArea.insert, 'INSERT requires a table');
  }

  sqlHelper.addSqlSnippet('INSERT ');

  if (isMysqlInsertIgnore(state.upsertState, config)) {
    sqlHelper.addSqlSnippet('IGNORE ');
  }

  sqlHelper.addSqlSnippet('INTO ');

  if ((insertState.owner ?? '').isNotEmpty) {
    if (config.databaseType == DatabaseType.mysql) {
      throw ParserError(
          ParserArea.insert, 'MySQL does not support table owners');
    }
    sqlHelper.addSqlSnippet(
        quoteIdentifier(insertState.owner, config.identifierDelimiters));
    sqlHelper.addSqlSnippet('.');
  }

  sqlHelper.addSqlSnippet(
      quoteIdentifier(insertState.tableName, config.identifierDelimiters));

  if (insertState.columns.isNotEmpty) {
    sqlHelper.addSqlSnippet(' (');
    for (var i = 0; i < insertState.columns.length; i++) {
      sqlHelper.addSqlSnippet(
        quoteIdentifier(insertState.columns[i], config.identifierDelimiters),
      );

      if (i < insertState.columns.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }
    }
    sqlHelper.addSqlSnippet(')');
  }

  if (state.returningState != null &&
      config.databaseType == DatabaseType.mssql) {
    emitMssqlOutputClause(sqlHelper, config, state.returningState!, 'INSERTED',
        ParserArea.insert);
  }

  final selectSubquery = insertState.selectSubquery;
  if (selectSubquery != null) {
    if (insertState.values.isNotEmpty) {
      throw ParserError(
        ParserArea.insert,
        'INSERT cannot combine a SELECT source with VALUES rows',
      );
    }

    sqlHelper.addSqlSnippet(' ');

    final subHelper = defaultToSql(selectSubquery, config, mode, options);
    sqlHelper.addSqlSnippetWithValues(
        subHelper.getSql(), subHelper.getValues());

    if (state.upsertState != null) {
      emitUpsertClause(
          sqlHelper, config, state.upsertState!, ParserArea.insert);
    }

    return sqlHelper;
  }

  if (insertState.values.isEmpty) {
    throw ParserError(
        ParserArea.insert, 'INSERT requires at least one VALUES row');
  }

  final columnCount = insertState.columns.length;

  sqlHelper.addSqlSnippet(' VALUES ');

  for (var r = 0; r < insertState.values.length; r++) {
    sqlHelper.addSqlSnippet('(');

    final row = insertState.values[r];

    if (columnCount > 0 && row.length != columnCount) {
      throw ParserError(
        ParserArea.insert,
        'INSERT column count ($columnCount) does not match value count (${row.length}) for row ${r + 1}',
      );
    }

    for (var c = 0; c < row.length; c++) {
      sqlHelper.addDynamicValue(row[c]);

      if (c < row.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }
    }

    sqlHelper.addSqlSnippet(')');

    if (r < insertState.values.length - 1) {
      sqlHelper.addSqlSnippet(', ');
    }
  }

  if (state.upsertState != null) {
    emitUpsertClause(sqlHelper, config, state.upsertState!, ParserArea.insert);
  }

  return sqlHelper;
}
