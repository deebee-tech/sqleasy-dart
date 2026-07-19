import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../sql_helper.dart';
import '../state.dart';
import 'default_json_predicate.dart';

void _emitColumnList(
  SqlHelper sqlHelper,
  Dialect config,
  List<GroupByColumnRef> columns,
) {
  for (var i = 0; i < columns.length; i++) {
    emitGroupByColumnRef(
      sqlHelper,
      config,
      columns[i].tableNameOrAlias,
      columns[i].columnName,
    );
    if (i < columns.length - 1) {
      sqlHelper.addSqlSnippet(', ');
    }
  }
}

List<GroupByColumnRef> _collectPlainColumns(List<GroupByState> groupByStates) {
  return [
    for (final state in groupByStates)
      if (state.builderType == BuilderType.groupByColumn)
        GroupByColumnRef(
          state.tableNameOrAlias ?? '',
          state.columnName ?? '',
        ),
  ];
}

SqlHelper defaultGroupBy(QueryState state, Dialect config, ParserMode mode) {
  final sqlHelper = SqlHelper(mode);

  if (state.groupByStates.isEmpty) {
    return sqlHelper;
  }

  GroupByState? modifier;
  for (final groupByState in state.groupByStates) {
    if (groupByState.builderType == BuilderType.groupByRollup ||
        groupByState.builderType == BuilderType.groupByCube ||
        groupByState.builderType == BuilderType.groupByGroupingSets) {
      modifier = groupByState;
      break;
    }
  }

  final plainColumns = _collectPlainColumns(state.groupByStates);

  sqlHelper.addSqlSnippet('GROUP BY ');

  if (modifier == null) {
    for (var i = 0; i < state.groupByStates.length; i++) {
      final groupByState = state.groupByStates[i];

      if (groupByState.builderType == BuilderType.groupByRaw) {
        sqlHelper.addSqlSnippet(groupByState.raw ?? '');

        if (i < state.groupByStates.length - 1) {
          sqlHelper.addSqlSnippet(', ');
        }

        continue;
      }

      if (groupByState.builderType == BuilderType.groupByColumn) {
        emitGroupByColumnRef(
          sqlHelper,
          config,
          groupByState.tableNameOrAlias ?? '',
          groupByState.columnName ?? '',
        );

        if (i < state.groupByStates.length - 1) {
          sqlHelper.addSqlSnippet(', ');
        }
      }
    }

    return sqlHelper;
  }

  if (modifier.builderType == BuilderType.groupByRollup) {
    final columns =
        modifier.groupingSets != null && modifier.groupingSets!.length == 1
            ? modifier.groupingSets!.first
            : plainColumns;

    if (columns.isEmpty) {
      throw ParserError(
          ParserArea.general, 'ROLLUP requires at least one grouping column');
    }
    if (config.databaseType == DatabaseType.mysql) {
      _emitColumnList(sqlHelper, config, columns);
      sqlHelper.addSqlSnippet(' WITH ROLLUP');
      return sqlHelper;
    }

    sqlHelper.addSqlSnippet('ROLLUP (');
    _emitColumnList(sqlHelper, config, columns);
    sqlHelper.addSqlSnippet(')');
    return sqlHelper;
  }

  if (modifier.builderType == BuilderType.groupByCube) {
    final columns =
        modifier.groupingSets != null && modifier.groupingSets!.length == 1
            ? modifier.groupingSets!.first
            : plainColumns;

    if (columns.isEmpty) {
      throw ParserError(
          ParserArea.general, 'CUBE requires at least one grouping column');
    }

    if (config.databaseType == DatabaseType.mysql) {
      throw ParserError(
        ParserArea.general,
        'MySQL has no CUBE — use groupByRollup/groupByGroupingSets or groupByRaw',
      );
    }

    sqlHelper.addSqlSnippet('CUBE (');
    _emitColumnList(sqlHelper, config, columns);
    sqlHelper.addSqlSnippet(')');
    return sqlHelper;
  }

  final sets = modifier.groupingSets ?? [];
  if (sets.isEmpty) {
    throw ParserError(
        ParserArea.general, 'GROUPING SETS requires at least one column set');
  }

  if (config.databaseType == DatabaseType.mysql) {
    throw ParserError(
      ParserArea.general,
      'MySQL has no GROUPING SETS — use groupByRollup or groupByRaw',
    );
  }

  sqlHelper.addSqlSnippet('GROUPING SETS (');
  for (var setIndex = 0; setIndex < sets.length; setIndex++) {
    sqlHelper.addSqlSnippet('(');
    _emitColumnList(sqlHelper, config, sets[setIndex]);
    sqlHelper.addSqlSnippet(')');
    if (setIndex < sets.length - 1) {
      sqlHelper.addSqlSnippet(', ');
    }
  }
  sqlHelper.addSqlSnippet(')');

  return sqlHelper;
}
