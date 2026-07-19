import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';
import 'comparison_operator.dart';
import 'default_full_text.dart';
import 'default_json.dart';

void emitJsonExtractPredicate(
  SqlHelper sqlHelper,
  Dialect config,
  ParserMode mode, {
  required String? tableNameOrAlias,
  required String? columnName,
  required String? jsonPath,
  required JsonExtractMode? jsonExtractMode,
  required WhereOperator whereOperator,
  required List<Object?> values,
  required ParserArea area,
}) {
  if (tableNameOrAlias == null ||
      columnName == null ||
      jsonPath == null ||
      jsonExtractMode == null) {
    throw ParserError(
        area, 'JSON extract predicate requires table, column, path, and mode');
  }

  emitJsonExtractExpression(
    sqlHelper,
    config,
    tableNameOrAlias,
    columnName,
    jsonPath,
    jsonExtractMode,
    area,
  );

  final scratch = SqlHelper(mode);
  emitComparisonPredicate(
    scratch,
    config,
    '___json___',
    whereOperator,
    values.isNotEmpty ? values[0] : null,
    area,
  );
  var tail = scratch.getSql();
  if (tail.startsWith('___json___ ')) {
    tail = tail.substring('___json___ '.length);
  } else if (tail.startsWith('LOWER(___json___)')) {
    tail = 'LOWER(${tail.substring('LOWER(___json___)'.length)}';
  } else if (tail.startsWith('NOT (___json___')) {
    tail = 'NOT (${tail.substring('NOT (___json___'.length)}';
  }

  sqlHelper.addSqlSnippet(' ');
  sqlHelper.addSqlSnippetWithValues(tail, scratch.getValues());
}

void emitJsonContainsPredicate(
  SqlHelper sqlHelper,
  Dialect config, {
  required String? tableNameOrAlias,
  required String? columnName,
  required List<Object?> values,
  required ParserArea area,
}) {
  if (tableNameOrAlias == null || columnName == null) {
    throw ParserError(
        area, 'JSON contains predicate requires table and column');
  }

  emitJsonContainsExpression(
      sqlHelper, config, tableNameOrAlias, columnName, area);
  sqlHelper.addDynamicValue(values.isNotEmpty ? values[0] : null);

  if (config.databaseType == DatabaseType.postgres) {
    sqlHelper.addSqlSnippet('::jsonb');
  }

  if (config.databaseType == DatabaseType.mysql) {
    sqlHelper.addSqlSnippet(')');
  }
}

void emitFullTextMatchPredicate(
  SqlHelper sqlHelper,
  Dialect config,
  List<FullTextColumnRef> columns,
  FullTextMode mode,
  Object? value,
  ParserArea area,
) {
  emitFullTextPredicate(sqlHelper, config, columns, mode, area);
  sqlHelper.addDynamicValue(value);
  emitFullTextValueSuffix(sqlHelper, config, mode);
}

/// Emits one GROUP BY column reference.
void emitGroupByColumnRef(
  SqlHelper sqlHelper,
  Dialect config,
  String tableNameOrAlias,
  String columnName,
) {
  sqlHelper.addSqlSnippet(
      quoteIdentifier(tableNameOrAlias, config.identifierDelimiters));
  sqlHelper.addSqlSnippet('.');
  sqlHelper
      .addSqlSnippet(quoteIdentifier(columnName, config.identifierDelimiters));
}
