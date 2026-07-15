import '../configuration.dart';
import '../enums.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';

SqlHelper defaultOrderBy(QueryState state, Dialect config, ParserMode mode) {
  final sqlHelper = SqlHelper(mode);

  if (state.orderByStates.isEmpty) {
    return sqlHelper;
  }

  sqlHelper.addSqlSnippet('ORDER BY ');

  for (var i = 0; i < state.orderByStates.length; i++) {
    final orderByState = state.orderByStates[i];

    if (orderByState.builderType == BuilderType.orderByRaw) {
      sqlHelper.addSqlSnippet(orderByState.raw ?? '');

      if (i < state.orderByStates.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }

      continue;
    }

    if (orderByState.builderType == BuilderType.orderByColumn) {
      sqlHelper.addSqlSnippet(
        quoteIdentifier(
            orderByState.tableNameOrAlias, config.identifierDelimiters),
      );
      sqlHelper.addSqlSnippet('.');
      sqlHelper.addSqlSnippet(
        quoteIdentifier(orderByState.columnName, config.identifierDelimiters),
      );

      if (orderByState.direction == OrderByDirection.ascending) {
        sqlHelper.addSqlSnippet(' ASC');
      } else {
        sqlHelper.addSqlSnippet(' DESC');
      }

      if (i < state.orderByStates.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }

      continue;
    }
  }

  return sqlHelper;
}
