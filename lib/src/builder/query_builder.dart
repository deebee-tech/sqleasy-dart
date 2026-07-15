import '../configuration.dart';
import '../enums.dart';
import '../parser/to_sql.dart' as parser;
import '../parser/to_sql.dart' show PreparedSql;
import '../state.dart';
import 'join_on_builder.dart';

/// A column reference for [QueryBuilder.selectColumns].
typedef ColumnRef = ({String table, String column, String? alias});

/// A table reference for [QueryBuilder.fromTables].
typedef TableRef = ({String table, String? alias, String? owner});

/// A join specification for [QueryBuilder.joinTables].
typedef JoinRef = ({
  JoinType joinType,
  String table,
  String? alias,
  String? owner,
  void Function(JoinOnBuilder builder) on,
});

/// An ORDER BY column for [QueryBuilder.orderByColumns].
typedef OrderByRef = ({
  String table,
  String column,
  OrderByDirection direction
});

/// A GROUP BY column for [QueryBuilder.groupByColumns].
typedef GroupByRef = ({String table, String column});

/// A SET assignment for [QueryBuilder.setColumns].
typedef SetRef = ({String column, Object? value});

/// The single, dialect-agnostic fluent SQL builder for SELECT / INSERT / UPDATE / DELETE.
///
/// The injected [Dialect] carries everything dialect-specific, so one class serves every database.
/// Every mutator returns the builder, so it works with both chaining and Dart cascades. Obtain one
/// via a dialect entry point (e.g. `SqliteQuery().newBuilder()`).
///
/// This is the Dart port of the TypeScript `QueryBuilder`, reshaped to Dart conventions: "no alias"
/// and "no owner" are optional named parameters that default to absent, not empty-string sentinels.
class QueryBuilder {
  QueryBuilder(this._config);

  QueryState _state = QueryState();
  final Dialect _config;

  QueryBuilder _child() => QueryBuilder(_config);

  /// The dialect configuration backing this builder.
  Dialect get configuration => _config;

  /// The underlying mutable query state. Consumed by the parser and [MultiBuilder].
  QueryState get state => _state;

  // ---- logic / clearing ----------------------------------------------------------------------

  QueryBuilder and() {
    _state.whereStates.add(WhereState()..builderType = BuilderType.and);
    return this;
  }

  QueryBuilder or() {
    _state.whereStates.add(WhereState()..builderType = BuilderType.or);
    return this;
  }

  QueryBuilder distinct() {
    _state.distinct = true;
    return this;
  }

  QueryBuilder clearAll() {
    _state = QueryState();
    return this;
  }

  QueryBuilder clearFrom() {
    _state.fromStates = [];
    return this;
  }

  QueryBuilder clearGroupBy() {
    _state.groupByStates = [];
    return this;
  }

  QueryBuilder clearHaving() {
    _state.havingStates = [];
    return this;
  }

  QueryBuilder clearJoin() {
    _state.joinStates = [];
    return this;
  }

  QueryBuilder clearLimit() {
    _state.limit = 0;
    return this;
  }

  QueryBuilder clearOffset() {
    _state.offset = 0;
    return this;
  }

  QueryBuilder clearOrderBy() {
    _state.orderByStates = [];
    return this;
  }

  QueryBuilder clearSelect() {
    _state.selectStates = [];
    return this;
  }

  QueryBuilder clearWhere() {
    _state.whereStates = [];
    return this;
  }

  QueryBuilder clearTop() {
    _state.customState?.remove('top');
    return this;
  }

  // ---- SELECT --------------------------------------------------------------------------------

  QueryBuilder selectAll() {
    _state.selectStates.add(SelectState()..builderType = BuilderType.selectAll);
    return this;
  }

  QueryBuilder selectColumn(String table, String column, {String? alias}) {
    _state.selectStates.add(SelectState()
      ..builderType = BuilderType.selectColumn
      ..tableNameOrAlias = table
      ..columnName = column
      ..alias = alias);
    return this;
  }

  QueryBuilder selectColumns(List<ColumnRef> columns) {
    for (final c in columns) {
      selectColumn(c.table, c.column, alias: c.alias);
    }
    return this;
  }

  QueryBuilder selectRaw(String rawSelect) {
    _state.selectStates.add(SelectState()
      ..builderType = BuilderType.selectRaw
      ..raw = rawSelect);
    return this;
  }

  QueryBuilder selectRaws(List<String> rawSelects) {
    for (final r in rawSelects) {
      selectRaw(r);
    }
    return this;
  }

  QueryBuilder selectWithBuilder(
      String alias, void Function(QueryBuilder builder) builder) {
    final child = _child();
    builder(child);
    child.state.isInnerStatement = true;

    _state.selectStates.add(SelectState()
      ..builderType = BuilderType.selectBuilder
      ..alias = alias
      ..subquery = child.state);
    return this;
  }

  // ---- FROM ----------------------------------------------------------------------------------

  QueryBuilder fromTable(String table, {String? alias, String? owner}) {
    _state.fromStates.add(FromState()
      ..builderType = BuilderType.fromTable
      ..owner = owner ?? _config.defaultOwner
      ..tableName = table
      ..alias = alias);
    return this;
  }

  QueryBuilder fromTables(List<TableRef> tables) {
    for (final t in tables) {
      fromTable(t.table, alias: t.alias, owner: t.owner);
    }
    return this;
  }

  QueryBuilder fromRaw(String rawFrom) {
    _state.fromStates.add(FromState()
      ..builderType = BuilderType.fromRaw
      ..raw = rawFrom);
    return this;
  }

  QueryBuilder fromRaws(List<String> rawFroms) {
    for (final r in rawFroms) {
      fromRaw(r);
    }
    return this;
  }

  QueryBuilder fromWithBuilder(
      String alias, void Function(QueryBuilder builder) builder) {
    final child = _child();
    builder(child);
    child.state.isInnerStatement = true;

    _state.fromStates.add(FromState()
      ..builderType = BuilderType.fromBuilder
      ..alias = alias
      ..subquery = child.state);
    return this;
  }

  // ---- JOIN ----------------------------------------------------------------------------------

  QueryBuilder joinTable(
    JoinType joinType,
    String table,
    void Function(JoinOnBuilder builder) on, {
    String? alias,
    String? owner,
  }) {
    final joinOnBuilder = JoinOnBuilder(_config);
    on(joinOnBuilder);

    _state.joinStates.add(JoinState()
      ..builderType = BuilderType.joinTable
      ..joinType = joinType
      ..owner = owner ?? _config.defaultOwner
      ..tableName = table
      ..alias = alias
      ..joinOnStates = joinOnBuilder.states());
    return this;
  }

  QueryBuilder joinTables(List<JoinRef> joins) {
    for (final j in joins) {
      joinTable(j.joinType, j.table, j.on, alias: j.alias, owner: j.owner);
    }
    return this;
  }

  QueryBuilder joinWithBuilder(
    JoinType joinType,
    String alias,
    void Function(QueryBuilder builder) builder,
    void Function(JoinOnBuilder builder) on,
  ) {
    final child = _child();
    builder(child);
    child.state.isInnerStatement = true;

    final joinOnBuilder = JoinOnBuilder(_config);
    on(joinOnBuilder);

    _state.joinStates.add(JoinState()
      ..builderType = BuilderType.joinBuilder
      ..joinType = joinType
      ..alias = alias
      ..subquery = child.state
      ..joinOnStates = joinOnBuilder.states());
    return this;
  }

  QueryBuilder joinRaw(String rawJoin) {
    _state.joinStates.add(JoinState()
      ..builderType = BuilderType.joinRaw
      ..joinType = JoinType.none
      ..raw = rawJoin);
    return this;
  }

  QueryBuilder joinRaws(List<String> rawJoins) {
    for (final r in rawJoins) {
      joinRaw(r);
    }
    return this;
  }

  // ---- WHERE ---------------------------------------------------------------------------------

  QueryBuilder where(
      String table, String column, WhereOperator operator, Object? value) {
    _state.whereStates.add(WhereState()
      ..builderType = BuilderType.where
      ..tableNameOrAlias = table
      ..columnName = column
      ..whereOperator = operator
      ..values = [value]);
    return this;
  }

  QueryBuilder whereBetween(
      String table, String column, Object? from, Object? to) {
    _state.whereStates.add(WhereState()
      ..builderType = BuilderType.whereBetween
      ..tableNameOrAlias = table
      ..columnName = column
      ..whereOperator = WhereOperator.equals
      ..values = [from, to]);
    return this;
  }

  QueryBuilder whereInValues(
      String table, String column, List<Object?> values) {
    _state.whereStates.add(WhereState()
      ..builderType = BuilderType.whereInValues
      ..tableNameOrAlias = table
      ..columnName = column
      ..values = values);
    return this;
  }

  QueryBuilder whereNotInValues(
      String table, String column, List<Object?> values) {
    _state.whereStates.add(WhereState()
      ..builderType = BuilderType.whereNotInValues
      ..tableNameOrAlias = table
      ..columnName = column
      ..values = values);
    return this;
  }

  QueryBuilder whereNull(String table, String column) {
    _state.whereStates.add(WhereState()
      ..builderType = BuilderType.whereNull
      ..tableNameOrAlias = table
      ..columnName = column);
    return this;
  }

  QueryBuilder whereNotNull(String table, String column) {
    _state.whereStates.add(WhereState()
      ..builderType = BuilderType.whereNotNull
      ..tableNameOrAlias = table
      ..columnName = column);
    return this;
  }

  QueryBuilder whereRaw(String rawWhere) {
    _state.whereStates.add(WhereState()
      ..builderType = BuilderType.whereRaw
      ..raw = rawWhere);
    return this;
  }

  QueryBuilder whereRaws(List<String> rawWheres) {
    for (final r in rawWheres) {
      whereRaw(r);
    }
    return this;
  }

  QueryBuilder whereGroup(void Function(QueryBuilder builder) builder) {
    _state.whereStates
        .add(WhereState()..builderType = BuilderType.whereGroupBegin);

    final child = _child();
    builder(child);
    child.state.isInnerStatement = true;

    _state.whereStates.add(WhereState()
      ..builderType = BuilderType.whereGroupBuilder
      ..subquery = child.state);

    _state.whereStates.add(WhereState()
      ..builderType = BuilderType.whereGroupEnd
      ..subquery = child.state);
    return this;
  }

  QueryBuilder whereInWithBuilder(String table, String column,
      void Function(QueryBuilder builder) builder) {
    return _whereSubquery(BuilderType.whereInBuilder, table, column, builder);
  }

  QueryBuilder whereNotInWithBuilder(String table, String column,
      void Function(QueryBuilder builder) builder) {
    return _whereSubquery(
        BuilderType.whereNotInBuilder, table, column, builder);
  }

  QueryBuilder whereExistsWithBuilder(String table, String column,
      void Function(QueryBuilder builder) builder) {
    return _whereSubquery(
        BuilderType.whereExistsBuilder, table, column, builder);
  }

  QueryBuilder whereNotExistsWithBuilder(String table, String column,
      void Function(QueryBuilder builder) builder) {
    return _whereSubquery(
        BuilderType.whereNotExistsBuilder, table, column, builder);
  }

  QueryBuilder _whereSubquery(
    BuilderType type,
    String table,
    String column,
    void Function(QueryBuilder builder) builder,
  ) {
    final child = _child();
    builder(child);
    child.state.isInnerStatement = true;

    _state.whereStates.add(WhereState()
      ..builderType = type
      ..tableNameOrAlias = table
      ..columnName = column
      ..subquery = child.state);
    return this;
  }

  // ---- GROUP BY / HAVING ---------------------------------------------------------------------

  QueryBuilder groupByColumn(String table, String column) {
    _state.groupByStates.add(GroupByState()
      ..builderType = BuilderType.groupByColumn
      ..tableNameOrAlias = table
      ..columnName = column);
    return this;
  }

  QueryBuilder groupByColumns(List<GroupByRef> columns) {
    for (final c in columns) {
      groupByColumn(c.table, c.column);
    }
    return this;
  }

  QueryBuilder groupByRaw(String rawGroupBy) {
    _state.groupByStates.add(GroupByState()
      ..builderType = BuilderType.groupByRaw
      ..raw = rawGroupBy);
    return this;
  }

  QueryBuilder groupByRaws(List<String> rawGroupBys) {
    for (final r in rawGroupBys) {
      groupByRaw(r);
    }
    return this;
  }

  QueryBuilder having(
      String table, String column, WhereOperator operator, Object? value) {
    _state.havingStates.add(HavingState()
      ..builderType = BuilderType.having
      ..tableNameOrAlias = table
      ..columnName = column
      ..whereOperator = operator
      ..values = [value]);
    return this;
  }

  QueryBuilder havingRaw(String rawHaving) {
    _state.havingStates.add(HavingState()
      ..builderType = BuilderType.havingRaw
      ..raw = rawHaving);
    return this;
  }

  QueryBuilder havingRaws(List<String> rawHavings) {
    for (final r in rawHavings) {
      havingRaw(r);
    }
    return this;
  }

  // ---- ORDER BY / LIMIT ----------------------------------------------------------------------

  QueryBuilder orderByColumn(
      String table, String column, OrderByDirection direction) {
    _state.orderByStates.add(OrderByState()
      ..builderType = BuilderType.orderByColumn
      ..tableNameOrAlias = table
      ..columnName = column
      ..direction = direction);
    return this;
  }

  QueryBuilder orderByColumns(List<OrderByRef> columns) {
    for (final c in columns) {
      orderByColumn(c.table, c.column, c.direction);
    }
    return this;
  }

  QueryBuilder orderByRaw(String rawOrderBy) {
    _state.orderByStates.add(OrderByState()
      ..builderType = BuilderType.orderByRaw
      ..direction = OrderByDirection.ascending
      ..raw = rawOrderBy);
    return this;
  }

  QueryBuilder orderByRaws(List<String> rawOrderBys) {
    for (final r in rawOrderBys) {
      orderByRaw(r);
    }
    return this;
  }

  QueryBuilder limit(int limit) {
    _state.limit = limit;
    return this;
  }

  QueryBuilder offset(int offset) {
    _state.offset = offset;
    return this;
  }

  /// Sets the `TOP` row limit for the generated SELECT (MSSQL; ignored by other dialects).
  QueryBuilder top(int top) {
    (_state.customState ??= {})['top'] = top;
    return this;
  }

  // ---- INSERT / UPDATE / DELETE --------------------------------------------------------------

  QueryBuilder insertInto(String table, {String? owner}) {
    _state.queryType = QueryType.insert;
    final insert = _state.insertState ??= InsertState();
    insert.owner = owner ?? _config.defaultOwner;
    insert.tableName = table;
    return this;
  }

  QueryBuilder insertColumns(List<String> columns) {
    (_state.insertState ??= InsertState()).columns = columns;
    return this;
  }

  QueryBuilder insertValues(List<Object?> values) {
    (_state.insertState ??= InsertState()).values.add(values);
    return this;
  }

  QueryBuilder insertRaw(String raw) {
    _state.queryType = QueryType.insert;
    (_state.insertState ??= InsertState()).raw = raw;
    return this;
  }

  QueryBuilder updateTable(String table, {String? alias, String? owner}) {
    _state.queryType = QueryType.update;
    _state.fromStates.add(FromState()
      ..builderType = BuilderType.fromTable
      ..owner = owner ?? _config.defaultOwner
      ..tableName = table
      ..alias = alias);
    return this;
  }

  QueryBuilder set(String column, Object? value) {
    _state.updateStates.add(UpdateState()
      ..builderType = BuilderType.updateColumn
      ..columnName = column
      ..value = value);
    return this;
  }

  QueryBuilder setColumns(List<SetRef> columns) {
    for (final c in columns) {
      set(c.column, c.value);
    }
    return this;
  }

  QueryBuilder setRaw(String raw) {
    _state.updateStates.add(UpdateState()
      ..builderType = BuilderType.updateRaw
      ..raw = raw);
    return this;
  }

  QueryBuilder deleteFrom(String table, {String? alias, String? owner}) {
    _state.queryType = QueryType.delete;
    _state.fromStates.add(FromState()
      ..builderType = BuilderType.fromTable
      ..owner = owner ?? _config.defaultOwner
      ..tableName = table
      ..alias = alias);
    return this;
  }

  // ---- SET OPERATIONS / CTE ------------------------------------------------------------------

  QueryBuilder union(void Function(QueryBuilder builder) builder) =>
      _union(BuilderType.union, builder);

  QueryBuilder unionAll(void Function(QueryBuilder builder) builder) =>
      _union(BuilderType.unionAll, builder);

  QueryBuilder intersect(void Function(QueryBuilder builder) builder) =>
      _union(BuilderType.intersect, builder);

  QueryBuilder except(void Function(QueryBuilder builder) builder) =>
      _union(BuilderType.except, builder);

  QueryBuilder _union(
      BuilderType type, void Function(QueryBuilder builder) builder) {
    final child = _child();
    builder(child);
    child.state.isInnerStatement = true;

    _state.unionStates.add(UnionState()
      ..builderType = type
      ..subquery = child.state);
    return this;
  }

  QueryBuilder cte(String name, void Function(QueryBuilder builder) builder) =>
      _cte(name, false, builder);

  QueryBuilder cteRecursive(
          String name, void Function(QueryBuilder builder) builder) =>
      _cte(name, true, builder);

  QueryBuilder _cte(String name, bool recursive,
      void Function(QueryBuilder builder) builder) {
    final child = _child();
    builder(child);
    child.state.isInnerStatement = true;

    _state.cteStates.add(CteState()
      ..builderType = BuilderType.cteBuilder
      ..name = name
      ..recursive = recursive
      ..subquery = child.state);
    return this;
  }

  QueryBuilder cteRaw(String name, String raw) {
    _state.cteStates.add(CteState()
      ..builderType = BuilderType.cteRaw
      ..name = name
      ..raw = raw);
    return this;
  }

  // ---- rendering -----------------------------------------------------------------------------

  /// DEBUG / TEST rendering with values inlined UNQUOTED. NOT execution-safe — run [parsePrepared].
  String parseRaw() => parser.parseRaw(state, _config);

  /// DEBUG / TEST rendering (placeholders as text). NOT execution-safe — run [parsePrepared].
  String parse() => parser.parse(state, _config);

  /// The ONLY execution-safe render: parameterized SQL plus its ordered bound values.
  PreparedSql parsePrepared() => parser.parsePrepared(state, _config);
}
