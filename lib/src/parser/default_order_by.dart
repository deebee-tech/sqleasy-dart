import '../configuration.dart';
import '../enums.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';

/// Emits one `<column> [ASC|DESC] [NULLS FIRST|NULLS LAST]` sort term. Shared by the top-level
/// ORDER BY clause and a window's `OVER (... ORDER BY ...)`.
void emitOrderByTerm(
  SqlHelper sqlHelper,
  Dialect config,
  String? tableNameOrAlias,
  String? columnName,
  OrderByDirection direction,
  NullsOrder nulls,
) {
  final columnSql =
      '${quoteIdentifier(tableNameOrAlias, config.identifierDelimiters)}.'
      '${quoteIdentifier(columnName, config.identifierDelimiters)}';

  final hasNativeNulls = config.databaseType == DatabaseType.postgres ||
      config.databaseType == DatabaseType.sqlite;

  if (nulls != NullsOrder.none && !hasNativeNulls) {
    final nullsFirst = nulls == NullsOrder.first;
    sqlHelper.addSqlSnippet(
      'CASE WHEN $columnSql IS NULL THEN ${nullsFirst ? '0' : '1'} ELSE ${nullsFirst ? '1' : '0'} END, ',
    );
  }

  sqlHelper.addSqlSnippet(columnSql);

  if (direction == OrderByDirection.ascending) {
    sqlHelper.addSqlSnippet(' ASC');
  } else if (direction == OrderByDirection.descending) {
    sqlHelper.addSqlSnippet(' DESC');
  }

  if (nulls != NullsOrder.none && hasNativeNulls) {
    sqlHelper.addSqlSnippet(
        nulls == NullsOrder.first ? ' NULLS FIRST' : ' NULLS LAST');
  }
}

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
      emitOrderByTerm(
        sqlHelper,
        config,
        orderByState.tableNameOrAlias,
        orderByState.columnName,
        orderByState.direction,
        orderByState.nulls,
      );

      if (i < state.orderByStates.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }

      continue;
    }
  }

  return sqlHelper;
}
