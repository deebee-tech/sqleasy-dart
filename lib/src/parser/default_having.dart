import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';
import 'comparison_operator.dart';
import 'default_json_predicate.dart';
import 'to_sql.dart';

/// HAVING mirrors WHERE's predicate set exactly (BETWEEN, IN, NULL checks, EXISTS, groups) — see
/// `default_where.dart`, whose combinator/spacing rules this file follows term for term.
const _havingPredicateTypes = {
  BuilderType.having,
  BuilderType.havingRaw,
  BuilderType.havingBetween,
  BuilderType.havingExistsBuilder,
  BuilderType.havingInBuilder,
  BuilderType.havingInValues,
  BuilderType.havingNotExistsBuilder,
  BuilderType.havingNotInBuilder,
  BuilderType.havingNotInValues,
  BuilderType.havingNotNull,
  BuilderType.havingNull,
  BuilderType.havingJsonExtract,
  BuilderType.havingJsonContains,
  BuilderType.havingFullText,
};

bool _isHavingPredicate(HavingState state) =>
    _havingPredicateTypes.contains(state.builderType);

/// True when the prior token ends an expression that can be AND-joined to the next.
bool _endsHavingExpression(HavingState state) =>
    _isHavingPredicate(state) ||
    state.builderType == BuilderType.havingGroupEnd;

/// True when the current token starts an expression that can follow an auto-AND.
bool _startsHavingExpression(HavingState state) =>
    _isHavingPredicate(state) ||
    state.builderType == BuilderType.havingGroupBegin;

SqlHelper defaultHaving(
  QueryState state,
  Dialect config,
  ParserMode mode, [
  ToSqlOptions? options,
]) {
  final sqlHelper = SqlHelper(mode);

  if (state.havingStates.isEmpty) {
    return sqlHelper;
  }

  if (state.groupByStates.isEmpty) {
    throw ParserError(ParserArea.having, 'HAVING requires a GROUP BY clause');
  }

  sqlHelper.addSqlSnippet('HAVING ');

  for (var i = 0; i < state.havingStates.length; i++) {
    final cur = state.havingStates[i];
    final prev = i > 0 ? state.havingStates[i - 1] : null;
    final next =
        i < state.havingStates.length - 1 ? state.havingStates[i + 1] : null;
    void spaceAfter() {
      if (i < state.havingStates.length - 1 &&
          next?.builderType != BuilderType.havingGroupEnd) {
        sqlHelper.addSqlSnippet(' ');
      }
    }

    if (i == 0 &&
        (cur.builderType == BuilderType.and ||
            cur.builderType == BuilderType.or)) {
      throw ParserError(
          ParserArea.having, 'First HAVING operator cannot be AND or OR');
    }

    if (i == state.havingStates.length - 1 &&
        (cur.builderType == BuilderType.and ||
            cur.builderType == BuilderType.or)) {
      throw ParserError(ParserArea.having,
          'AND or OR cannot be used as the last HAVING operator');
    }

    if ((cur.builderType == BuilderType.and ||
            cur.builderType == BuilderType.or) &&
        (prev?.builderType == BuilderType.and ||
            prev?.builderType == BuilderType.or)) {
      throw ParserError(
          ParserArea.having, 'AND or OR cannot be used consecutively');
    }

    if ((cur.builderType == BuilderType.and ||
            cur.builderType == BuilderType.or) &&
        prev?.builderType == BuilderType.havingGroupBegin) {
      throw ParserError(ParserArea.having,
          'AND or OR cannot be used directly after a group begin');
    }

    if (cur.builderType == BuilderType.havingGroupBegin &&
        i == state.havingStates.length - 1) {
      throw ParserError(
          ParserArea.having, 'Group begin cannot be the last HAVING operator');
    }

    if (cur.builderType == BuilderType.havingGroupEnd && i == 0) {
      throw ParserError(
          ParserArea.having, 'Group end cannot be the first HAVING operator');
    }

    if (cur.builderType == BuilderType.and) {
      sqlHelper.addSqlSnippet('AND');
      if (i < state.havingStates.length - 1) {
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
        _endsHavingExpression(prev) &&
        _startsHavingExpression(cur)) {
      sqlHelper.addSqlSnippet('AND ');
    }

    if (cur.builderType == BuilderType.havingGroupBegin) {
      sqlHelper.addSqlSnippet('(');
      continue;
    }

    if (cur.builderType == BuilderType.havingGroupEnd) {
      sqlHelper.addSqlSnippet(')');
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.havingRaw) {
      sqlHelper.addSqlSnippet(cur.raw ?? '');
      spaceAfter();
      continue;
    }

    // A grouped sub-expression: render the sub-builder's predicates inside the ( ) that the
    // surrounding HavingGroupBegin/End emit, carrying its bound values up in order.
    if (cur.builderType == BuilderType.havingGroupBuilder) {
      if (cur.subquery == null || cur.subquery!.havingStates.isEmpty) {
        throw ParserError(ParserArea.having, 'HAVING group cannot be empty');
      }
      final subState = QueryState()
        ..havingStates = cur.subquery!.havingStates
        ..groupByStates = state.groupByStates;
      final subHelper = defaultHaving(subState, config, mode);
      var inner = subHelper.getSql();
      if (inner.startsWith('HAVING ')) {
        inner = inner.substring('HAVING '.length);
      }
      if (inner.trim().isEmpty) {
        throw ParserError(ParserArea.having, 'HAVING group cannot be empty');
      }
      sqlHelper.addSqlSnippetWithValues(inner, subHelper.getValues());
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.having) {
      final columnSql =
          '${quoteIdentifier(cur.tableNameOrAlias, config.identifierDelimiters)}.'
          '${quoteIdentifier(cur.columnName, config.identifierDelimiters)}';

      final value = cur.values.isNotEmpty ? cur.values[0] : null;

      emitComparisonPredicate(sqlHelper, config, columnSql, cur.whereOperator,
          value, ParserArea.having);
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.havingBetween) {
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

    if (cur.builderType == BuilderType.havingExistsBuilder) {
      sqlHelper.addSqlSnippet('EXISTS (');
      final subHelper = defaultToSql(cur.subquery, config, mode, options);
      sqlHelper.addSqlSnippetWithValues(
          subHelper.getSql(), subHelper.getValues());
      sqlHelper.addSqlSnippet(')');
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.havingInBuilder) {
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

    if (cur.builderType == BuilderType.havingInValues) {
      // `IN ()` is a syntax error in every dialect — see WHERE's identical guard.
      if (cur.values.isEmpty) {
        throw ParserError(ParserArea.having, 'IN requires at least one value');
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

    if (cur.builderType == BuilderType.havingNotExistsBuilder) {
      sqlHelper.addSqlSnippet('NOT EXISTS (');
      final subHelper = defaultToSql(cur.subquery, config, mode, options);
      sqlHelper.addSqlSnippetWithValues(
          subHelper.getSql(), subHelper.getValues());
      sqlHelper.addSqlSnippet(')');
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.havingNotInBuilder) {
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

    if (cur.builderType == BuilderType.havingNotInValues) {
      // See HavingInValues above — `NOT IN ()` is equally invalid.
      if (cur.values.isEmpty) {
        throw ParserError(
            ParserArea.having, 'NOT IN requires at least one value');
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

    if (cur.builderType == BuilderType.havingNotNull) {
      sqlHelper.addSqlSnippet(
          quoteIdentifier(cur.tableNameOrAlias, config.identifierDelimiters));
      sqlHelper.addSqlSnippet('.');
      sqlHelper.addSqlSnippet(
          quoteIdentifier(cur.columnName, config.identifierDelimiters));
      sqlHelper.addSqlSnippet(' IS NOT NULL');
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.havingNull) {
      sqlHelper.addSqlSnippet(
          quoteIdentifier(cur.tableNameOrAlias, config.identifierDelimiters));
      sqlHelper.addSqlSnippet('.');
      sqlHelper.addSqlSnippet(
          quoteIdentifier(cur.columnName, config.identifierDelimiters));
      sqlHelper.addSqlSnippet(' IS NULL');
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.havingJsonExtract) {
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
        area: ParserArea.having,
      );
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.havingJsonContains) {
      emitJsonContainsPredicate(
        sqlHelper,
        config,
        tableNameOrAlias: cur.tableNameOrAlias,
        columnName: cur.columnName,
        values: cur.values,
        area: ParserArea.having,
      );
      spaceAfter();
      continue;
    }

    if (cur.builderType == BuilderType.havingFullText) {
      emitFullTextMatchPredicate(
        sqlHelper,
        config,
        cur.fullTextColumns ?? [],
        cur.fullTextMode ?? FullTextMode.natural,
        cur.values.isNotEmpty ? cur.values[0] : null,
        ParserArea.having,
      );
      spaceAfter();
      continue;
    }
  }

  return sqlHelper;
}
