import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';
import 'to_sql.dart';

SqlHelper defaultJoin(
  QueryState state,
  Dialect config,
  ParserMode mode, [
  ToSqlOptions? options,
]) {
  final sqlHelper = SqlHelper(mode);

  if (state.joinStates.isEmpty) {
    return sqlHelper;
  }

  for (var i = 0; i < state.joinStates.length; i++) {
    final joinState = state.joinStates[i];

    if (joinState.builderType == BuilderType.joinRaw) {
      sqlHelper.addSqlSnippet(joinState.raw ?? '');
      if (i < state.joinStates.length - 1) {
        sqlHelper.addSqlSnippet(' ');
      }
      continue;
    }

    switch (joinState.joinType) {
      case JoinType.inner:
        sqlHelper.addSqlSnippet('INNER JOIN ');
      case JoinType.left:
        sqlHelper.addSqlSnippet('LEFT JOIN ');
      case JoinType.leftOuter:
        sqlHelper.addSqlSnippet('LEFT OUTER JOIN ');
      case JoinType.right:
        sqlHelper.addSqlSnippet('RIGHT JOIN ');
      case JoinType.rightOuter:
        sqlHelper.addSqlSnippet('RIGHT OUTER JOIN ');
      case JoinType.fullOuter:
        if (config.databaseType == DatabaseType.mysql) {
          throw ParserError(
            ParserArea.join,
            'MySQL does not support FULL OUTER JOIN',
          );
        }
        sqlHelper.addSqlSnippet('FULL OUTER JOIN ');
      case JoinType.cross:
        sqlHelper.addSqlSnippet('CROSS JOIN ');
      case JoinType.none:
        break;
    }

    if (joinState.builderType == BuilderType.joinTable) {
      if ((joinState.owner ?? '').isNotEmpty &&
          config.databaseType == DatabaseType.mysql) {
        throw ParserError(
            ParserArea.join, 'MySQL does not support table owners');
      }

      if ((joinState.owner ?? '').isNotEmpty) {
        sqlHelper.addSqlSnippet(
            quoteIdentifier(joinState.owner, config.identifierDelimiters));
        sqlHelper.addSqlSnippet('.');
      }

      sqlHelper.addSqlSnippet(
          quoteIdentifier(joinState.tableName, config.identifierDelimiters));

      if ((joinState.alias ?? '').isNotEmpty) {
        sqlHelper.addSqlSnippet(' AS ');
        sqlHelper.addSqlSnippet(
            quoteIdentifier(joinState.alias, config.identifierDelimiters));
      }

      _defaultJoinOns(sqlHelper, config, joinState.joinOnStates);

      if (i < state.joinStates.length - 1) {
        sqlHelper.addSqlSnippet(' ');
      }

      continue;
    }

    if (joinState.builderType == BuilderType.joinBuilder) {
      final subHelper = defaultToSql(joinState.subquery, config, mode, options);

      sqlHelper.addSqlSnippetWithValues(
          '(${subHelper.getSql()})', subHelper.getValues());

      if ((joinState.alias ?? '').isNotEmpty) {
        sqlHelper.addSqlSnippet(' AS ');
        sqlHelper.addSqlSnippet(
            quoteIdentifier(joinState.alias, config.identifierDelimiters));
      }

      _defaultJoinOns(sqlHelper, config, joinState.joinOnStates);

      if (i < state.joinStates.length - 1) {
        sqlHelper.addSqlSnippet(' ');
      }
    }
  }

  return sqlHelper;
}

void _defaultJoinOns(
  SqlHelper sqlHelper,
  Dialect config,
  List<JoinOnState> joinOnStates,
) {
  if (joinOnStates.isEmpty) {
    return;
  }

  sqlHelper.addSqlSnippet(' ON ');

  for (var i = 0; i < joinOnStates.length; i++) {
    final on = joinOnStates[i];
    final prevOn = i > 0 ? joinOnStates[i - 1] : null;
    final nextOn = i < joinOnStates.length - 1 ? joinOnStates[i + 1] : null;

    // Separator after a condition — but never immediately before a `)`. Mirrors `defaultWhere`.
    void spaceAfter() {
      if (i < joinOnStates.length - 1 &&
          nextOn?.joinOnOperator != JoinOnOperator.groupEnd) {
        sqlHelper.addSqlSnippet(' ');
      }
    }

    if (i == 0 &&
        (on.joinOnOperator == JoinOnOperator.and ||
            on.joinOnOperator == JoinOnOperator.or)) {
      throw ParserError(
          ParserArea.join, 'First JOIN ON operator cannot be AND or OR');
    }

    if (i == joinOnStates.length - 1 &&
        (on.joinOnOperator == JoinOnOperator.and ||
            on.joinOnOperator == JoinOnOperator.or)) {
      throw ParserError(ParserArea.join,
          'AND or OR cannot be used as the last JOIN ON operator');
    }

    if ((on.joinOnOperator == JoinOnOperator.and ||
            on.joinOnOperator == JoinOnOperator.or) &&
        (prevOn?.joinOnOperator == JoinOnOperator.and ||
            prevOn?.joinOnOperator == JoinOnOperator.or)) {
      throw ParserError(
          ParserArea.join, 'AND or OR cannot be used consecutively');
    }

    if ((on.joinOnOperator == JoinOnOperator.and ||
            on.joinOnOperator == JoinOnOperator.or) &&
        prevOn?.joinOnOperator == JoinOnOperator.groupBegin) {
      throw ParserError(ParserArea.join,
          'AND or OR cannot be used directly after a group begin');
    }

    if (on.joinOnOperator == JoinOnOperator.groupBegin &&
        i == joinOnStates.length - 1) {
      throw ParserError(
          ParserArea.join, 'Group begin cannot be the last JOIN ON operator');
    }

    if (on.joinOnOperator == JoinOnOperator.groupEnd && i == 0) {
      throw ParserError(
          ParserArea.join, 'Group end cannot be the first JOIN ON operator');
    }

    if (on.joinOnOperator == JoinOnOperator.and) {
      sqlHelper.addSqlSnippet('AND');
      spaceAfter();
      continue;
    }

    if (on.joinOnOperator == JoinOnOperator.or) {
      sqlHelper.addSqlSnippet('OR');
      spaceAfter();
      continue;
    }

    if (on.joinOnOperator == JoinOnOperator.groupBegin) {
      sqlHelper.addSqlSnippet('(');
      continue;
    }

    if (on.joinOnOperator == JoinOnOperator.groupEnd) {
      sqlHelper.addSqlSnippet(')');
      spaceAfter();
      continue;
    }

    if (on.joinOnOperator == JoinOnOperator.raw) {
      sqlHelper.addSqlSnippet(on.raw ?? '');
      spaceAfter();
      continue;
    }

    if (on.joinOnOperator == JoinOnOperator.on) {
      sqlHelper.addSqlSnippet(
          quoteIdentifier(on.aliasLeft, config.identifierDelimiters));
      sqlHelper.addSqlSnippet('.');
      sqlHelper.addSqlSnippet(
          quoteIdentifier(on.columnLeft, config.identifierDelimiters));

      sqlHelper.addSqlSnippet(' ');

      _appendJoinOperator(sqlHelper, on.joinOperator);

      sqlHelper.addSqlSnippet(' ');

      sqlHelper.addSqlSnippet(
          quoteIdentifier(on.aliasRight, config.identifierDelimiters));
      sqlHelper.addSqlSnippet('.');
      sqlHelper.addSqlSnippet(
          quoteIdentifier(on.columnRight, config.identifierDelimiters));

      spaceAfter();
      continue;
    }

    if (on.joinOnOperator == JoinOnOperator.value) {
      sqlHelper.addSqlSnippet(
          quoteIdentifier(on.aliasLeft, config.identifierDelimiters));
      sqlHelper.addSqlSnippet('.');
      sqlHelper.addSqlSnippet(
          quoteIdentifier(on.columnLeft, config.identifierDelimiters));

      sqlHelper.addSqlSnippet(' ');

      _appendJoinOperator(sqlHelper, on.joinOperator);

      sqlHelper.addSqlSnippet(' ');

      sqlHelper.addDynamicValue(on.valueRight);

      spaceAfter();
      continue;
    }
  }
}

void _appendJoinOperator(SqlHelper sqlHelper, JoinOperator op) {
  switch (op) {
    case JoinOperator.equals:
      sqlHelper.addSqlSnippet('=');
    case JoinOperator.notEquals:
      sqlHelper.addSqlSnippet('<>');
    case JoinOperator.greaterThan:
      sqlHelper.addSqlSnippet('>');
    case JoinOperator.greaterThanOrEquals:
      sqlHelper.addSqlSnippet('>=');
    case JoinOperator.lessThan:
      sqlHelper.addSqlSnippet('<');
    case JoinOperator.lessThanOrEquals:
      sqlHelper.addSqlSnippet('<=');
    case JoinOperator.none:
      break;
  }
}
