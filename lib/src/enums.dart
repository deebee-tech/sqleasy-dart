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
  notLike('NotLike');

  const WhereOperator(this.wire);

  final String wire;

  static WhereOperator fromWire(String wire) =>
      _fromWire(values, wire, (v) => v.wire);
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
  none('None');

  const JoinOperator(this.wire);

  final String wire;

  static JoinOperator fromWire(String wire) =>
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
enum QueryType { select, insert, update, delete }

/// Whether values are inlined into the SQL (raw) or surfaced as bound parameters (prepared).
enum ParserMode { raw, prepared, none }

/// The specific clause a piece of builder state represents. Internal; drives the parser's dispatch.
enum BuilderType {
  and,
  fromBuilder,
  fromTable,
  fromRaw,
  groupByColumn,
  groupByRaw,
  having,
  havingRaw,
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
}

/// The kind of JOIN ON entry. Internal; drives the join-on parser's dispatch.
enum JoinOnOperator { groupBegin, groupEnd, on, raw, value, and, or, none }
