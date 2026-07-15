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
  bool isInnerStatement = false;
  int limit = 0;
  int offset = 0;
  bool distinct = false;

  /// An open bag for dialect-specific state (currently only MSSQL's `top`). Mirrors the TypeScript
  /// `customState: any | undefined`.
  Map<String, Object?>? customState;
}

class SelectState {
  BuilderType builderType = BuilderType.none;
  String? tableNameOrAlias;
  String? columnName;
  String? alias;
  QueryState? subquery;
  String? raw;
}

class FromState {
  BuilderType builderType = BuilderType.none;
  String? owner;
  String? tableName;
  String? alias;
  QueryState? subquery;
  String? raw;
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
}

class WhereState {
  BuilderType builderType = BuilderType.none;
  String? tableNameOrAlias;
  String? columnName;
  WhereOperator whereOperator = WhereOperator.none;
  String? raw;
  QueryState? subquery;
  List<Object?> values = [];
}

class HavingState {
  BuilderType builderType = BuilderType.none;
  String? tableNameOrAlias;
  String? columnName;
  WhereOperator whereOperator = WhereOperator.none;
  String? raw;
  List<Object?> values = [];
}

class GroupByState {
  BuilderType builderType = BuilderType.none;
  String? tableNameOrAlias;
  String? columnName;
  String? raw;
}

class OrderByState {
  BuilderType builderType = BuilderType.none;
  String? tableNameOrAlias;
  String? columnName;
  OrderByDirection direction = OrderByDirection.none;
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
  bool recursive = false;
  QueryState? subquery;
  String? raw;
}

class InsertState {
  String? owner;
  String? tableName;
  List<String> columns = [];
  List<List<Object?>> values = [];
  String? raw;
}

class UpdateState {
  BuilderType builderType = BuilderType.none;
  String? columnName;
  Object? value;
  String? raw;
}
