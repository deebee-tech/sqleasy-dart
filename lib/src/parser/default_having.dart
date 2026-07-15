import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';

SqlHelper defaultHaving(QueryState state, Dialect config, ParserMode mode) {
  final sqlHelper = SqlHelper(mode);

  if (state.havingStates.isEmpty) {
    return sqlHelper;
  }

  if (state.groupByStates.isEmpty) {
    throw ParserError(ParserArea.general, 'HAVING requires a GROUP BY clause');
  }

  sqlHelper.addSqlSnippet('HAVING ');

  for (var i = 0; i < state.havingStates.length; i++) {
    final havingState = state.havingStates[i];

    if (i == 0 &&
        (havingState.builderType == BuilderType.and ||
            havingState.builderType == BuilderType.or)) {
      throw ParserError(
          ParserArea.general, 'First HAVING operator cannot be AND or OR');
    }

    if (havingState.builderType == BuilderType.and) {
      sqlHelper.addSqlSnippet('AND ');
      continue;
    }

    if (havingState.builderType == BuilderType.or) {
      sqlHelper.addSqlSnippet('OR ');
      continue;
    }

    if (havingState.builderType == BuilderType.havingRaw) {
      sqlHelper.addSqlSnippet(havingState.raw ?? '');

      if (i < state.havingStates.length - 1) {
        sqlHelper.addSqlSnippet(' ');
      }
      continue;
    }

    if (havingState.builderType == BuilderType.having) {
      sqlHelper.addSqlSnippet(
        quoteIdentifier(
            havingState.tableNameOrAlias, config.identifierDelimiters),
      );
      sqlHelper.addSqlSnippet('.');
      sqlHelper.addSqlSnippet(
        quoteIdentifier(havingState.columnName, config.identifierDelimiters),
      );
      sqlHelper.addSqlSnippet(' ');

      switch (havingState.whereOperator) {
        case WhereOperator.equals:
          sqlHelper.addSqlSnippet('=');
        case WhereOperator.notEquals:
          sqlHelper.addSqlSnippet('<>');
        case WhereOperator.greaterThan:
          sqlHelper.addSqlSnippet('>');
        case WhereOperator.greaterThanOrEquals:
          sqlHelper.addSqlSnippet('>=');
        case WhereOperator.lessThan:
          sqlHelper.addSqlSnippet('<');
        case WhereOperator.lessThanOrEquals:
          sqlHelper.addSqlSnippet('<=');
        // HAVING takes the same WhereOperator as WHERE. Omitting these two rendered `HAVING "x"."y"
        // $1` — the operator silently missing, the value still bound, the statement invalid.
        case WhereOperator.like:
          sqlHelper.addSqlSnippet('LIKE');
        case WhereOperator.notLike:
          sqlHelper.addSqlSnippet('NOT LIKE');
        case WhereOperator.none:
          break;
      }

      sqlHelper.addSqlSnippet(' ');
      sqlHelper.addDynamicValue(havingState.values[0]);

      if (i < state.havingStates.length - 1) {
        sqlHelper.addSqlSnippet(' ');
      }
      continue;
    }
  }

  return sqlHelper;
}
