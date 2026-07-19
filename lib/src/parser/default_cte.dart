import '../configuration.dart';
import '../enums.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';
import 'to_sql.dart';

SqlHelper defaultCte(
  QueryState state,
  Dialect config,
  ParserMode mode, [
  ToSqlOptions? options,
]) {
  final sqlHelper = SqlHelper(mode);

  if (state.cteStates.isEmpty) {
    return sqlHelper;
  }

  final hasRecursive = state.cteStates.any((cte) => cte.recursive);

  // SQL Server recursive CTEs use bare `WITH` — `RECURSIVE` is not a T-SQL keyword.
  if (hasRecursive && config.databaseType != DatabaseType.mssql) {
    sqlHelper.addSqlSnippet('WITH RECURSIVE ');
  } else {
    sqlHelper.addSqlSnippet('WITH ');
  }

  for (var i = 0; i < state.cteStates.length; i++) {
    final cteState = state.cteStates[i];

    sqlHelper.addSqlSnippet(
        quoteIdentifier(cteState.name, config.identifierDelimiters));

    if (cteState.columns.isNotEmpty) {
      sqlHelper.addSqlSnippet(' (');
      for (var columnIndex = 0;
          columnIndex < cteState.columns.length;
          columnIndex++) {
        sqlHelper.addSqlSnippet(
          quoteIdentifier(
              cteState.columns[columnIndex], config.identifierDelimiters),
        );

        if (columnIndex < cteState.columns.length - 1) {
          sqlHelper.addSqlSnippet(', ');
        }
      }
      sqlHelper.addSqlSnippet(')');
    }

    sqlHelper.addSqlSnippet(' AS (');

    if (cteState.builderType == BuilderType.cteRaw) {
      sqlHelper.addSqlSnippet(cteState.raw ?? '');
    } else if (cteState.subquery != null) {
      final subHelper = defaultToSql(cteState.subquery, config, mode, options);
      sqlHelper.addSqlSnippetWithValues(
          subHelper.getSql(), subHelper.getValues());
    }

    sqlHelper.addSqlSnippet(')');

    if (i < state.cteStates.length - 1) {
      sqlHelper.addSqlSnippet(', ');
    } else {
      sqlHelper.addSqlSnippet(' ');
    }
  }

  return sqlHelper;
}
