import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';
import 'default_window.dart';
import 'default_json.dart';
import 'to_sql.dart';

SqlHelper defaultSelect(
  QueryState state,
  Dialect config,
  ParserMode mode, [
  ToSqlOptions? options,
]) {
  final sqlHelper = SqlHelper(mode);

  if (state.selectStates.isEmpty) {
    throw ParserError(
      ParserArea.select,
      'Select statement must have at least one select state',
    );
  }

  sqlHelper.addSqlSnippet('SELECT ');

  final distinctOnColumns = state.distinctOnColumns;
  if (distinctOnColumns != null && distinctOnColumns.isNotEmpty) {
    if (config.databaseType != DatabaseType.postgres) {
      throw ParserError(
          ParserArea.select, 'DISTINCT ON is only supported on Postgres');
    }

    if (state.distinct) {
      throw ParserError(
          ParserArea.select, 'Cannot combine distinct() with distinctOn()');
    }

    sqlHelper.addSqlSnippet('DISTINCT ON (');
    for (var i = 0; i < distinctOnColumns.length; i++) {
      final column = distinctOnColumns[i];
      sqlHelper.addSqlSnippet(
        quoteIdentifier(column.tableNameOrAlias, config.identifierDelimiters),
      );
      sqlHelper.addSqlSnippet('.');
      sqlHelper.addSqlSnippet(
        quoteIdentifier(column.columnName, config.identifierDelimiters),
      );

      if (i < distinctOnColumns.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }
    }
    sqlHelper.addSqlSnippet(') ');
  } else if (state.distinct) {
    sqlHelper.addSqlSnippet('DISTINCT ');
  }

  options?.beforeSelectColumns?.call(state, config, sqlHelper);

  for (var i = 0; i < state.selectStates.length; i++) {
    final selectState = state.selectStates[i];

    if (selectState.builderType == BuilderType.selectAll) {
      sqlHelper.addSqlSnippet('*');

      if (i < state.selectStates.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }
    }

    if (selectState.builderType == BuilderType.selectRaw) {
      sqlHelper.addSqlSnippet(selectState.raw ?? '');
      if (i < state.selectStates.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }
      continue;
    }

    if (selectState.builderType == BuilderType.selectColumn) {
      sqlHelper.addSqlSnippet(
        quoteIdentifier(
            selectState.tableNameOrAlias, config.identifierDelimiters),
      );
      sqlHelper.addSqlSnippet('.');
      sqlHelper.addSqlSnippet(
        quoteIdentifier(selectState.columnName, config.identifierDelimiters),
      );

      if ((selectState.alias ?? '').isNotEmpty) {
        sqlHelper.addSqlSnippet(' AS ');
        sqlHelper.addSqlSnippet(
          quoteIdentifier(selectState.alias, config.identifierDelimiters),
        );
      }

      if (i < state.selectStates.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }

      continue;
    }

    if (selectState.builderType == BuilderType.selectWindow) {
      sqlHelper.addSqlSnippet(selectState.raw ?? '');
      sqlHelper.addSqlSnippet(' ');

      final windowHelper = defaultWindow(
        selectState.window ??
            (WindowState()
              ..partitionByStates = []
              ..orderByStates = []),
        config,
        mode,
      );
      sqlHelper.addSqlSnippetWithValues(
          windowHelper.getSql(), windowHelper.getValues());

      if ((selectState.alias ?? '').isNotEmpty) {
        sqlHelper.addSqlSnippet(' AS ');
        sqlHelper.addSqlSnippet(
          quoteIdentifier(selectState.alias, config.identifierDelimiters),
        );
      }

      if (i < state.selectStates.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }

      continue;
    }

    if (selectState.builderType == BuilderType.selectBuilder) {
      final subHelper =
          defaultToSql(selectState.subquery, config, mode, options);

      sqlHelper.addSqlSnippetWithValues(
          '(${subHelper.getSql()})', subHelper.getValues());

      if ((selectState.alias ?? '').isNotEmpty) {
        sqlHelper.addSqlSnippet(' AS ');
        sqlHelper.addSqlSnippet(
          quoteIdentifier(selectState.alias, config.identifierDelimiters),
        );
      }

      if (i < state.selectStates.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }

      continue;
    }

    if (selectState.builderType == BuilderType.selectJsonExtract) {
      emitJsonExtractExpression(
        sqlHelper,
        config,
        selectState.tableNameOrAlias ?? '',
        selectState.columnName ?? '',
        selectState.jsonPath ?? '',
        selectState.jsonExtractMode ?? JsonExtractMode.text,
        ParserArea.select,
      );

      if ((selectState.alias ?? '').isNotEmpty) {
        sqlHelper.addSqlSnippet(' AS ');
        sqlHelper.addSqlSnippet(
          quoteIdentifier(selectState.alias, config.identifierDelimiters),
        );
      }

      if (i < state.selectStates.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }

      continue;
    }
  }

  return sqlHelper;
}
