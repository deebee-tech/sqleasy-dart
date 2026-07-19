import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';
import 'to_sql.dart';

void _emitMergeSetList(
  SqlHelper sqlHelper,
  Dialect config,
  UpsertState upsertState,
  String sourceAlias,
  List<String> columns,
) {
  if ((upsertState.updateRaw ?? '').isNotEmpty) {
    sqlHelper.addSqlSnippet(upsertState.updateRaw!);
    return;
  }

  final updates = upsertState.updateColumns.isNotEmpty
      ? upsertState.updateColumns
      : [
          for (final column in columns) UpsertSetState(column, null),
        ];

  if (updates.isEmpty) {
    throw ParserError(
        ParserArea.insert, 'MERGE DO UPDATE requires at least one SET column');
  }

  for (var i = 0; i < updates.length; i++) {
    final update = updates[i];
    sqlHelper.addSqlSnippet(
        quoteIdentifier(update.columnName, config.identifierDelimiters));
    sqlHelper.addSqlSnippet(' = ');
    sqlHelper.addSqlSnippet(
        quoteIdentifier(sourceAlias, config.identifierDelimiters));
    sqlHelper.addSqlSnippet('.');
    sqlHelper.addSqlSnippet(
        quoteIdentifier(update.columnName, config.identifierDelimiters));

    if (i < updates.length - 1) {
      sqlHelper.addSqlSnippet(', ');
    }
  }
}

/// Emits a T-SQL `MERGE` upsert instead of `INSERT ... VALUES` when [QueryState.upsertState]
/// is set on MSSQL.
SqlHelper emitMssqlMergeInsert(
  QueryState state,
  Dialect config,
  ParserMode mode, [
  ToSqlOptions? options,
]) {
  if (config.databaseType != DatabaseType.mssql) {
    throw ParserError(ParserArea.insert, 'MERGE upsert emission is MSSQL-only');
  }

  final insertState = state.insertState;
  final upsertState = state.upsertState;
  if (insertState == null || upsertState == null) {
    throw ParserError(ParserArea.insert, 'MERGE requires INSERT upsert state');
  }

  final sqlHelper = SqlHelper(mode);

  if ((insertState.tableName ?? '').isEmpty) {
    throw ParserError(ParserArea.insert, 'MERGE requires a target table');
  }

  const targetAlias = 'target';
  const sourceAlias = 'source';
  final columns = insertState.columns;

  if (columns.isEmpty) {
    throw ParserError(
        ParserArea.insert, 'MERGE requires an explicit INSERT column list');
  }

  if (upsertState.conflictColumns.isEmpty) {
    throw ParserError(
        ParserArea.insert, 'MERGE requires at least one conflict column');
  }

  sqlHelper.addSqlSnippet('MERGE INTO ');

  if ((insertState.owner ?? '').isNotEmpty) {
    sqlHelper.addSqlSnippet(
        quoteIdentifier(insertState.owner, config.identifierDelimiters));
    sqlHelper.addSqlSnippet('.');
  }

  sqlHelper.addSqlSnippet(
      quoteIdentifier(insertState.tableName, config.identifierDelimiters));
  sqlHelper.addSqlSnippet(' AS ');
  sqlHelper
      .addSqlSnippet(quoteIdentifier(targetAlias, config.identifierDelimiters));
  sqlHelper.addSqlSnippet(' USING (');

  final selectSubquery = insertState.selectSubquery;
  if (selectSubquery != null) {
    final subHelper = defaultToSql(selectSubquery, config, mode, options);
    sqlHelper.addSqlSnippetWithValues(
        subHelper.getSql(), subHelper.getValues());
  } else {
    if (insertState.values.isEmpty) {
      throw ParserError(ParserArea.insert,
          'MERGE requires VALUES or INSERT SELECT source rows');
    }

    if (insertState.values.length != 1) {
      throw ParserError(
        ParserArea.insert,
        'MERGE currently supports a single VALUES row — use insertSelect for multi-row sources',
      );
    }

    sqlHelper.addSqlSnippet('VALUES (');
    final row = insertState.values.first;
    if (row.length != columns.length) {
      throw ParserError(
        ParserArea.insert,
        'MERGE column count (${columns.length}) does not match value count (${row.length})',
      );
    }

    for (var c = 0; c < row.length; c++) {
      sqlHelper.addDynamicValue(row[c]);
      if (c < row.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }
    }
    sqlHelper.addSqlSnippet(')');
  }

  sqlHelper.addSqlSnippet(') AS ');
  sqlHelper
      .addSqlSnippet(quoteIdentifier(sourceAlias, config.identifierDelimiters));
  sqlHelper.addSqlSnippet(' (');
  for (var i = 0; i < columns.length; i++) {
    sqlHelper.addSqlSnippet(
        quoteIdentifier(columns[i], config.identifierDelimiters));
    if (i < columns.length - 1) {
      sqlHelper.addSqlSnippet(', ');
    }
  }
  sqlHelper.addSqlSnippet(') ON ');

  for (var i = 0; i < upsertState.conflictColumns.length; i++) {
    final conflictColumn = upsertState.conflictColumns[i];
    sqlHelper.addSqlSnippet(
        quoteIdentifier(targetAlias, config.identifierDelimiters));
    sqlHelper.addSqlSnippet('.');
    sqlHelper.addSqlSnippet(
        quoteIdentifier(conflictColumn, config.identifierDelimiters));
    sqlHelper.addSqlSnippet(' = ');
    sqlHelper.addSqlSnippet(
        quoteIdentifier(sourceAlias, config.identifierDelimiters));
    sqlHelper.addSqlSnippet('.');
    sqlHelper.addSqlSnippet(
        quoteIdentifier(conflictColumn, config.identifierDelimiters));
    if (i < upsertState.conflictColumns.length - 1) {
      sqlHelper.addSqlSnippet(' AND ');
    }
  }

  sqlHelper.addSqlSnippet(' WHEN NOT MATCHED BY TARGET THEN INSERT (');
  for (var i = 0; i < columns.length; i++) {
    sqlHelper.addSqlSnippet(
        quoteIdentifier(columns[i], config.identifierDelimiters));
    if (i < columns.length - 1) {
      sqlHelper.addSqlSnippet(', ');
    }
  }
  sqlHelper.addSqlSnippet(') VALUES (');
  for (var i = 0; i < columns.length; i++) {
    sqlHelper.addSqlSnippet(
        quoteIdentifier(sourceAlias, config.identifierDelimiters));
    sqlHelper.addSqlSnippet('.');
    sqlHelper.addSqlSnippet(
        quoteIdentifier(columns[i], config.identifierDelimiters));
    if (i < columns.length - 1) {
      sqlHelper.addSqlSnippet(', ');
    }
  }
  sqlHelper.addSqlSnippet(')');

  if (upsertState.action == UpsertAction.doUpdate) {
    sqlHelper.addSqlSnippet(' WHEN MATCHED THEN UPDATE SET ');
    _emitMergeSetList(sqlHelper, config, upsertState, sourceAlias, columns);
  }

  return sqlHelper;
}
