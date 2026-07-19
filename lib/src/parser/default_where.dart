import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';
import 'comparison_operator.dart';
import 'default_json_predicate.dart';
import 'to_sql.dart';

const _wherePredicateTypes = {
  BuilderType.where,
  BuilderType.whereRaw,
  BuilderType.whereBetween,
  BuilderType.whereExistsBuilder,
  BuilderType.whereInBuilder,
  BuilderType.whereInValues,
  BuilderType.whereNotExistsBuilder,
  BuilderType.whereNotInBuilder,
  BuilderType.whereNotInValues,
  BuilderType.whereNotNull,
  BuilderType.whereNull,
  BuilderType.whereJsonExtract,
  BuilderType.whereJsonContains,
  BuilderType.whereFullText,
};

bool _isWherePredicate(WhereState state) =>
    _wherePredicateTypes.contains(state.builderType);

/// True when the prior token ends an expression that can be AND-joined to the next.
bool _endsWhereExpression(WhereState state) =>
    _isWherePredicate(state) || state.builderType == BuilderType.whereGroupEnd;

/// True when the current token starts an expression that can follow an auto-AND.
bool _startsWhereExpression(WhereState state) =>
    _isWherePredicate(state) ||
    state.builderType == BuilderType.whereGroupBegin;

SqlHelper defaultWhere(
  QueryState state,
  Dialect config,
  ParserMode mode, [
  ToSqlOptions? options,
]) {
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

    // Consecutive predicates / groups without an explicit AND/OR are joined with AND.
    if (i > 0 &&
        prev != null &&
        _endsWhereExpression(prev) &&
        _startsWhereExpression(cur)) {
      sqlHelper.addSqlSnippet('AND ');
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
      if (cur.subquery == null || cur.subquery!.whereStates.isEmpty) {
        throw ParserError(ParserArea.where, 'WHERE group cannot be empty');
      }
      final subHelper = defaultWhere(cur.subquery!, config, mode);
      var inner = subHelper.getSql();
      if (inner.startsWith('WHERE ')) {
        inner = inner.substring('WHERE '.length);
      }
      if (inner.trim().isEmpty) {
        throw ParserError(ParserArea.where, 'WHERE group cannot be empty');
      }
      sqlHelper.addSqlSnippetWithValues(inner, subHelper.getValues());
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.where) {
      final columnSql =
          '${quoteIdentifier(cur.tableNameOrAlias, config.identifierDelimiters)}.'
          '${quoteIdentifier(cur.columnName, config.identifierDelimiters)}';

      final value = cur.values.isNotEmpty ? cur.values[0] : null;

      emitComparisonPredicate(sqlHelper, config, columnSql, cur.whereOperator,
          value, ParserArea.where);
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
      final subHelper = defaultToSql(cur.subquery, config, mode, options);
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
      final subHelper = defaultToSql(cur.subquery, config, mode, options);
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
      final subHelper = defaultToSql(cur.subquery, config, mode, options);
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
      final subHelper = defaultToSql(cur.subquery, config, mode, options);
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

    if (cur.builderType == BuilderType.whereJsonExtract) {
      emitJsonExtractPredicate(
        sqlHelper,
        config,
        mode,
        tableNameOrAlias: cur.tableNameOrAlias,
        columnName: cur.columnName,
        jsonPath: cur.jsonPath,
        jsonExtractMode: cur.jsonExtractMode,
        whereOperator: cur.whereOperator,
        values: cur.values,
        area: ParserArea.where,
      );
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.whereJsonContains) {
      emitJsonContainsPredicate(
        sqlHelper,
        config,
        tableNameOrAlias: cur.tableNameOrAlias,
        columnName: cur.columnName,
        values: cur.values,
        area: ParserArea.where,
      );
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.whereFullText) {
      emitFullTextMatchPredicate(
        sqlHelper,
        config,
        cur.fullTextColumns ?? [],
        cur.fullTextMode ?? FullTextMode.natural,
        cur.values.isNotEmpty ? cur.values[0] : null,
        ParserArea.where,
      );
      spaceAfter();
      continue;
    }
  }

  return sqlHelper;
}
