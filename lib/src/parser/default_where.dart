import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';
import 'to_sql.dart';

SqlHelper defaultWhere(QueryState state, Dialect config, ParserMode mode) {
  final sqlHelper = SqlHelper(mode);

  if (state.whereStates.isEmpty) {
    return sqlHelper;
  }

  sqlHelper.addSqlSnippet('WHERE ');

  for (var i = 0; i < state.whereStates.length; i++) {
    final cur = state.whereStates[i];
    final prev = i > 0 ? state.whereStates[i - 1] : null;
    final next =
        i < state.whereStates.length - 1 ? state.whereStates[i + 1] : null;
    void spaceAfter() {
      if (i < state.whereStates.length - 1 &&
          next?.builderType != BuilderType.whereGroupEnd) {
        sqlHelper.addSqlSnippet(' ');
      }
    }

    if (i == 0 &&
        (cur.builderType == BuilderType.and ||
            cur.builderType == BuilderType.or)) {
      throw ParserError(
          ParserArea.where, 'First WHERE operator cannot be AND or OR');
    }

    if (i == state.whereStates.length - 1 &&
        (cur.builderType == BuilderType.and ||
            cur.builderType == BuilderType.or)) {
      throw ParserError(ParserArea.where,
          'AND or OR cannot be used as the last WHERE operator');
    }

    if ((cur.builderType == BuilderType.and ||
            cur.builderType == BuilderType.or) &&
        (prev?.builderType == BuilderType.and ||
            prev?.builderType == BuilderType.or)) {
      throw ParserError(
          ParserArea.where, 'AND or OR cannot be used consecutively');
    }

    if ((cur.builderType == BuilderType.and ||
            cur.builderType == BuilderType.or) &&
        prev?.builderType == BuilderType.whereGroupBegin) {
      throw ParserError(ParserArea.where,
          'AND or OR cannot be used directly after a group begin');
    }

    if (cur.builderType == BuilderType.whereGroupBegin &&
        i == state.whereStates.length - 1) {
      throw ParserError(
          ParserArea.where, 'Group begin cannot be the last WHERE operator');
    }

    if (cur.builderType == BuilderType.whereGroupEnd && i == 0) {
      throw ParserError(
          ParserArea.where, 'Group end cannot be the first WHERE operator');
    }

    if (cur.builderType == BuilderType.and) {
      sqlHelper.addSqlSnippet('AND');
      if (i < state.whereStates.length - 1) {
        sqlHelper.addSqlSnippet(' ');
      }
      continue;
    }

    if (cur.builderType == BuilderType.or) {
      sqlHelper.addSqlSnippet('OR');
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.whereGroupBegin) {
      sqlHelper.addSqlSnippet('(');
      continue;
    }

    if (cur.builderType == BuilderType.whereGroupEnd) {
      sqlHelper.addSqlSnippet(')');
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.whereRaw) {
      sqlHelper.addSqlSnippet(cur.raw ?? '');
      spaceAfter();
      continue;
    }

    // A grouped sub-expression: render the sub-builder's predicates inside the ( ) that the
    // surrounding WhereGroupBegin/End emit, carrying its bound values up in order.
    if (cur.builderType == BuilderType.whereGroupBuilder) {
      if (cur.subquery != null) {
        final subHelper = defaultWhere(cur.subquery!, config, mode);
        var inner = subHelper.getSql();
        if (inner.startsWith('WHERE ')) {
          inner = inner.substring('WHERE '.length);
        }
        sqlHelper.addSqlSnippetWithValues(inner, subHelper.getValues());
      }
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.where) {
      sqlHelper.addSqlSnippet(
          quoteIdentifier(cur.tableNameOrAlias, config.identifierDelimiters));
      sqlHelper.addSqlSnippet('.');
      sqlHelper.addSqlSnippet(
          quoteIdentifier(cur.columnName, config.identifierDelimiters));
      sqlHelper.addSqlSnippet(' ');

      switch (cur.whereOperator) {
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
        case WhereOperator.none:
          break;
      }

      sqlHelper.addSqlSnippet(' ');
      sqlHelper.addDynamicValue(cur.values[0]);
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.whereBetween) {
      sqlHelper.addSqlSnippet(
          quoteIdentifier(cur.tableNameOrAlias, config.identifierDelimiters));
      sqlHelper.addSqlSnippet('.');
      sqlHelper.addSqlSnippet(
          quoteIdentifier(cur.columnName, config.identifierDelimiters));
      sqlHelper.addSqlSnippet(' ');
      sqlHelper.addSqlSnippet('BETWEEN ');
      sqlHelper.addDynamicValue(cur.values[0]);
      sqlHelper.addSqlSnippet(' AND ');
      sqlHelper.addDynamicValue(cur.values[1]);
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.whereExistsBuilder) {
      sqlHelper.addSqlSnippet('EXISTS (');
      final subHelper = defaultToSql(cur.subquery, config, mode);
      sqlHelper.addSqlSnippetWithValues(
          subHelper.getSql(), subHelper.getValues());
      sqlHelper.addSqlSnippet(')');
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.whereInBuilder) {
      sqlHelper.addSqlSnippet(
          quoteIdentifier(cur.tableNameOrAlias, config.identifierDelimiters));
      sqlHelper.addSqlSnippet('.');
      sqlHelper.addSqlSnippet(
          quoteIdentifier(cur.columnName, config.identifierDelimiters));
      sqlHelper.addSqlSnippet(' IN (');
      final subHelper = defaultToSql(cur.subquery, config, mode);
      sqlHelper.addSqlSnippetWithValues(
          subHelper.getSql(), subHelper.getValues());
      sqlHelper.addSqlSnippet(')');
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.whereInValues) {
      // `IN ()` is a syntax error in every dialect. An empty list means "match nothing", but
      // silently rewriting it would hide a caller bug, so refuse it.
      if (cur.values.isEmpty) {
        throw ParserError(ParserArea.where, 'IN requires at least one value');
      }

      sqlHelper.addSqlSnippet(
          quoteIdentifier(cur.tableNameOrAlias, config.identifierDelimiters));
      sqlHelper.addSqlSnippet('.');
      sqlHelper.addSqlSnippet(
          quoteIdentifier(cur.columnName, config.identifierDelimiters));
      sqlHelper.addSqlSnippet(' IN (');

      for (var j = 0; j < cur.values.length; j++) {
        sqlHelper.addDynamicValue(cur.values[j]);
        if (j < cur.values.length - 1) {
          sqlHelper.addSqlSnippet(', ');
        }
      }

      sqlHelper.addSqlSnippet(')');
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.whereNotExistsBuilder) {
      sqlHelper.addSqlSnippet('NOT EXISTS (');
      final subHelper = defaultToSql(cur.subquery, config, mode);
      sqlHelper.addSqlSnippetWithValues(
          subHelper.getSql(), subHelper.getValues());
      sqlHelper.addSqlSnippet(')');
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.whereNotInBuilder) {
      sqlHelper.addSqlSnippet(
          quoteIdentifier(cur.tableNameOrAlias, config.identifierDelimiters));
      sqlHelper.addSqlSnippet('.');
      sqlHelper.addSqlSnippet(
          quoteIdentifier(cur.columnName, config.identifierDelimiters));
      sqlHelper.addSqlSnippet(' NOT IN (');
      final subHelper = defaultToSql(cur.subquery, config, mode);
      sqlHelper.addSqlSnippetWithValues(
          subHelper.getSql(), subHelper.getValues());
      sqlHelper.addSqlSnippet(')');
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.whereNotInValues) {
      // See whereInValues above — `NOT IN ()` is equally invalid.
      if (cur.values.isEmpty) {
        throw ParserError(
            ParserArea.where, 'NOT IN requires at least one value');
      }

      sqlHelper.addSqlSnippet(
          quoteIdentifier(cur.tableNameOrAlias, config.identifierDelimiters));
      sqlHelper.addSqlSnippet('.');
      sqlHelper.addSqlSnippet(
          quoteIdentifier(cur.columnName, config.identifierDelimiters));
      sqlHelper.addSqlSnippet(' NOT IN (');

      for (var j = 0; j < cur.values.length; j++) {
        sqlHelper.addDynamicValue(cur.values[j]);
        if (j < cur.values.length - 1) {
          sqlHelper.addSqlSnippet(', ');
        }
      }

      sqlHelper.addSqlSnippet(')');
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.whereNotNull) {
      sqlHelper.addSqlSnippet(
          quoteIdentifier(cur.tableNameOrAlias, config.identifierDelimiters));
      sqlHelper.addSqlSnippet('.');
      sqlHelper.addSqlSnippet(
          quoteIdentifier(cur.columnName, config.identifierDelimiters));
      sqlHelper.addSqlSnippet(' IS NOT NULL');
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.whereNull) {
      sqlHelper.addSqlSnippet(
          quoteIdentifier(cur.tableNameOrAlias, config.identifierDelimiters));
      sqlHelper.addSqlSnippet('.');
      sqlHelper.addSqlSnippet(
          quoteIdentifier(cur.columnName, config.identifierDelimiters));
      sqlHelper.addSqlSnippet(' IS NULL');
      spaceAfter();
      continue;
    }
  }

  return sqlHelper;
}
