import 'dart:convert';

import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';

String _columnRef(Dialect config, FullTextColumnRef column) =>
    '${quoteIdentifier(column.tableNameOrAlias, config.identifierDelimiters)}.'
    '${quoteIdentifier(column.columnName, config.identifierDelimiters)}';

/// Emits a dialect-specific full-text predicate for [columns] and a bound query term.
/// The query value is appended by the caller via [SqlHelper.addDynamicValue].
void emitFullTextPredicate(
  SqlHelper sqlHelper,
  Dialect config,
  List<FullTextColumnRef> columns,
  FullTextMode mode,
  ParserArea area,
) {
  if (columns.isEmpty) {
    throw ParserError(area, 'Full-text search requires at least one column');
  }

  if (config.databaseType == DatabaseType.postgres) {
    if (mode == FullTextMode.phrase) {
      throw ParserError(
        area,
        'Postgres phrase full-text search is not structured yet — use whereMatchRaw or plainto_tsquery in raw SQL',
      );
    }

    if (columns.length == 1) {
      final col = columns.first;
      sqlHelper.addSqlSnippet('to_tsvector(');
      sqlHelper.addSqlSnippet(jsonEncode('english'));
      sqlHelper.addSqlSnippet(', ');
      sqlHelper.addSqlSnippet(_columnRef(config, col));
      sqlHelper.addSqlSnippet(') @@ ');
      sqlHelper.addSqlSnippet(
        mode == FullTextMode.boolean ? 'to_tsquery(' : 'plainto_tsquery(',
      );
      sqlHelper.addSqlSnippet(jsonEncode('english'));
      sqlHelper.addSqlSnippet(', ');
      return;
    }

    sqlHelper.addSqlSnippet('to_tsvector(');
    sqlHelper.addSqlSnippet(jsonEncode('english'));
    sqlHelper.addSqlSnippet(', ');
    sqlHelper.addSqlSnippet('concat(');
    for (var i = 0; i < columns.length; i++) {
      sqlHelper.addSqlSnippet(_columnRef(config, columns[i]));
      if (i < columns.length - 1) {
        sqlHelper.addSqlSnippet(", ' ', ");
      }
    }
    sqlHelper.addSqlSnippet(')) @@ ');
    sqlHelper.addSqlSnippet(
      mode == FullTextMode.boolean ? 'to_tsquery(' : 'plainto_tsquery(',
    );
    sqlHelper.addSqlSnippet(jsonEncode('english'));
    sqlHelper.addSqlSnippet(', ');
    return;
  }

  if (config.databaseType == DatabaseType.mysql) {
    sqlHelper.addSqlSnippet('MATCH (');
    for (var i = 0; i < columns.length; i++) {
      sqlHelper.addSqlSnippet(_columnRef(config, columns[i]));
      if (i < columns.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }
    }
    sqlHelper.addSqlSnippet(') AGAINST (');
    return;
  }

  if (config.databaseType == DatabaseType.mssql) {
    if (columns.length != 1) {
      throw ParserError(
        area,
        'MSSQL CONTAINS/FREETEXT accepts a single column — pass one column or use whereMatchRaw',
      );
    }

    final col = columns.first;
    if (mode == FullTextMode.natural) {
      sqlHelper.addSqlSnippet('FREETEXT(');
      sqlHelper.addSqlSnippet(_columnRef(config, col));
      sqlHelper.addSqlSnippet(', ');
      return;
    }

    sqlHelper.addSqlSnippet('CONTAINS(');
    sqlHelper.addSqlSnippet(_columnRef(config, col));
    sqlHelper.addSqlSnippet(', ');
    return;
  }

  if (config.databaseType == DatabaseType.sqlite) {
    if (columns.length != 1) {
      throw ParserError(
        area,
        'SQLite FTS MATCH accepts a single FTS column — pass one column or use whereMatchRaw',
      );
    }

    if (mode != FullTextMode.natural && mode != FullTextMode.boolean) {
      throw ParserError(
          area, 'SQLite FTS only supports Natural/Boolean-style MATCH queries');
    }

    final col = columns.first;
    sqlHelper.addSqlSnippet(_columnRef(config, col));
    sqlHelper.addSqlSnippet(' MATCH ');
    return;
  }

  throw ParserError(
      area, 'Full-text search is not supported on ${config.databaseType}');
}

/// Emits the closing syntax after the bound full-text query value (MySQL `AGAINST (...)` only).
void emitFullTextValueSuffix(
  SqlHelper sqlHelper,
  Dialect config,
  FullTextMode mode,
) {
  if (config.databaseType == DatabaseType.postgres ||
      config.databaseType == DatabaseType.mssql) {
    sqlHelper.addSqlSnippet(')');
    return;
  }

  if (config.databaseType == DatabaseType.mysql) {
    if (mode == FullTextMode.boolean || mode == FullTextMode.phrase) {
      sqlHelper.addSqlSnippet(' IN BOOLEAN MODE)');
      return;
    }

    sqlHelper.addSqlSnippet(' IN NATURAL LANGUAGE MODE)');
  }
}
