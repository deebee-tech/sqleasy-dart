import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';
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

  if (state.distinct) {
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

    if (selectState.builderType == BuilderType.selectBuilder) {
      final subHelper = defaultToSql(selectState.subquery, config, mode);

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
  }

  return sqlHelper;
}
