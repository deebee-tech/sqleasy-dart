import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';
import 'default_join.dart';
import 'to_sql.dart';

void assertMutationJoinsSupported(
  QueryState state,
  Dialect config,
  ParserArea area,
) {
  if (state.joinStates.isEmpty) {
    return;
  }

  if (config.databaseType == DatabaseType.sqlite) {
    throw ParserError(
      area,
      'SQLite does not support joins in UPDATE/DELETE; rewrite the join as a correlated subquery',
    );
  }
}

void _emitPostgresFromItem(
  SqlHelper sqlHelper,
  Dialect config,
  ParserMode mode,
  ToSqlOptions? options,
  JoinState joinState,
  ParserArea area,
) {
  if (joinState.builderType == BuilderType.joinRaw) {
    throw ParserError(
      area,
      'Raw JOIN fragments are not supported in a Postgres join-backed UPDATE/DELETE; use a raw WHERE/FROM instead',
    );
  }

  if (joinState.joinType != JoinType.inner &&
      joinState.joinType != JoinType.cross) {
    throw ParserError(
      area,
      'Postgres UPDATE...FROM/DELETE...USING only supports INNER or CROSS joins — the ON condition '
      'is translated into a WHERE predicate, which cannot express OUTER JOIN semantics',
    );
  }

  if (joinState.builderType == BuilderType.joinTable) {
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

    return;
  }

  final subHelper = defaultToSql(joinState.subquery, config, mode, options);
  sqlHelper.addSqlSnippetWithValues(
      '(${subHelper.getSql()})', subHelper.getValues());

  if ((joinState.alias ?? '').isNotEmpty) {
    sqlHelper.addSqlSnippet(' AS ');
    sqlHelper.addSqlSnippet(
        quoteIdentifier(joinState.alias, config.identifierDelimiters));
  }
}

SqlHelper renderPostgresMutationFrom(
  Dialect config,
  QueryState state,
  ParserMode mode,
  ToSqlOptions? options,
  ParserArea area,
) {
  final sqlHelper = SqlHelper(mode);

  for (var i = 0; i < state.joinStates.length; i++) {
    _emitPostgresFromItem(
        sqlHelper, config, mode, options, state.joinStates[i], area);

    if (i < state.joinStates.length - 1) {
      sqlHelper.addSqlSnippet(', ');
    }
  }

  return sqlHelper;
}

SqlHelper buildPostgresMutationJoinPredicate(
  Dialect config,
  QueryState state,
  ParserMode mode,
) {
  final sqlHelper = SqlHelper(mode);
  var wroteAny = false;

  for (final joinState in state.joinStates) {
    if (joinState.joinType == JoinType.cross ||
        joinState.joinOnStates.isEmpty) {
      continue;
    }

    if (wroteAny) {
      sqlHelper.addSqlSnippet(' AND ');
    }

    final wrapInParens = joinState.joinOnStates.length > 1;
    if (wrapInParens) {
      sqlHelper.addSqlSnippet('(');
    }

    renderJoinOnConditions(sqlHelper, config, joinState.joinOnStates);

    if (wrapInParens) {
      sqlHelper.addSqlSnippet(')');
    }

    wroteAny = true;
  }

  return sqlHelper;
}
