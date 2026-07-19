import 'dart:convert';

import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';

String _columnRef(Dialect config, String tableNameOrAlias, String columnName) =>
    '${quoteIdentifier(tableNameOrAlias, config.identifierDelimiters)}.'
    '${quoteIdentifier(columnName, config.identifierDelimiters)}';

String _pgPathLiteral(String path) {
  final escaped = path.replaceAll("'", "''");
  return "'$escaped'";
}

/// Emits a dialect-specific JSON path extraction expression for [columnName] at [path].
void emitJsonExtractExpression(
  SqlHelper sqlHelper,
  Dialect config,
  String tableNameOrAlias,
  String columnName,
  String path,
  JsonExtractMode mode,
  ParserArea area,
) {
  final col = _columnRef(config, tableNameOrAlias, columnName);

  if (config.databaseType == DatabaseType.postgres) {
    sqlHelper.addSqlSnippet(col);
    sqlHelper.addSqlSnippet(mode == JsonExtractMode.text ? '->>' : '->');
    sqlHelper.addSqlSnippet(_pgPathLiteral(path));
    return;
  }

  if (config.databaseType == DatabaseType.mysql) {
    if (mode == JsonExtractMode.text) {
      sqlHelper.addSqlSnippet('JSON_UNQUOTE(JSON_EXTRACT(');
      sqlHelper.addSqlSnippet(col);
      sqlHelper.addSqlSnippet(', ');
      sqlHelper.addSqlSnippet(jsonEncode(path));
      sqlHelper.addSqlSnippet('))');
      return;
    }

    sqlHelper.addSqlSnippet('JSON_EXTRACT(');
    sqlHelper.addSqlSnippet(col);
    sqlHelper.addSqlSnippet(', ');
    sqlHelper.addSqlSnippet(jsonEncode(path));
    sqlHelper.addSqlSnippet(')');
    return;
  }

  if (config.databaseType == DatabaseType.mssql) {
    if (mode == JsonExtractMode.object) {
      sqlHelper.addSqlSnippet('JSON_QUERY(');
      sqlHelper.addSqlSnippet(col);
      sqlHelper.addSqlSnippet(', ');
      sqlHelper.addSqlSnippet(jsonEncode(path));
      sqlHelper.addSqlSnippet(')');
      return;
    }

    sqlHelper.addSqlSnippet('JSON_VALUE(');
    sqlHelper.addSqlSnippet(col);
    sqlHelper.addSqlSnippet(', ');
    sqlHelper.addSqlSnippet(jsonEncode(path));
    sqlHelper.addSqlSnippet(')');
    return;
  }

  if (config.databaseType == DatabaseType.sqlite) {
    if (mode == JsonExtractMode.object) {
      throw ParserError(
        area,
        'SQLite json_extract always returns text — use JsonExtractMode.Text or selectJsonRaw',
      );
    }

    sqlHelper.addSqlSnippet('json_extract(');
    sqlHelper.addSqlSnippet(col);
    sqlHelper.addSqlSnippet(', ');
    sqlHelper.addSqlSnippet(jsonEncode(path));
    sqlHelper.addSqlSnippet(')');
    return;
  }

  throw ParserError(
      area, 'JSON extract is not supported on ${config.databaseType}');
}

/// Emits `column @> value` / `JSON_CONTAINS` / equivalent containment predicate (lhs only).
void emitJsonContainsExpression(
  SqlHelper sqlHelper,
  Dialect config,
  String tableNameOrAlias,
  String columnName,
  ParserArea area,
) {
  final col = _columnRef(config, tableNameOrAlias, columnName);

  if (config.databaseType == DatabaseType.postgres) {
    sqlHelper.addSqlSnippet(col);
    sqlHelper.addSqlSnippet(' @> ');
    return;
  }

  if (config.databaseType == DatabaseType.mysql) {
    sqlHelper.addSqlSnippet('JSON_CONTAINS(');
    sqlHelper.addSqlSnippet(col);
    sqlHelper.addSqlSnippet(', ');
    return;
  }

  if (config.databaseType == DatabaseType.mssql) {
    throw ParserError(
      area,
      'MSSQL has no JSON containment operator — use whereJsonExtract or whereRaw with OPENJSON/JSON_QUERY',
    );
  }

  throw ParserError(
    area,
    'SQLite does not support JSON containment — use whereJsonExtract or whereRaw',
  );
}
