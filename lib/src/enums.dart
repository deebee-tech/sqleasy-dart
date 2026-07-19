/// The enums used across the builder and parser.
///
/// Each carries a `wire` value — the string the TypeScript implementation uses — so the golden
/// corpus (authored against TypeScript) can look a member up by name via `fromWire`. Member names
/// are idiomatic Dart (`lowerCamelCase`); the `wire` value preserves the original PascalCase.
library;

T _fromWire<T extends Enum>(
    List<T> values, String wire, String Function(T) wireOf) {
  for (final v in values) {
    if (wireOf(v) == wire) return v;
  }
  throw ArgumentError('unknown wire value "$wire" for $T');
}

/// Comparison operators for WHERE and HAVING predicates.
enum WhereOperator {
  equals('Equals'),
  notEquals('NotEquals'),
  greaterThan('GreaterThan'),
  greaterThanOrEquals('GreaterThanOrEquals'),
  lessThan('LessThan'),
  lessThanOrEquals('LessThanOrEquals'),
  none('None'),
  like('Like'),
  notLike('NotLike'),

  /// Case-insensitive pattern match. Native `ILIKE` on Postgres; on MySQL, SQLite, and MSSQL
  /// (none of which have `ILIKE`) it is rewritten to `LOWER(col) LIKE LOWER(?)`.
  ilike('Ilike'),

  /// Negated case-insensitive pattern match — see [ilike].
  notIlike('NotIlike'),

  /// Null-safe inequality — native `IS DISTINCT FROM` on Postgres/SQLite; MySQL rewrites to
  /// `NOT (a <=> b)`; MSSQL throws.
  isDistinctFrom('IsDistinctFrom'),

  /// Null-safe equality — native `IS NOT DISTINCT FROM` on Postgres/SQLite; MySQL rewrites to
  /// `<=>`; MSSQL throws.
  isNotDistinctFrom('IsNotDistinctFrom');

  const WhereOperator(this.wire);

  final String wire;

  static WhereOperator fromWire(String wire) =>
      _fromWire(values, wire, (v) => v.wire);
}

/// The row-locking mode requested for a SELECT (`FOR UPDATE` / `FOR SHARE` and MSSQL's table-hint
/// equivalents).
enum RowLockMode {
  none('None'),
  forUpdate('ForUpdate'),
  forShare('ForShare');

  const RowLockMode(this.wire);

  final String wire;
}

/// Wait behavior for a [RowLockMode], when the requested rows are already locked.
enum RowLockWait {
  /// Block until the lock is available (the dialect's default wait behavior).
  defaultWait('Default'),

  /// Fail immediately instead of waiting (`NOWAIT`).
  nowait('Nowait'),

  /// Silently skip already-locked rows instead of waiting (`SKIP LOCKED`, MSSQL `READPAST`).
  skipLocked('SkipLocked');

  const RowLockWait(this.wire);

  final String wire;
}

/// The conflict-resolution action for an INSERT's upsert clause.
enum UpsertAction {
  /// No upsert clause configured.
  none('None'),

  /// Conflicting rows are silently skipped (PG/SQLite `DO NOTHING`, MySQL `INSERT IGNORE`).
  doNothing('DoNothing'),

  /// Conflicting rows are updated (PG/SQLite `DO UPDATE SET`, MySQL `ON DUPLICATE KEY UPDATE`).
  doUpdate('DoUpdate');

  const UpsertAction(this.wire);

  final String wire;
}

/// JSON path extraction mode for `selectJsonExtract` / `whereJsonExtract` / `havingJsonExtract`.
enum JsonExtractMode {
  text('Text'),
  object('Object');

  const JsonExtractMode(this.wire);

  final String wire;

  static JsonExtractMode fromWire(String wire) =>
      _fromWire(values, wire, (v) => v.wire);
}

/// Full-text search mode for `whereMatch` / `havingMatch`.
enum FullTextMode {
  natural('Natural'),
  boolean('Boolean'),
  phrase('Phrase');

  const FullTextMode(this.wire);

  final String wire;

  static FullTextMode fromWire(String wire) =>
      _fromWire(values, wire, (v) => v.wire);
}

/// Structured query-hint kind for `hintUseIndex` / `hintForceIndex` / `hintMssqlOption` /
/// `hintRaw`.
enum HintKind {
  useIndex('UseIndex'),
  forceIndex('ForceIndex'),
  mssqlOption('MssqlOption'),
  raw('Raw');

  const HintKind(this.wire);

  final String wire;
}

/// The kind of JOIN.
enum JoinType {
  inner('Inner'),
  left('Left'),
  leftOuter('LeftOuter'),
  right('Right'),
  rightOuter('RightOuter'),
  fullOuter('FullOuter'),
  cross('Cross'),
  lateral('Lateral'),
  crossApply('CrossApply'),
  outerApply('OuterApply'),
  none('None');

  const JoinType(this.wire);

  final String wire;

  static JoinType fromWire(String wire) =>
      _fromWire(values, wire, (v) => v.wire);
}

/// Comparison operators for JOIN ON predicates.
enum JoinOperator {
  equals('Equals'),
  notEquals('NotEquals'),
  greaterThan('GreaterThan'),
  greaterThanOrEquals('GreaterThanOrEquals'),
  lessThan('LessThan'),
  lessThanOrEquals('LessThanOrEquals'),
  none('None'),
  like('Like'),
  notLike('NotLike');

  const JoinOperator(this.wire);

  final String wire;

  static JoinOperator fromWire(String wire) =>
      _fromWire(values, wire, (v) => v.wire);
}

/// `NULLS FIRST` / `NULLS LAST` placement for an ORDER BY term (top-level or inside a window's
/// `OVER (... ORDER BY ...)`).
enum NullsOrder {
  none('None'),
  first('First'),
  last('Last');

  const NullsOrder(this.wire);

  final String wire;

  static NullsOrder fromWire(String wire) =>
      _fromWire(values, wire, (v) => v.wire);
}

/// One endpoint of a window function's frame clause (`ROWS`/`RANGE BETWEEN ... AND ...`).
enum FrameBoundType {
  unboundedPreceding('UnboundedPreceding'),
  preceding('Preceding'),
  currentRow('CurrentRow'),
  following('Following'),
  unboundedFollowing('UnboundedFollowing');

  const FrameBoundType(this.wire);

  final String wire;

  static FrameBoundType fromWire(String wire) =>
      _fromWire(values, wire, (v) => v.wire);
}

/// The unit a window function's frame clause counts in — physical rows, or logical value range.
enum FrameUnit {
  rows('Rows'),
  range('Range');

  const FrameUnit(this.wire);

  final String wire;

  static FrameUnit fromWire(String wire) =>
      _fromWire(values, wire, (v) => v.wire);
}

/// ORDER BY sort direction.
enum OrderByDirection {
  ascending('Ascending'),
  descending('Descending'),
  none('None');

  const OrderByDirection(this.wire);

  final String wire;

  static OrderByDirection fromWire(String wire) =>
      _fromWire(values, wire, (v) => v.wire);
}

/// Whether a [MultiBuilder] batch is wrapped in a transaction.
enum MultiBuilderTransactionState {
  transactionOn('TransactionOn'),
  transactionOff('TransactionOff'),
  none('None');

  const MultiBuilderTransactionState(this.wire);

  final String wire;
}

/// Which database a [Dialect] targets. The `wire` values are lowercase, matching the TypeScript
/// `DatabaseType`.
enum DatabaseType {
  mssql('mssql'),
  postgres('postgres'),
  mysql('mysql'),
  sqlite('sqlite'),
  unknown('unknown');

  const DatabaseType(this.wire);

  final String wire;
}

/// The kind of statement a query state renders as.
enum QueryType { select, insert, update, delete, call }

/// Whether a [QueryBuilder.callProcedure]/[QueryBuilder.callFunction] invocation targets a stored
/// procedure or a stored function — the two are emitted differently on every dialect (a
/// `CALL`/`EXEC` statement vs. an expression usable in a `SELECT`).
enum CallKind {
  /// A stored procedure, invoked as its own statement (`CALL name(...)` / `EXEC name ...`).
  procedure('Procedure'),

  /// A stored function, invoked as a `SELECT` expression (`SELECT name(...)`).
  function('Function');

  const CallKind(this.wire);

  final String wire;
}

/// The calling convention for one [QueryBuilder.callProcedure]/[QueryBuilder.callFunction]
/// argument. OUT/INOUT are meaningful only for procedures — see [QueryBuilder.procParamOut]/
/// [QueryBuilder.procParamInOut].
enum CallParamDirection {
  /// An input value, bound like any other parameter.
  in_('In'),

  /// An output-only slot (MSSQL: a declared local variable; MySQL: a session variable).
  out('Out'),

  /// Both an input value and an output slot.
  inOut('InOut');

  const CallParamDirection(this.wire);

  final String wire;
}

/// What a [QueryBuilder.callFunction] call is expected to return, which decides whether
/// Postgres/MSSQL wrap the invocation in `SELECT expr` (a single scalar) or `SELECT * FROM expr`
/// (a set-returning / table-valued function). MySQL has no table-valued functions and refuses
/// [resultSet].
enum CallReturnIntent {
  /// No return value. Only meaningful for procedures — never valid for [QueryBuilder.callFunction].
  voidReturn('Void'),

  /// A single scalar value: `SELECT name(...)`.
  scalar('Scalar'),

  /// A set-returning / table-valued function: `SELECT * FROM name(...)`.
  resultSet('ResultSet');

  const CallReturnIntent(this.wire);

  final String wire;

  static CallReturnIntent fromWire(String wire) =>
      _fromWire(values, wire, (v) => v.wire);
}

/// Whether values are inlined into the SQL (raw) or surfaced as bound parameters (prepared).
enum ParserMode { raw, prepared, none }

/// The specific clause a piece of builder state represents. Internal; drives the parser's dispatch.
enum BuilderType {
  and,
  fromBuilder,
  fromTable,
  fromRaw,
  fromLateral,
  fromFunction,
  groupByColumn,
  groupByRaw,
  groupByRollup,
  groupByCube,
  groupByGroupingSets,
  having,
  havingRaw,
  havingBetween,
  havingGroupBegin,
  havingGroupBuilder,
  havingGroupEnd,
  havingExistsBuilder,
  havingInBuilder,
  havingInValues,
  havingNotExistsBuilder,
  havingNotInBuilder,
  havingNotInValues,
  havingNotNull,
  havingNull,
  havingJsonExtract,
  havingJsonContains,
  havingFullText,
  insertRaw,
  joinBuilder,
  joinRaw,
  joinTable,
  none,
  or,
  orderByColumn,
  orderByRaw,
  selectAll,
  selectBuilder,
  selectColumn,
  selectRaw,
  selectJsonExtract,
  selectWindow,
  updateColumn,
  updateRaw,
  union,
  unionAll,
  intersect,
  except,
  cteBuilder,
  cteRaw,
  where,
  whereBetween,
  whereGroupBegin,
  whereGroupBuilder,
  whereGroupEnd,
  whereExistsBuilder,
  whereInBuilder,
  whereInValues,
  whereNotExistsBuilder,
  whereNotInBuilder,
  whereNotInValues,
  whereNotNull,
  whereNull,
  whereRaw,
  whereJsonExtract,
  whereJsonContains,
  whereFullText,
}

/// The kind of JOIN ON entry. Internal; drives the join-on parser's dispatch.
enum JoinOnOperator {
  groupBegin,
  groupEnd,
  on,
  raw,
  value,
  and,
  or,
  inValues,
  notInValues,
  between,
  notBetween,
  none,
}
