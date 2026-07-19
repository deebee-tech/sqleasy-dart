/// The mutable data model a builder populates and the parser walks.
///
/// These mirror the TypeScript `src/state/*` object types. They are deliberately plain mutable
/// classes with defaulted fields — not sealed/immutable — because the builder mutates them in place
/// and the parser reads them, exactly as the original does. A `string | undefined` field becomes
/// `String?`; an `any` value slot becomes `Object?`.
library;

import 'enums.dart';

/// A single statement's full state. The equivalent of `createQueryState()` is just `QueryState()`.
class QueryState {
  String builderName = '';
  QueryType queryType = QueryType.select;
  List<FromState> fromStates = [];
  List<JoinState> joinStates = [];
  List<WhereState> whereStates = [];
  List<OrderByState> orderByStates = [];
  List<SelectState> selectStates = [];
  List<GroupByState> groupByStates = [];
  List<HavingState> havingStates = [];
  List<UnionState> unionStates = [];
  List<CteState> cteStates = [];
  InsertState? insertState;
  List<UpdateState> updateStates = [];

  /// INSERT conflict clause (upsert); null when not configured.
  UpsertState? upsertState;

  /// RETURNING/OUTPUT clause for INSERT/UPDATE/DELETE; null when not configured.
  ReturningState? returningState;

  /// Row-locking clause for SELECT (`FOR UPDATE`/`FOR SHARE`); null when not configured.
  RowLockState? rowLock;

  /// Stored procedure/function call state; null for non-Call queries.
  CallState? callState;
  bool isInnerStatement = false;
  int limit = 0;
  int offset = 0;
  bool limitWithTies = false;
  bool distinct = false;

  /// `DISTINCT ON (...)` columns (Postgres only); null/empty omits it.
  List<DistinctOnColumnState>? distinctOnColumns;

  /// An open bag for dialect-specific state (currently only MSSQL's `top`). Mirrors the TypeScript
  /// `customState: any | undefined`.
  Map<String, Object?>? customState;

  /// Index into [fromStates] for the UPDATE/DELETE target table.
  ///
  /// Set by `updateTable` / `deleteFrom` so a prior `fromTable` cannot steal the target.
  int? mutationTargetIndex;

  /// Structured and raw query hints (MySQL index hints, MSSQL OPTION, etc.).
  List<HintState> hintStates = [];
}

/// One column in a Postgres `DISTINCT ON (...)` list.
class DistinctOnColumnState {
  DistinctOnColumnState(this.tableNameOrAlias, this.columnName);

  String tableNameOrAlias;
  String columnName;
}

class SelectState {
  BuilderType builderType = BuilderType.none;
  String? tableNameOrAlias;
  String? columnName;
  String? alias;
  QueryState? subquery;
  String? raw;

  /// JSON path for [BuilderType.selectJsonExtract].
  String? jsonPath;
  JsonExtractMode? jsonExtractMode;

  /// The `OVER (...)` clause for a [BuilderType.selectWindow] item.
  WindowState? window;
}

class FromState {
  BuilderType builderType = BuilderType.none;
  String? owner;
  String? tableName;
  String? alias;
  QueryState? subquery;
  String? raw;

  /// Table-valued / set-returning function name for [BuilderType.fromFunction].
  String? functionName;

  /// Positional arguments for [BuilderType.fromFunction].
  List<Object?> functionParams = [];
}

class JoinState {
  BuilderType builderType = BuilderType.none;
  JoinType joinType = JoinType.inner;
  String? owner;
  String? tableName;
  String? alias;
  QueryState? subquery;
  String? raw;
  List<JoinOnState> joinOnStates = [];
}

class JoinOnState {
  String? aliasLeft;
  String? columnLeft;
  JoinOperator joinOperator = JoinOperator.equals;
  String? aliasRight;
  String? columnRight;
  JoinOnOperator joinOnOperator = JoinOnOperator.none;
  String? raw;
  Object? valueRight;

  /// Right-hand value list for `onIn`/`onNotIn` or `onBetween`/`onNotBetween` (exactly two).
  List<Object?>? valuesRight;
}

class WhereState {
  BuilderType builderType = BuilderType.none;
  String? tableNameOrAlias;
  String? columnName;
  WhereOperator whereOperator = WhereOperator.none;
  String? raw;
  QueryState? subquery;
  List<Object?> values = [];

  /// JSON path for [BuilderType.whereJsonExtract].
  String? jsonPath;
  JsonExtractMode? jsonExtractMode;

  /// Full-text mode for [BuilderType.whereFullText].
  FullTextMode? fullTextMode;

  /// Full-text column list for [BuilderType.whereFullText].
  List<FullTextColumnRef>? fullTextColumns;
}

class HavingState {
  BuilderType builderType = BuilderType.none;
  String? tableNameOrAlias;
  String? columnName;
  WhereOperator whereOperator = WhereOperator.none;
  String? raw;
  QueryState? subquery;
  List<Object?> values = [];

  /// JSON path for [BuilderType.havingJsonExtract].
  String? jsonPath;
  JsonExtractMode? jsonExtractMode;

  /// Full-text mode for [BuilderType.havingFullText].
  FullTextMode? fullTextMode;

  /// Full-text column list for [BuilderType.havingFullText].
  List<FullTextColumnRef>? fullTextColumns;
}

class GroupByState {
  BuilderType builderType = BuilderType.none;
  String? tableNameOrAlias;
  String? columnName;
  String? raw;

  /// Column sets for ROLLUP/CUBE/GROUPING SETS modifiers.
  List<List<GroupByColumnRef>>? groupingSets;
}

/// One column reference in a GROUP BY ROLLUP/CUBE/GROUPING SETS list.
class GroupByColumnRef {
  GroupByColumnRef(this.tableNameOrAlias, this.columnName);

  String tableNameOrAlias;
  String columnName;
}

/// One column reference in a full-text MATCH predicate.
class FullTextColumnRef {
  FullTextColumnRef(this.tableNameOrAlias, this.columnName);

  String tableNameOrAlias;
  String columnName;
}

/// One structured or raw query hint.
class HintState {
  HintKind kind = HintKind.raw;
  String? tableNameOrAlias;
  String? indexName;
  String? optionText;
  String? raw;
}

class OrderByState {
  BuilderType builderType = BuilderType.none;
  String? tableNameOrAlias;
  String? columnName;
  OrderByDirection direction = OrderByDirection.none;

  /// `NULLS FIRST`/`NULLS LAST` placement; [NullsOrder.none] omits it.
  NullsOrder nulls = NullsOrder.none;
  String? raw;
}

class UnionState {
  BuilderType builderType = BuilderType.none;
  QueryState? subquery;
  String? raw;
}

class CteState {
  BuilderType builderType = BuilderType.none;
  String name = '';
  List<String> columns = [];
  bool recursive = false;
  QueryState? subquery;
  String? raw;
}

class InsertState {
  String? owner;
  String? tableName;
  List<String> columns = [];
  List<List<Object?>> values = [];

  /// `INSERT ... SELECT` source query; mutually exclusive with [values].
  QueryState? selectSubquery;
  String? raw;
}

class UpdateState {
  BuilderType builderType = BuilderType.none;
  String? columnName;
  Object? value;
  String? raw;
}

/// Holds state for a RETURNING (PG/SQLite) or OUTPUT (MSSQL) clause on INSERT/UPDATE/DELETE.
class ReturningState {
  List<String> columns = [];
  String? raw;
}

/// Holds state for an INSERT's conflict clause (PG/SQLite `ON CONFLICT`, MySQL
/// `ON DUPLICATE KEY UPDATE` / `INSERT IGNORE`, MSSQL `MERGE`).
class UpsertState {
  UpsertAction action = UpsertAction.none;

  /// Columns identifying the conflict target for PG/SQLite `ON CONFLICT (...)`. Ignored on
  /// MySQL, which infers the conflicting key from the table's own unique/primary constraints.
  List<String> conflictColumns = [];

  /// SET assignments for the conflict-update action.
  List<UpsertSetState> updateColumns = [];

  /// Raw SQL for the conflict-update SET list when not using structured fields.
  String? updateRaw;
}

/// One `column = value` assignment inside an upsert's conflict-update SET list.
class UpsertSetState {
  UpsertSetState(this.columnName, this.value);

  String columnName;
  Object? value;
}

/// Holds state for a SELECT's row-locking clause (`FOR UPDATE`/`FOR SHARE`, or MSSQL's
/// `WITH (...)` table-hint equivalent).
class RowLockState {
  RowLockMode mode = RowLockMode.none;
  RowLockWait wait = RowLockWait.defaultWait;
}

/// One argument to a `callProcedure`/`callFunction` call.
///
/// `name` is dual-purpose, matching how the underlying SQL actually spells a named argument. For
/// [CallParamDirection.in_] it is the *named-argument key* — Postgres (`name := value`) and MSSQL
/// (`@name = value`) match it against the routine's own declared parameter name; MySQL has no
/// named-argument syntax and refuses it. For [CallParamDirection.out]/[CallParamDirection.inOut]
/// it is instead the *variable identifier*: the MSSQL local variable `DECLARE @name ...` declares,
/// or the MySQL session variable `@name` references — required on both, and by convention the
/// same name as the routine's own parameter. Postgres has no variables at all (an OUT value simply
/// comes back as a result column of the `CALL`), so `name` there is always just the named-argument
/// key, and may be omitted.
class CallParamState {
  /// Calling convention: bound input, output-only, or both.
  CallParamDirection direction = CallParamDirection.in_;

  /// See the class-level doc above — meaning depends on [direction] and dialect.
  String? name;

  /// Bound value for `In`/`InOut`; ignored (no value to supply) for `Out`.
  Object? value;

  /// Declared T-SQL type for an MSSQL OUT/INOUT variable (e.g. `'INT'`); required there only.
  String? sqlType;

  /// Raw SQL argument expression, emitted verbatim — mutually exclusive with [value].
  String? raw;
}

/// Holds state for a `callProcedure`/`callFunction` statement. Populated by the builder; exposed
/// via [QueryState.callState].
class CallState {
  /// Procedure (`CALL`/`EXEC`) or function (`SELECT` expression).
  CallKind kind = CallKind.procedure;

  /// Schema/owner the routine lives in; null/empty omits it.
  String? owner;

  /// The routine name.
  String name = '';

  /// For functions: scalar vs. set-returning invocation. Unused for procedures.
  CallReturnIntent returnIntent = CallReturnIntent.voidReturn;

  /// Arguments in declaration order.
  List<CallParamState> params = [];
}

/// Holds state for one `PARTITION BY` term inside a window's `OVER (...)`.
class WindowPartitionByState {
  String? tableNameOrAlias;
  String? columnName;
  String? raw;
}

/// Holds state for one `ORDER BY` term inside a window's `OVER (...)`.
class WindowOrderByState {
  String? tableNameOrAlias;
  String? columnName;
  OrderByDirection direction = OrderByDirection.none;
  NullsOrder nulls = NullsOrder.none;
  String? raw;
}

/// One endpoint of a window's `ROWS`/`RANGE BETWEEN ... AND ...` frame clause.
class WindowFrameBoundState {
  FrameBoundType type = FrameBoundType.currentRow;
  int? offset;
}

/// A window's optional frame clause (`ROWS`/`RANGE BETWEEN start AND end`).
class WindowFrameState {
  FrameUnit unit = FrameUnit.rows;
  WindowFrameBoundState start = WindowFrameBoundState();
  WindowFrameBoundState? end;
  String? raw;
}

/// Holds state for one window function's `OVER (...)` clause.
class WindowState {
  List<WindowPartitionByState> partitionByStates = [];
  List<WindowOrderByState> orderByStates = [];
  WindowFrameState? frame;
}
