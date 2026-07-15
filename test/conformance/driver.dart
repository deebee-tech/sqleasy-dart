import 'package:sqleasy/sqleasy.dart';

import 'corpus.dart';

/// Replays a corpus op-list through the idiomatic Dart API.
///
/// The Dart twin of `tests/conformance/driver.ts` in the TypeScript repo. Neither driver computes
/// SQL itself — each only translates ops into builder calls — so any disagreement in the output is a
/// disagreement between the two implementations, which is exactly what the corpus exists to catch.
///
/// Where the TypeScript API uses an empty-string sentinel (`selectColumn('u','id','')`), the Dart
/// API uses an optional named parameter, so a corpus `alias` that is absent maps to `null`.

Object? _query(String dialect) {
  switch (dialect) {
    case 'mssql':
      return MssqlQuery();
    case 'mysql':
      return MysqlQuery();
    case 'postgres':
      return PostgresQuery();
    case 'sqlite':
      return SqliteQuery();
    default:
      throw StateError('unknown dialect "$dialect"');
  }
}

QueryBuilder _newBuilder(Object? query) => switch (query) {
      MssqlQuery() => query.newBuilder(),
      MysqlQuery() => query.newBuilder(),
      PostgresQuery() => query.newBuilder(),
      SqliteQuery() => query.newBuilder(),
      _ => throw StateError('not a query'),
    };

MultiBuilder _newMultiBuilder(Object? query) => switch (query) {
      MssqlQuery() => query.newMultiBuilder(),
      MysqlQuery() => query.newMultiBuilder(),
      PostgresQuery() => query.newMultiBuilder(),
      SqliteQuery() => query.newMultiBuilder(),
      _ => throw StateError('not a query'),
    };

String _str(Map<String, Object?> op, String key) => op[key]! as String;
String? _optStr(Map<String, Object?> op, String key) => op[key] as String?;
Object? _val(Map<String, Object?> op, [String key = 'value']) =>
    decodeInputValue(op[key]! as Map<String, Object?>);
List<Map<String, Object?>> _ops(Map<String, Object?> op,
        [String key = 'ops']) =>
    ((op[key] as List<Object?>?) ?? const []).cast<Map<String, Object?>>();
List<Object?> _values(Map<String, Object?> op, String key) =>
    ((op[key] as List<Object?>?) ?? const [])
        .map((v) => decodeInputValue(v! as Map<String, Object?>))
        .toList();
List<String> _strs(Map<String, Object?> op, String key) =>
    ((op[key] as List<Object?>?) ?? const []).cast<String>();

void _applyJoinOn(JoinOnBuilder b, List<Map<String, Object?>> onOps) {
  for (final op in onOps) {
    switch (op['op']) {
      case 'on':
        b.on(
            _str(op, 'leftAlias'),
            _str(op, 'leftColumn'),
            JoinOperator.fromWire(_str(op, 'operator')),
            _str(op, 'rightAlias'),
            _str(op, 'rightColumn'));
      case 'onValue':
        b.onValue(_str(op, 'alias'), _str(op, 'column'),
            JoinOperator.fromWire(_str(op, 'operator')), _val(op));
      case 'onRaw':
        b.onRaw(_str(op, 'sql'));
      case 'onGroup':
        b.onGroup((sub) => _applyJoinOn(sub, _ops(op)));
      case 'and':
        b.and();
      case 'or':
        b.or();
      default:
        throw StateError('unknown join-on op "${op['op']}"');
    }
  }
}

void applyOps(QueryBuilder b, List<Map<String, Object?>> ops) {
  for (final op in ops) {
    switch (op['op']) {
      // ---- SELECT ----
      case 'selectAll':
        b.selectAll();
      case 'selectColumn':
        b.selectColumn(_str(op, 'table'), _str(op, 'column'),
            alias: _optStr(op, 'alias'));
      case 'selectColumns':
        b.selectColumns([
          for (final c in _ops(op, 'columns'))
            (
              table: _str(c, 'table'),
              column: _str(c, 'column'),
              alias: _optStr(c, 'alias')
            ),
        ]);
      case 'selectRaw':
        b.selectRaw(_str(op, 'sql'));
      case 'selectRaws':
        b.selectRaws(_strs(op, 'sqls'));
      case 'selectWithBuilder':
        b.selectWithBuilder(
            _str(op, 'alias'), (sub) => applyOps(sub, _ops(op)));
      case 'distinct':
        b.distinct();

      // ---- FROM ----
      case 'fromTable':
        b.fromTable(_str(op, 'table'), alias: _optStr(op, 'alias'));
      case 'fromTableWithOwner':
        b.fromTable(_str(op, 'table'),
            alias: _optStr(op, 'alias'), owner: _str(op, 'owner'));
      case 'fromTables':
        b.fromTables([
          for (final t in _ops(op, 'tables'))
            (
              table: _str(t, 'table'),
              alias: _optStr(t, 'alias'),
              owner: _optStr(t, 'owner')
            ),
        ]);
      case 'fromRaw':
        b.fromRaw(_str(op, 'sql'));
      case 'fromRaws':
        b.fromRaws(_strs(op, 'sqls'));
      case 'fromWithBuilder':
        b.fromWithBuilder(_str(op, 'alias'), (sub) => applyOps(sub, _ops(op)));

      // ---- JOIN ----
      case 'joinTable':
        b.joinTable(JoinType.fromWire(_str(op, 'joinType')), _str(op, 'table'),
            (j) => _applyJoinOn(j, _ops(op, 'on')),
            alias: _optStr(op, 'alias'));
      case 'joinTableWithOwner':
        b.joinTable(JoinType.fromWire(_str(op, 'joinType')), _str(op, 'table'),
            (j) => _applyJoinOn(j, _ops(op, 'on')),
            alias: _optStr(op, 'alias'), owner: _str(op, 'owner'));
      case 'joinWithBuilder':
        b.joinWithBuilder(
            JoinType.fromWire(_str(op, 'joinType')),
            _str(op, 'alias'),
            (sub) => applyOps(sub, _ops(op)),
            (j) => _applyJoinOn(j, _ops(op, 'on')));
      case 'joinRaw':
        b.joinRaw(_str(op, 'sql'));

      // ---- WHERE ----
      case 'where':
        b.where(_str(op, 'table'), _str(op, 'column'),
            WhereOperator.fromWire(_str(op, 'operator')), _val(op));
      case 'whereBetween':
        b.whereBetween(_str(op, 'table'), _str(op, 'column'), _val(op, 'from'),
            _val(op, 'to'));
      case 'whereInValues':
        b.whereInValues(
            _str(op, 'table'), _str(op, 'column'), _values(op, 'values'));
      case 'whereNotInValues':
        b.whereNotInValues(
            _str(op, 'table'), _str(op, 'column'), _values(op, 'values'));
      case 'whereNull':
        b.whereNull(_str(op, 'table'), _str(op, 'column'));
      case 'whereNotNull':
        b.whereNotNull(_str(op, 'table'), _str(op, 'column'));
      case 'whereRaw':
        b.whereRaw(_str(op, 'sql'));
      case 'whereGroup':
        b.whereGroup((sub) => applyOps(sub, _ops(op)));
      case 'whereInWithBuilder':
        b.whereInWithBuilder(_str(op, 'table'), _str(op, 'column'),
            (sub) => applyOps(sub, _ops(op)));
      case 'whereNotInWithBuilder':
        b.whereNotInWithBuilder(_str(op, 'table'), _str(op, 'column'),
            (sub) => applyOps(sub, _ops(op)));
      case 'whereExistsWithBuilder':
        b.whereExistsWithBuilder(_str(op, 'table'), _str(op, 'column'),
            (sub) => applyOps(sub, _ops(op)));
      case 'whereNotExistsWithBuilder':
        b.whereNotExistsWithBuilder(_str(op, 'table'), _str(op, 'column'),
            (sub) => applyOps(sub, _ops(op)));
      case 'and':
        b.and();
      case 'or':
        b.or();

      // ---- GROUP BY / HAVING ----
      case 'groupByColumn':
        b.groupByColumn(_str(op, 'table'), _str(op, 'column'));
      case 'groupByRaw':
        b.groupByRaw(_str(op, 'sql'));
      case 'having':
        b.having(_str(op, 'table'), _str(op, 'column'),
            WhereOperator.fromWire(_str(op, 'operator')), _val(op));
      case 'havingRaw':
        b.havingRaw(_str(op, 'sql'));

      // ---- ORDER BY / LIMIT ----
      case 'orderByColumn':
        b.orderByColumn(_str(op, 'table'), _str(op, 'column'),
            OrderByDirection.fromWire(_str(op, 'direction')));
      case 'orderByRaw':
        b.orderByRaw(_str(op, 'sql'));
      case 'limit':
        b.limit((op['n']! as num).toInt());
      case 'offset':
        b.offset((op['n']! as num).toInt());
      case 'top':
        b.top((op['n']! as num).toInt());

      // ---- INSERT / UPDATE / DELETE ----
      case 'insertInto':
        b.insertInto(_str(op, 'table'));
      case 'insertIntoWithOwner':
        b.insertInto(_str(op, 'table'), owner: _str(op, 'owner'));
      case 'insertColumns':
        b.insertColumns(_strs(op, 'columns'));
      case 'insertValues':
        b.insertValues(_values(op, 'values'));
      case 'insertRaw':
        b.insertRaw(_str(op, 'sql'));
      case 'updateTable':
        b.updateTable(_str(op, 'table'), alias: _optStr(op, 'alias'));
      case 'updateTableWithOwner':
        b.updateTable(_str(op, 'table'),
            alias: _optStr(op, 'alias'), owner: _str(op, 'owner'));
      case 'set':
        b.set(_str(op, 'column'), _val(op));
      case 'setRaw':
        b.setRaw(_str(op, 'sql'));
      case 'deleteFrom':
        b.deleteFrom(_str(op, 'table'), alias: _optStr(op, 'alias'));
      case 'deleteFromWithOwner':
        b.deleteFrom(_str(op, 'table'),
            alias: _optStr(op, 'alias'), owner: _str(op, 'owner'));

      // ---- SET OPERATIONS / CTE ----
      case 'union':
        b.union((sub) => applyOps(sub, _ops(op)));
      case 'unionAll':
        b.unionAll((sub) => applyOps(sub, _ops(op)));
      case 'intersect':
        b.intersect((sub) => applyOps(sub, _ops(op)));
      case 'except':
        b.except((sub) => applyOps(sub, _ops(op)));
      case 'cte':
        b.cte(_str(op, 'name'), (sub) => applyOps(sub, _ops(op)));
      case 'cteRecursive':
        b.cteRecursive(_str(op, 'name'), (sub) => applyOps(sub, _ops(op)));
      case 'cteRaw':
        b.cteRaw(_str(op, 'name'), _str(op, 'sql'));

      default:
        throw StateError('unknown op "${op['op']}"');
    }
  }
}

/// Runs one case against one dialect and returns the same shape the golden records.
Map<String, Object?> runCase(GoldenCase c, String dialect) {
  final query = _query(dialect);

  try {
    if (c.builders != null) {
      final multi = _newMultiBuilder(query);
      if (c.transaction == 'off') {
        multi.setTransactionState(MultiBuilderTransactionState.transactionOff);
      }
      for (final spec in c.builders!) {
        final b = multi.addBuilder(spec['name']! as String);
        applyOps(
            b, (spec['ops']! as List<Object?>).cast<Map<String, Object?>>());
      }
      return {
        'prepared': {'sql': multi.parse(), 'params': const <Object?>[]},
        'raw': multi.parseRaw(),
      };
    }

    final builder = _newBuilder(query);
    applyOps(builder, c.ops ?? const []);

    final prepared = builder.parsePrepared();
    return {
      'prepared': {
        'sql': prepared.sql,
        'params': prepared.params.map(encodeOutputValue).toList(),
      },
      'raw': builder.parseRaw(),
    };
  } on ParserError catch (e) {
    return {'throws': e.toString()};
  }
}
