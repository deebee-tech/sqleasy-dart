/// Renders a [QueryState] to SQL by walking its clauses in order.
library;

import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../sql_helper.dart';
import '../state.dart';
import '../values/mssql_parameter.dart';
import '../values/sql_value.dart';
import 'default_call.dart';
import 'default_cte.dart';
import 'default_delete.dart';
import 'default_from.dart';
import 'default_group_by.dart';
import 'default_having.dart';
import 'default_insert.dart';
import 'default_join.dart';
import 'default_limit_offset.dart';
import 'default_mutation_join.dart';
import 'default_order_by.dart';
import 'default_returning.dart';
import 'default_row_lock.dart';
import 'default_select.dart';
import 'default_union.dart';
import 'default_update.dart';
import 'default_where.dart';
import 'default_hint.dart';

/// A prepared statement and the ordered values bound to its placeholders — ready to hand straight to
/// a driver as `query(sql, params)`. For dialects that inline values into a self-contained statement
/// (MSSQL's `sp_executesql`), [params] is empty.
class PreparedSql {
  const PreparedSql(this.sql, this.params);

  final String sql;
  final List<Object?> params;
}

/// A hook the dialect can inject into the shared clause walk (e.g. MSSQL's `TOP`).
typedef BeforeSelectColumns = void Function(
    QueryState state, Dialect config, SqlHelper sqlHelper);

/// Hooks the dialect can inject into the shared clause walk.
class ToSqlOptions {
  const ToSqlOptions({this.beforeSelectColumns});

  final BeforeSelectColumns? beforeSelectColumns;
}

void _emitMutationWhere(
  SqlHelper sqlHelper,
  QueryState state,
  Dialect config,
  ParserMode mode, [
  ToSqlOptions? options,
]) {
  final joinPredicate = state.joinStates.isNotEmpty &&
          config.databaseType == DatabaseType.postgres
      ? buildPostgresMutationJoinPredicate(config, state, mode)
      : null;

  if (joinPredicate == null || joinPredicate.getSql().isEmpty) {
    if (state.whereStates.isNotEmpty) {
      final where = defaultWhere(state, config, mode, options);
      sqlHelper.addSqlSnippet(' ');
      sqlHelper.addSqlSnippetWithValues(where.getSql(), where.getValues());
    }
    return;
  }

  sqlHelper.addSqlSnippet(' WHERE ');
  sqlHelper.addSqlSnippetWithValues(
      joinPredicate.getSql(), joinPredicate.getValues());

  if (state.whereStates.isNotEmpty) {
    final where = defaultWhere(state, config, mode, options);
    var whereSql = where.getSql();
    if (whereSql.startsWith('WHERE ')) {
      whereSql = whereSql.substring('WHERE '.length);
    }
    sqlHelper.addSqlSnippet(' AND ');
    sqlHelper.addSqlSnippetWithValues(whereSql, where.getValues());
  }
}

/// Renders a [QueryState] to SQL by walking its clauses in order. Pure and dialect-driven. Used for
/// the outer statement and, recursively, for every nested subquery.
SqlHelper defaultToSql(
  QueryState? state,
  Dialect config,
  ParserMode mode, [
  ToSqlOptions? options,
]) {
  final sqlHelper = SqlHelper(mode);

  if (state == null) {
    throw ParserError(ParserArea.general, 'No state provided');
  }

  if (state.cteStates.isNotEmpty) {
    final cte = defaultCte(state, config, mode, options);
    sqlHelper.addSqlSnippetWithValues(cte.getSql(), cte.getValues());
  }

  if (state.rowLock != null && state.queryType != QueryType.select) {
    throw ParserError(
        ParserArea.general, 'FOR UPDATE/FOR SHARE requires a SELECT query');
  }

  if (state.upsertState != null && state.queryType != QueryType.insert) {
    throw ParserError(
        ParserArea.insert, 'Upsert (ON CONFLICT) requires INSERT');
  }

  if (state.callState != null && state.queryType != QueryType.call) {
    throw ParserError(ParserArea.call,
        'Procedure/function call state requires queryType Call');
  }

  if (state.queryType == QueryType.call) {
    if (state.cteStates.isNotEmpty) {
      throw ParserError(ParserArea.call,
          'A CTE cannot be combined with a procedure/function call');
    }

    if (state.returningState != null) {
      throw ParserError(ParserArea.call,
          'RETURNING/OUTPUT cannot be combined with a procedure/function call');
    }

    final call = defaultCall(state, config, mode);
    sqlHelper.addSqlSnippetWithValues(call.getSql(), call.getValues());

    if (!state.isInnerStatement) {
      sqlHelper.addSqlSnippet(';');
    }
    return sqlHelper;
  }

  if (state.queryType == QueryType.insert) {
    final insert = defaultInsert(state, config, mode, options);
    sqlHelper.addSqlSnippetWithValues(insert.getSql(), insert.getValues());

    // PG/SQLite's RETURNING is trailing; MSSQL's OUTPUT was already emitted inline by
    // `defaultInsert` (before VALUES), and MySQL has no equivalent (`defaultReturning` throws).
    if (state.returningState != null &&
        config.databaseType != DatabaseType.mssql) {
      emitTrailingReturningClause(
          sqlHelper, config, state.returningState!, ParserArea.insert);
    }

    if (!state.isInnerStatement) {
      sqlHelper.addSqlSnippet(';');
    }
    return sqlHelper;
  }

  if (state.queryType == QueryType.update) {
    final update = defaultUpdate(state, config, mode, options);
    sqlHelper.addSqlSnippetWithValues(update.getSql(), update.getValues());

    if (state.whereStates.isNotEmpty || state.joinStates.isNotEmpty) {
      _emitMutationWhere(sqlHelper, state, config, mode, options);
    }

    if (state.returningState != null &&
        config.databaseType != DatabaseType.mssql) {
      emitTrailingReturningClause(
          sqlHelper, config, state.returningState!, ParserArea.update);
    }

    if (!state.isInnerStatement) {
      sqlHelper.addSqlSnippet(';');
    }
    return sqlHelper;
  }

  if (state.queryType == QueryType.delete) {
    final del = defaultDelete(state, config, mode, options);
    sqlHelper.addSqlSnippetWithValues(del.getSql(), del.getValues());

    if (state.whereStates.isNotEmpty || state.joinStates.isNotEmpty) {
      _emitMutationWhere(sqlHelper, state, config, mode, options);
    }

    if (state.returningState != null &&
        config.databaseType != DatabaseType.mssql) {
      emitTrailingReturningClause(
          sqlHelper, config, state.returningState!, ParserArea.delete);
    }

    if (!state.isInnerStatement) {
      sqlHelper.addSqlSnippet(';');
    }
    return sqlHelper;
  }

  if (state.returningState != null) {
    throw ParserError(ParserArea.general,
        'RETURNING/OUTPUT requires INSERT, UPDATE, or DELETE');
  }

  final sel = defaultSelect(state, config, mode, options);
  sqlHelper.addSqlSnippetWithValues(sel.getSql(), sel.getValues());

  final from = defaultFrom(state, config, mode, options);
  sqlHelper.addSqlSnippet(' ');
  sqlHelper.addSqlSnippetWithValues(from.getSql(), from.getValues());

  if (state.joinStates.isNotEmpty) {
    final join = defaultJoin(state, config, mode, options);
    sqlHelper.addSqlSnippet(' ');
    sqlHelper.addSqlSnippetWithValues(join.getSql(), join.getValues());
  }

  if (state.whereStates.isNotEmpty) {
    final where = defaultWhere(state, config, mode, options);
    sqlHelper.addSqlSnippet(' ');
    sqlHelper.addSqlSnippetWithValues(where.getSql(), where.getValues());
  }

  if (state.groupByStates.isNotEmpty) {
    final groupBy = defaultGroupBy(state, config, mode);
    sqlHelper.addSqlSnippet(' ');
    sqlHelper.addSqlSnippetWithValues(groupBy.getSql(), groupBy.getValues());
  }

  if (state.havingStates.isNotEmpty) {
    final having = defaultHaving(state, config, mode);
    sqlHelper.addSqlSnippet(' ');
    sqlHelper.addSqlSnippetWithValues(having.getSql(), having.getValues());
  }

  if (state.unionStates.isNotEmpty) {
    final union = defaultUnion(state, config, mode, options);
    sqlHelper.addSqlSnippet(' ');
    sqlHelper.addSqlSnippetWithValues(union.getSql(), union.getValues());
  }

  if (state.orderByStates.isNotEmpty) {
    final orderBy = defaultOrderBy(state, config, mode);
    sqlHelper.addSqlSnippet(' ');
    sqlHelper.addSqlSnippetWithValues(orderBy.getSql(), orderBy.getValues());
  }

  if (state.limit > 0 || state.offset > 0 || state.limitWithTies) {
    final limitOffset = defaultLimitOffset(state, config, mode);
    sqlHelper.addSqlSnippet(' ');
    sqlHelper.addSqlSnippetWithValues(
        limitOffset.getSql(), limitOffset.getValues());
  }

  if (state.limitWithTies &&
      config.databaseType == DatabaseType.mssql &&
      state.limit <= 0) {
    throw ParserError(
        ParserArea.limitOffset, 'limitWithTies requires a positive limit');
  }

  // Trailing `FOR UPDATE`/`FOR SHARE` (PG/MySQL). MSSQL's equivalent is a `WITH (...)` hint
  // already emitted on each FROM table by `defaultFrom`; SQLite has no row locking and throws.
  if (state.rowLock != null) {
    emitTrailingRowLockClause(sqlHelper, config, state.rowLock!);
  }

  validateHints(state, config, ParserArea.general);
  emitTrailingHints(sqlHelper, state, config);

  if (!state.isInnerStatement) {
    sqlHelper.addSqlSnippet(';');
  }

  return sqlHelper;
}

/// MSSQL prepends a `TOP` to the SELECT list for an explicit `.top(n)`. Other dialects need no hook.
///
/// There is deliberately no automatic cap here. SQLEasy emits the query it was asked for, however
/// unbounded — a row cap is the caller's policy, not the builder's, and one applied behind the
/// caller's back is a silent truncation they never wrote. `.top(n)` is the caller asking; it
/// conflicts with limit/offset outright, and [defaultLimitOffset] throws on that combination.
ToSqlOptions toSqlOptionsFor(Dialect config) {
  if (config.databaseType != DatabaseType.mssql) {
    return const ToSqlOptions();
  }

  return ToSqlOptions(
    beforeSelectColumns: (state, cfg, sqlHelper) {
      final top = state.customState?['top'];
      if (top is num && top > 0) {
        sqlHelper.addSqlSnippet('TOP ');
        sqlHelper.addSqlSnippet('(${formatNumber(top)})');
        sqlHelper.addSqlSnippet(' ');
      }
    },
  );
}

/// Wraps the rendered statement in a self-contained `exec sp_executesql`.
String _mssqlToSql(QueryState state, Dialect config) {
  final paramsString = SqlHelper(ParserMode.prepared);
  final finalString = SqlHelper(ParserMode.prepared);

  final sqlHelper =
      defaultToSql(state, config, ParserMode.prepared, toSqlOptionsFor(config));

  var sql = sqlHelper.getSql();
  sql = sql.replaceAll("'", "''");

  final values = sqlHelper.getValues();

  // Substitute by token, never by scanning for a bare `?`. The old scan rewrote the first `?` it
  // found — which, for `selectRaw("'why?' AS q")`, was the one inside the caller's string literal.
  sql = renderPlaceholders(sql, (index) => '@p$index');

  for (var index = 0; index < values.length; index++) {
    if (index > 0) {
      paramsString.addSqlSnippet(', ');
    }
    paramsString.addSqlSnippet('@p$index ${mssqlParameterType(values[index])}');
  }

  finalString.addSqlSnippet('SET NOCOUNT ON; ');
  finalString.addSqlSnippet("exec sp_executesql N'");
  finalString.addSqlSnippet(sql);
  finalString.addSqlSnippet("', N'");
  finalString.addSqlSnippet(paramsString.getSql());
  finalString.addSqlSnippet("'");

  // Only append the parameter-value list when there are parameters; otherwise a trailing `', ;` is
  // malformed sp_executesql syntax and SQL Server rejects the whole statement.
  if (values.isNotEmpty) {
    finalString.addSqlSnippet(', ');
    for (var i = 0; i < values.length; i++) {
      if (i > 0) {
        finalString.addSqlSnippet(', ');
      }
      finalString.addSqlSnippet('@p$i = ${mssqlParameterValue(values[i])}');
    }
  }

  finalString.addSqlSnippet(';');

  return finalString.getSql();
}

/// Postgres uses numbered `$n` placeholders: substitute the Nth token with `$1`, `$2`, … in order.
PreparedSql _postgresPrepared(QueryState state, Dialect config) {
  final sqlHelper = defaultToSql(state, config, ParserMode.prepared);
  // Use the dialect placeholder character as the `$n` prefix so the config field is not dead.
  final sql = renderPlaceholders(
    sqlHelper.getSql(),
    (index) => '${config.preparedStatementPlaceholder}${index + 1}',
  );
  return PreparedSql(sql, sqlHelper.getValues());
}

/// The dialect's own placeholder, substituted for each token. MySQL and SQLite bind positionally.
PreparedSql _positionalPrepared(QueryState state, Dialect config) {
  final sqlHelper = defaultToSql(state, config, ParserMode.prepared);
  final sql = renderPlaceholders(
    sqlHelper.getSql(),
    (index) => config.preparedStatementPlaceholder,
  );
  return PreparedSql(sql, sqlHelper.getValues());
}

/// Renders one query state as a prepared SQL string.
String parse(QueryState state, Dialect config) {
  if (config.databaseType == DatabaseType.mssql) {
    return _mssqlToSql(state, config);
  }
  if (config.databaseType == DatabaseType.postgres) {
    return _postgresPrepared(state, config).sql;
  }
  return _positionalPrepared(state, config).sql;
}

/// Renders one query state as prepared SQL plus its ordered bound values. MSSQL inlines its values
/// into the `sp_executesql` string, so its `params` is empty.
PreparedSql parsePrepared(QueryState state, Dialect config) {
  if (config.databaseType == DatabaseType.mssql) {
    return PreparedSql(_mssqlToSql(state, config), const []);
  }
  if (config.databaseType == DatabaseType.postgres) {
    return _postgresPrepared(state, config);
  }
  return _positionalPrepared(state, config);
}

/// Renders one query state as a raw SQL string with values inlined (MSSQL keeps its `TOP`). DEBUG /
/// TEST display only — NOT execution-safe.
String parseRaw(QueryState state, Dialect config) {
  final sqlHelper =
      defaultToSql(state, config, ParserMode.raw, toSqlOptionsFor(config));
  return sqlHelper.getSqlDebug();
}

/// Renders a batch of query states as a single prepared SQL string. Each statement is prepared
/// independently, so placeholder numbering restarts per statement.
String parseMulti(
  List<QueryState> states,
  MultiBuilderTransactionState transactionState,
  Dialect config,
) {
  var sql = '';

  if (transactionState == MultiBuilderTransactionState.transactionOn) {
    sql += '${config.transactionDelimiters.begin}; ';
  }

  for (final state in states) {
    sql += parse(state, config);
  }

  if (transactionState == MultiBuilderTransactionState.transactionOn) {
    sql += '${config.transactionDelimiters.end};';
  }

  return sql;
}

/// Renders a batch of query states as a single raw SQL string with values inlined. DEBUG / TEST only.
String parseMultiRaw(
  List<QueryState> states,
  MultiBuilderTransactionState transactionState,
  Dialect config,
) {
  var sql = '';

  if (transactionState == MultiBuilderTransactionState.transactionOn) {
    sql += '${config.transactionDelimiters.begin}; ';
  }

  for (final state in states) {
    sql += parseRaw(state, config);
  }

  if (transactionState == MultiBuilderTransactionState.transactionOn) {
    sql += '${config.transactionDelimiters.end};';
  }

  return sql;
}
