import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../sql_helper.dart';

/// Emits `<column> <operator> <value>` for a comparison predicate — the shared core of WHERE's
/// and HAVING's `col op value` term, so the two clauses can never drift on operator semantics.
///
/// [columnSql] must already be the fully quoted/qualified column reference (e.g. `"u"."id"`).
/// [area] selects the [ParserError] area for an unsupported operator, so the message still says
/// `Where:` or `Having:` as appropriate.
void emitComparisonPredicate(
  SqlHelper sqlHelper,
  Dialect config,
  String columnSql,
  WhereOperator whereOperator,
  Object? value,
  ParserArea area,
) {
  // `col = NULL` is never true under SQL three-valued logic. Emit IS NULL / IS NOT NULL so
  // callers who pass null get a predicate that can match rows.
  if ((whereOperator == WhereOperator.equals ||
          whereOperator == WhereOperator.notEquals) &&
      value == null) {
    sqlHelper.addSqlSnippet(columnSql);
    sqlHelper.addSqlSnippet(' ');
    sqlHelper.addSqlSnippet(
        whereOperator == WhereOperator.equals ? 'IS NULL' : 'IS NOT NULL');
    return;
  }

  if (whereOperator == WhereOperator.isDistinctFrom ||
      whereOperator == WhereOperator.isNotDistinctFrom) {
    final isNotDistinct = whereOperator == WhereOperator.isNotDistinctFrom;

    if (config.databaseType == DatabaseType.postgres ||
        config.databaseType == DatabaseType.sqlite) {
      sqlHelper.addSqlSnippet(columnSql);
      sqlHelper.addSqlSnippet(
          isNotDistinct ? ' IS NOT DISTINCT FROM ' : ' IS DISTINCT FROM ');
      sqlHelper.addDynamicValue(value);
      return;
    }

    if (config.databaseType == DatabaseType.mysql) {
      if (isNotDistinct) {
        sqlHelper.addSqlSnippet(columnSql);
        sqlHelper.addSqlSnippet(' <=> ');
        sqlHelper.addDynamicValue(value);
        return;
      }

      sqlHelper.addSqlSnippet('NOT (');
      sqlHelper.addSqlSnippet(columnSql);
      sqlHelper.addSqlSnippet(' <=> ');
      sqlHelper.addDynamicValue(value);
      sqlHelper.addSqlSnippet(')');
      return;
    }

    throw ParserError(
      area,
      'MSSQL does not support IS DISTINCT FROM / IS NOT DISTINCT FROM — write the equivalent CASE expression as raw SQL',
    );
  }

  if (whereOperator == WhereOperator.ilike ||
      whereOperator == WhereOperator.notIlike) {
    final negate = whereOperator == WhereOperator.notIlike;

    // Postgres has native ILIKE. Every other dialect here has no case-insensitive LIKE
    // operator, so it is emulated by lower-casing both sides — the standard portable rewrite.
    if (config.databaseType == DatabaseType.postgres) {
      sqlHelper.addSqlSnippet(columnSql);
      sqlHelper.addSqlSnippet(negate ? ' NOT ILIKE ' : ' ILIKE ');
      sqlHelper.addDynamicValue(value);
      return;
    }

    sqlHelper.addSqlSnippet('LOWER(');
    sqlHelper.addSqlSnippet(columnSql);
    sqlHelper.addSqlSnippet(negate ? ') NOT LIKE LOWER(' : ') LIKE LOWER(');
    sqlHelper.addDynamicValue(value);
    sqlHelper.addSqlSnippet(')');
    return;
  }

  sqlHelper.addSqlSnippet(columnSql);
  sqlHelper.addSqlSnippet(' ');

  switch (whereOperator) {
    case WhereOperator.equals:
      sqlHelper.addSqlSnippet('=');
    case WhereOperator.notEquals:
      sqlHelper.addSqlSnippet('<>');
    case WhereOperator.greaterThan:
      sqlHelper.addSqlSnippet('>');
    case WhereOperator.greaterThanOrEquals:
      sqlHelper.addSqlSnippet('>=');
    case WhereOperator.lessThan:
      sqlHelper.addSqlSnippet('<');
    case WhereOperator.lessThanOrEquals:
      sqlHelper.addSqlSnippet('<=');
    case WhereOperator.like:
      sqlHelper.addSqlSnippet('LIKE');
    case WhereOperator.notLike:
      sqlHelper.addSqlSnippet('NOT LIKE');
    default:
      throw ParserError(
        area,
        'Unsupported ${area.value.toUpperCase()} operator: ${whereOperator.wire}',
      );
  }

  sqlHelper.addSqlSnippet(' ');
  sqlHelper.addDynamicValue(value);
}
