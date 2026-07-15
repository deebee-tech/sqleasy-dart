import '../configuration.dart';
import '../enums.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';

SqlHelper defaultGroupBy(QueryState state, Dialect config, ParserMode mode) {
  final sqlHelper = SqlHelper(mode);

  if (state.groupByStates.isEmpty) {
    return sqlHelper;
  }

  sqlHelper.addSqlSnippet('GROUP BY ');

  for (var i = 0; i < state.groupByStates.length; i++) {
    final groupByState = state.groupByStates[i];

    if (groupByState.builderType == BuilderType.groupByRaw) {
      sqlHelper.addSqlSnippet(groupByState.raw ?? '');

      if (i < state.groupByStates.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }

      continue;
    }

    if (groupByState.builderType == BuilderType.groupByColumn) {
      sqlHelper.addSqlSnippet(
        quoteIdentifier(
            groupByState.tableNameOrAlias, config.identifierDelimiters),
      );
      sqlHelper.addSqlSnippet('.');
      sqlHelper.addSqlSnippet(
        quoteIdentifier(groupByState.columnName, config.identifierDelimiters),
      );

      if (i < state.groupByStates.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }

      continue;
    }
  }

  return sqlHelper;
}
