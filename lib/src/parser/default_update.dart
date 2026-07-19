import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';
import 'default_join.dart';
import 'default_mutation_join.dart';
import 'default_returning.dart';
import 'mutation_target.dart';
import 'to_sql.dart';

SqlHelper defaultUpdate(
  QueryState state,
  Dialect config,
  ParserMode mode, [
  ToSqlOptions? options,
]) {
  final sqlHelper = SqlHelper(mode);

  if (state.updateStates.isEmpty) {
    throw ParserError(
        ParserArea.update, 'UPDATE requires at least one SET column');
  }

  assertMutationJoinsSupported(state, config, ParserArea.update);

  final hasJoins = state.joinStates.isNotEmpty;

  final delim = config.identifierDelimiters;
  String quote(String s) => quoteIdentifier(s, delim);

  final fromState = resolveMutationTarget(
      state, ParserArea.update, 'UPDATE requires a table');
  final owner = fromState.owner ?? '';
  final alias = fromState.alias ?? '';

  if (owner.isNotEmpty && config.databaseType == DatabaseType.mysql) {
    throw ParserError(ParserArea.update, 'MySQL does not support table owners');
  }

  final qualified = (owner.isNotEmpty ? '${quote(owner)}.' : '') +
      quote(fromState.tableName ?? '');
  final mssqlAliased = config.databaseType == DatabaseType.mssql &&
      (alias.isNotEmpty || hasJoins);

  sqlHelper.addSqlSnippet('UPDATE ');

  if (mssqlAliased) {
    sqlHelper.addSqlSnippet(alias.isNotEmpty ? quote(alias) : qualified);
  } else {
    sqlHelper.addSqlSnippet(qualified);
    if (alias.isNotEmpty) {
      sqlHelper.addSqlSnippet(' AS ');
      sqlHelper.addSqlSnippet(quote(alias));
    }

    if (hasJoins && config.databaseType == DatabaseType.mysql) {
      final join = defaultJoin(state, config, mode, options);
      sqlHelper.addSqlSnippet(' ');
      sqlHelper.addSqlSnippetWithValues(join.getSql(), join.getValues());
    }
  }

  sqlHelper.addSqlSnippet(' SET ');

  for (var i = 0; i < state.updateStates.length; i++) {
    final updateState = state.updateStates[i];

    if (updateState.builderType == BuilderType.updateRaw) {
      sqlHelper.addSqlSnippet(updateState.raw ?? '');
    } else if (updateState.builderType == BuilderType.updateColumn) {
      sqlHelper.addSqlSnippet(
          quoteIdentifier(updateState.columnName, config.identifierDelimiters));
      sqlHelper.addSqlSnippet(' = ');
      sqlHelper.addDynamicValue(updateState.value);
    }

    if (i < state.updateStates.length - 1) {
      sqlHelper.addSqlSnippet(', ');
    }
  }

  if (state.returningState != null &&
      config.databaseType == DatabaseType.mssql) {
    emitMssqlOutputClause(sqlHelper, config, state.returningState!, 'INSERTED',
        ParserArea.update);
  }

  if (mssqlAliased) {
    sqlHelper.addSqlSnippet(' FROM ');
    sqlHelper.addSqlSnippet(qualified);
    if (alias.isNotEmpty) {
      sqlHelper.addSqlSnippet(' AS ');
      sqlHelper.addSqlSnippet(quote(alias));
    }

    if (hasJoins) {
      final join = defaultJoin(state, config, mode, options);
      sqlHelper.addSqlSnippet(' ');
      sqlHelper.addSqlSnippetWithValues(join.getSql(), join.getValues());
    }
  }

  if (hasJoins && config.databaseType == DatabaseType.postgres) {
    final from = renderPostgresMutationFrom(
        config, state, mode, options, ParserArea.update);
    sqlHelper.addSqlSnippet(' FROM ');
    sqlHelper.addSqlSnippetWithValues(from.getSql(), from.getValues());
  }

  return sqlHelper;
}
