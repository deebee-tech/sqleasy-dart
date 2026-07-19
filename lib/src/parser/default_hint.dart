import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';

/// MySQL index hint text immediately after a table reference (`USE INDEX (idx)`).
String mysqlIndexHintForTable(
  QueryState state,
  Dialect config,
  String tableNameOrAlias,
) {
  if (state.hintStates.isEmpty) {
    return '';
  }

  final indexHints = state.hintStates.where((hint) =>
      (hint.kind == HintKind.useIndex || hint.kind == HintKind.forceIndex) &&
      hint.tableNameOrAlias == tableNameOrAlias &&
      (hint.indexName ?? '').isNotEmpty);

  if (indexHints.isEmpty) {
    return '';
  }

  if (config.databaseType != DatabaseType.mysql) {
    throw ParserError(
      ParserArea.from,
      'MySQL index hints (hintUseIndex/hintForceIndex) are only supported on MySQL',
    );
  }

  var sql = '';
  for (final hint in indexHints) {
    sql +=
        '${hint.kind == HintKind.forceIndex ? ' FORCE INDEX (' : ' USE INDEX ('}'
        '${quoteIdentifier(hint.indexName, config.identifierDelimiters)})';
  }

  return sql;
}

/// Trailing MSSQL `OPTION (...)` and raw hints appended after the SELECT statement body.
void emitTrailingHints(SqlHelper sqlHelper, QueryState state, Dialect config) {
  if (state.hintStates.isEmpty) {
    return;
  }

  for (final hint in state.hintStates) {
    if (hint.kind == HintKind.mssqlOption) {
      if (config.databaseType != DatabaseType.mssql) {
        throw ParserError(
          ParserArea.general,
          'hintMssqlOption is only supported on MSSQL — use hintRaw on other dialects',
        );
      }

      if ((hint.optionText ?? '').trim().isEmpty) {
        throw ParserError(ParserArea.general,
            'hintMssqlOption requires non-empty option text');
      }

      sqlHelper.addSqlSnippet(' OPTION (');
      sqlHelper.addSqlSnippet(hint.optionText!);
      sqlHelper.addSqlSnippet(')');
      continue;
    }

    if (hint.kind == HintKind.raw) {
      if ((hint.raw ?? '').trim().isEmpty) {
        throw ParserError(ParserArea.general, 'hintRaw requires non-empty SQL');
      }

      sqlHelper.addSqlSnippet(' ');
      sqlHelper.addSqlSnippet(hint.raw!);
    }
  }
}

/// Validates that no unsupported hint kinds remain unhandled at parse time.
void validateHints(QueryState state, Dialect config, ParserArea area) {
  if (state.hintStates.isEmpty) {
    return;
  }

  for (final hint in state.hintStates) {
    if (hint.kind == HintKind.useIndex || hint.kind == HintKind.forceIndex) {
      if (config.databaseType != DatabaseType.mysql) {
        throw ParserError(
          area,
          'MySQL index hints (hintUseIndex/hintForceIndex) are only supported on MySQL — use hintRaw elsewhere',
        );
      }
    }
  }
}
