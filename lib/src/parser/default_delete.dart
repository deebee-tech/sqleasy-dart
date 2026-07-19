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

SqlHelper defaultDelete(
  QueryState state,
  Dialect config,
  ParserMode mode, [
  ToSqlOptions? options,
]) {
  final sqlHelper = SqlHelper(mode);

  assertMutationJoinsSupported(state, config, ParserArea.delete);

  final hasJoins = state.joinStates.isNotEmpty;

  final delim = config.identifierDelimiters;
  String quote(String s) => quoteIdentifier(s, delim);

  final fromState = resolveMutationTarget(
      state, ParserArea.delete, 'DELETE requires a table');
  final owner = fromState.owner ?? '';
  final alias = fromState.alias ?? '';

  if (owner.isNotEmpty && config.databaseType == DatabaseType.mysql) {
    throw ParserError(ParserArea.delete, 'MySQL does not support table owners');
  }

  final qualified = (owner.isNotEmpty ? '${quote(owner)}.' : '') +
      quote(fromState.tableName ?? '');

  final mssqlAliased = config.databaseType == DatabaseType.mssql &&
      (alias.isNotEmpty || hasJoins);

  if (mssqlAliased) {
    sqlHelper.addSqlSnippet('DELETE ');
    sqlHelper.addSqlSnippet(alias.isNotEmpty ? quote(alias) : qualified);

    if (state.returningState != null) {
      emitMssqlOutputClause(sqlHelper, config, state.returningState!, 'DELETED',
          ParserArea.delete);
    }

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

    return sqlHelper;
  }

  if (hasJoins && config.databaseType == DatabaseType.mysql) {
    sqlHelper.addSqlSnippet('DELETE ');
    sqlHelper.addSqlSnippet(alias.isNotEmpty ? quote(alias) : qualified);
    sqlHelper.addSqlSnippet(' FROM ');
    sqlHelper.addSqlSnippet(qualified);

    if (alias.isNotEmpty) {
      sqlHelper.addSqlSnippet(' AS ');
      sqlHelper.addSqlSnippet(quote(alias));
    }

    final join = defaultJoin(state, config, mode, options);
    sqlHelper.addSqlSnippet(' ');
    sqlHelper.addSqlSnippetWithValues(join.getSql(), join.getValues());

    return sqlHelper;
  }

  sqlHelper.addSqlSnippet('DELETE FROM ');
  sqlHelper.addSqlSnippet(qualified);

  if (alias.isNotEmpty) {
    sqlHelper.addSqlSnippet(' AS ');
    sqlHelper.addSqlSnippet(quote(alias));
  }

  if (state.returningState != null &&
      config.databaseType == DatabaseType.mssql) {
    emitMssqlOutputClause(
        sqlHelper, config, state.returningState!, 'DELETED', ParserArea.delete);
  }

  if (hasJoins && config.databaseType == DatabaseType.postgres) {
    final using = renderPostgresMutationFrom(
        config, state, mode, options, ParserArea.delete);
    sqlHelper.addSqlSnippet(' USING ');
    sqlHelper.addSqlSnippetWithValues(using.getSql(), using.getValues());
  }

  return sqlHelper;
}
