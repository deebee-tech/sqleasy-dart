import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';
import 'default_row_lock.dart';
import 'default_hint.dart';
import 'to_sql.dart';

SqlHelper defaultFrom(
  QueryState state,
  Dialect config,
  ParserMode mode, [
  ToSqlOptions? options,
]) {
  final sqlHelper = SqlHelper(mode);

  if (state.fromStates.isEmpty) {
    throw ParserError(ParserArea.from, 'No tables to select from');
  }

  sqlHelper.addSqlSnippet('FROM ');

  for (var i = 0; i < state.fromStates.length; i++) {
    final fromState = state.fromStates[i];

    if (fromState.builderType == BuilderType.fromRaw) {
      sqlHelper.addSqlSnippet(fromState.raw ?? '');
      if (i < state.fromStates.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }
      continue;
    }

    if (fromState.builderType == BuilderType.fromTable) {
      final hasOwner = (fromState.owner ?? '').isNotEmpty;

      if (hasOwner && config.databaseType == DatabaseType.mysql) {
        throw ParserError(
            ParserArea.from, 'MySQL does not support table owners');
      }

      if (hasOwner) {
        sqlHelper.addSqlSnippet(
            quoteIdentifier(fromState.owner, config.identifierDelimiters));
        sqlHelper.addSqlSnippet('.');
      }

      sqlHelper.addSqlSnippet(
          quoteIdentifier(fromState.tableName, config.identifierDelimiters));

      sqlHelper.addSqlSnippet(mysqlIndexHintForTable(
          state, config, fromState.alias ?? fromState.tableName ?? ''));

      if ((fromState.alias ?? '').isNotEmpty) {
        sqlHelper.addSqlSnippet(' AS ');
        sqlHelper.addSqlSnippet(
            quoteIdentifier(fromState.alias, config.identifierDelimiters));
      }

      // MSSQL has no `FOR UPDATE`/`FOR SHARE` — the row lock is a `WITH (...)` hint on each
      // base table instead. See `default_row_lock.dart`.
      if (state.rowLock != null && config.databaseType == DatabaseType.mssql) {
        sqlHelper.addSqlSnippet(mssqlRowLockHint(state.rowLock!));
      }

      if (i < state.fromStates.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }

      continue;
    }

    if (fromState.builderType == BuilderType.fromBuilder) {
      final subHelper = defaultToSql(fromState.subquery, config, mode, options);

      // Merge the subquery's bound values, not just its SQL — else its placeholders ship with no
      // parameters and bind NULL.
      sqlHelper.addSqlSnippetWithValues(
          '(${subHelper.getSql()})', subHelper.getValues());

      if ((fromState.alias ?? '').isNotEmpty) {
        sqlHelper.addSqlSnippet(' AS ');
        sqlHelper.addSqlSnippet(
            quoteIdentifier(fromState.alias, config.identifierDelimiters));
      }

      if (i < state.fromStates.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }

      continue;
    }

    if (fromState.builderType == BuilderType.fromLateral) {
      if (config.databaseType == DatabaseType.sqlite) {
        throw ParserError(
            ParserArea.from, 'SQLite does not support LATERAL derived tables');
      }
      if (config.databaseType == DatabaseType.mssql) {
        throw ParserError(
          ParserArea.from,
          'MSSQL LATERAL belongs in APPLY joins — use joinCrossApply/joinOuterApply',
        );
      }

      final subHelper = defaultToSql(fromState.subquery, config, mode, options);
      sqlHelper.addSqlSnippet('LATERAL (');
      sqlHelper.addSqlSnippetWithValues(
          subHelper.getSql(), subHelper.getValues());
      sqlHelper.addSqlSnippet(')');

      if ((fromState.alias ?? '').isNotEmpty) {
        sqlHelper.addSqlSnippet(' AS ');
        sqlHelper.addSqlSnippet(
            quoteIdentifier(fromState.alias, config.identifierDelimiters));
      }

      if (i < state.fromStates.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }

      continue;
    }

    if (fromState.builderType == BuilderType.fromFunction) {
      if ((fromState.owner ?? '').isNotEmpty) {
        if (config.databaseType == DatabaseType.mysql) {
          throw ParserError(
              ParserArea.from, 'MySQL does not support table owners');
        }
        sqlHelper.addSqlSnippet(
            quoteIdentifier(fromState.owner, config.identifierDelimiters));
        sqlHelper.addSqlSnippet('.');
      }

      final fnName = fromState.functionName ?? '';
      if (config.databaseType == DatabaseType.sqlite) {
        sqlHelper.addSqlSnippet(fnName);
      } else {
        sqlHelper.addSqlSnippet(
            quoteIdentifier(fnName, config.identifierDelimiters));
      }
      sqlHelper.addSqlSnippet('(');
      final params = fromState.functionParams;
      for (var paramIndex = 0; paramIndex < params.length; paramIndex++) {
        sqlHelper.addDynamicValue(params[paramIndex]);
        if (paramIndex < params.length - 1) {
          sqlHelper.addSqlSnippet(', ');
        }
      }
      sqlHelper.addSqlSnippet(')');

      if ((fromState.alias ?? '').isNotEmpty) {
        sqlHelper.addSqlSnippet(' AS ');
        sqlHelper.addSqlSnippet(
            quoteIdentifier(fromState.alias, config.identifierDelimiters));
      }

      if (i < state.fromStates.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }
    }
  }

  return sqlHelper;
}
