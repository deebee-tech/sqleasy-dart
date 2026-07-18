import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';

bool _isHavingPredicate(HavingState state) =>
    state.builderType == BuilderType.having ||
    state.builderType == BuilderType.havingRaw;

SqlHelper defaultHaving(QueryState state, Dialect config, ParserMode mode) {
  final sqlHelper = SqlHelper(mode);

  if (state.havingStates.isEmpty) {
    return sqlHelper;
  }

  if (state.groupByStates.isEmpty) {
    throw ParserError(ParserArea.having, 'HAVING requires a GROUP BY clause');
  }

  sqlHelper.addSqlSnippet('HAVING ');

  for (var i = 0; i < state.havingStates.length; i++) {
    final havingState = state.havingStates[i];
    final prev = i > 0 ? state.havingStates[i - 1] : null;

    if (i == 0 &&
        (havingState.builderType == BuilderType.and ||
            havingState.builderType == BuilderType.or)) {
      throw ParserError(
          ParserArea.having, 'First HAVING operator cannot be AND or OR');
    }

    if (i == state.havingStates.length - 1 &&
        (havingState.builderType == BuilderType.and ||
            havingState.builderType == BuilderType.or)) {
      throw ParserError(ParserArea.having,
          'AND or OR cannot be used as the last HAVING operator');
    }

    if ((havingState.builderType == BuilderType.and ||
            havingState.builderType == BuilderType.or) &&
        prev != null &&
        (prev.builderType == BuilderType.and ||
            prev.builderType == BuilderType.or)) {
      throw ParserError(
          ParserArea.having, 'AND or OR cannot be used consecutively');
    }

    if (havingState.builderType == BuilderType.and) {
      sqlHelper.addSqlSnippet(' AND ');
      continue;
    }

    if (havingState.builderType == BuilderType.or) {
      sqlHelper.addSqlSnippet(' OR ');
      continue;
    }

    // Consecutive predicates without an explicit AND/OR are joined with AND so
    // `.having().having()` and `havingRaws([...])` emit valid SQL.
    if (i > 0 &&
        prev != null &&
        _isHavingPredicate(prev) &&
        _isHavingPredicate(havingState)) {
      sqlHelper.addSqlSnippet(' AND ');
    }

    if (havingState.builderType == BuilderType.havingRaw) {
      sqlHelper.addSqlSnippet(havingState.raw ?? '');
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

      final value =
          havingState.values.isNotEmpty ? havingState.values[0] : null;

      // Null comparisons are three-valued — emit IS NULL / IS NOT NULL instead of `= NULL`.
      if ((havingState.whereOperator == WhereOperator.equals ||
              havingState.whereOperator == WhereOperator.notEquals) &&
          value == null) {
        sqlHelper.addSqlSnippet(
          havingState.whereOperator == WhereOperator.equals
              ? 'IS NULL'
              : 'IS NOT NULL',
        );
        continue;
      }

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
        case WhereOperator.like:
          sqlHelper.addSqlSnippet('LIKE');
        case WhereOperator.notLike:
          sqlHelper.addSqlSnippet('NOT LIKE');
        default:
          throw ParserError(
            ParserArea.having,
            'Unsupported HAVING operator: ${havingState.whereOperator.wire}',
          );
      }

      sqlHelper.addSqlSnippet(' ');
      sqlHelper.addDynamicValue(value);
      continue;
    }
  }

  return sqlHelper;
}
