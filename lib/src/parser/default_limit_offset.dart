import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../sql_helper.dart';
import '../state.dart';

/// Each grammar's idiom for "no upper bound, just skip n rows".
///
/// MySQL and SQLite have no standalone OFFSET — it only parses as the tail of a LIMIT — so an
/// offset without a limit needs a sentinel limit in front of it or the statement is a syntax error
/// (MySQL 1064, SQLite `near "OFFSET"`). MySQL's documented idiom is the largest unsigned BIGINT,
/// 2^64-1; 2^64 is itself a syntax error. Postgres is deliberately absent: a bare OFFSET is valid
/// there.
const _unboundedLimit = <DatabaseType, String>{
  DatabaseType.mysql: '18446744073709551615',
  DatabaseType.sqlite: '-1',
};

SqlHelper defaultLimitOffset(
    QueryState state, Dialect config, ParserMode mode) {
  final sqlHelper = SqlHelper(mode);

  if (state.limit == 0 && state.offset == 0 && !state.limitWithTies) {
    return sqlHelper;
  }

  if (config.databaseType == DatabaseType.mysql ||
      config.databaseType == DatabaseType.postgres ||
      config.databaseType == DatabaseType.sqlite) {
    if (state.limitWithTies) {
      if (config.databaseType == DatabaseType.sqlite) {
        throw ParserError(
            ParserArea.limitOffset, 'SQLite does not support WITH TIES');
      }

      if (state.limit <= 0) {
        throw ParserError(
            ParserArea.limitOffset, 'limitWithTies requires a positive limit');
      }

      if (state.offset > 0) {
        sqlHelper.addSqlSnippet('OFFSET ');
        sqlHelper.addSqlSnippet(state.offset.toString());
        sqlHelper.addSqlSnippet(' ROWS ');
      }

      sqlHelper.addSqlSnippet('FETCH FIRST ');
      sqlHelper.addSqlSnippet(state.limit.toString());
      sqlHelper.addSqlSnippet(' ROWS WITH TIES');
      return sqlHelper;
    }

    if (state.limit > 0) {
      sqlHelper.addSqlSnippet('LIMIT ');
      sqlHelper.addSqlSnippet(state.limit.toString());
    } else if (state.offset > 0) {
      // Offset with no limit is a legitimate query — "skip n, return the rest" — but MySQL and
      // SQLite cannot spell it without a limit in front. Postgres yields no sentinel and keeps its
      // bare OFFSET.
      final sentinel = _unboundedLimit[config.databaseType];

      if (sentinel != null) {
        sqlHelper.addSqlSnippet('LIMIT ');
        sqlHelper.addSqlSnippet(sentinel);
      }
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
      sqlHelper.addSqlSnippet(
          state.limitWithTies ? ' ROWS WITH TIES' : ' ROWS ONLY');
    }
  }

  // Evaluated after the clause text is built so that MSSQL's TOP/LIMIT conflict above reports
  // first. Both arms are the same guard: pagination needs a deterministic order to page against.
  if (state.orderByStates.isEmpty) {
    if (state.limitWithTies) {
      throw ParserError(
          ParserArea.limitOffset, 'ORDER BY is required when using WITH TIES');
    }

    if (state.offset > 0) {
      throw ParserError(
          ParserArea.limitOffset, 'ORDER BY is required when using OFFSET');
    }

    // MSSQL renders `.limit(n)` as OFFSET/FETCH, and T-SQL requires an ORDER BY for it (Msg 102).
    // `.limit()` is pagination; the designer's explicit, unordered row cap is `.top(n)`.
    if (config.databaseType == DatabaseType.mssql && state.limit > 0) {
      throw ParserError(
        ParserArea.limitOffset,
        'ORDER BY is required when using LIMIT on MSSQL, which paginates with OFFSET/FETCH; use top() for an unordered row cap',
      );
    }
  }

  return sqlHelper;
}
