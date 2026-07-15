import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../sql_helper.dart';
import '../state.dart';

SqlHelper defaultLimitOffset(
    QueryState state, Dialect config, ParserMode mode) {
  final sqlHelper = SqlHelper(mode);

  if (state.limit == 0 && state.offset == 0) {
    return sqlHelper;
  }

  if (config.databaseType == DatabaseType.mysql ||
      config.databaseType == DatabaseType.postgres ||
      config.databaseType == DatabaseType.sqlite) {
    if (state.limit > 0) {
      sqlHelper.addSqlSnippet('LIMIT ');
      sqlHelper.addSqlSnippet(state.limit.toString());
    }

    if (state.limit == 0 &&
        !state.isInnerStatement &&
        state.whereStates.isEmpty) {
      sqlHelper.addSqlSnippet('LIMIT ');
      sqlHelper.addSqlSnippet(
          config.runtimeConfiguration.maxRowsReturned.toString());
    }

    if (state.offset > 0) {
      if (state.limit > 0) {
        sqlHelper.addSqlSnippet(' ');
      }

      sqlHelper.addSqlSnippet(' OFFSET ');
      sqlHelper.addSqlSnippet(state.offset.toString());
    }
  }

  if (config.databaseType == DatabaseType.mssql) {
    final top = state.customState?['top'];
    if (top != null && (state.limit > 0 || state.offset > 0)) {
      throw ParserError(
        ParserArea.limitOffset,
        'MSSQL should not use both TOP and LIMIT/OFFSET in the same query',
      );
    }

    if (state.limit > 0 || state.offset > 0) {
      sqlHelper.addSqlSnippet('OFFSET ');
      sqlHelper.addSqlSnippet(state.offset.toString());
      sqlHelper.addSqlSnippet(' ROWS');
    }

    if (state.limit > 0) {
      sqlHelper.addSqlSnippet(' ');

      sqlHelper.addSqlSnippet('FETCH NEXT ');
      sqlHelper.addSqlSnippet(state.limit.toString());
      sqlHelper.addSqlSnippet(' ROWS ONLY');
    }
  }

  if (state.offset > 0 && state.orderByStates.isEmpty) {
    throw ParserError(
        ParserArea.limitOffset, 'ORDER BY is required when using OFFSET');
  }

  return sqlHelper;
}
