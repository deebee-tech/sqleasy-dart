import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';

SqlHelper defaultDelete(QueryState state, Dialect config, ParserMode mode) {
  final sqlHelper = SqlHelper(mode);

  if (state.fromStates.isEmpty) {
    throw ParserError(ParserArea.delete, 'DELETE requires a table');
  }

  final delim = config.identifierDelimiters;
  String quote(String s) => quoteIdentifier(s, delim);

  final fromState = state.fromStates[0];
  final owner = fromState.owner ?? '';
  final alias = fromState.alias ?? '';

  if (owner.isNotEmpty && config.databaseType == DatabaseType.mysql) {
    throw ParserError(
        ParserArea.delete, 'MySQL does not support table owners');
  }

  final qualified = (owner.isNotEmpty ? '${quote(owner)}.' : '') +
      quote(fromState.tableName ?? '');

  // T-SQL has no `DELETE FROM table AS alias` — the aliased form is
  // `DELETE [alias] FROM [tbl] AS [alias]`.
  if (alias.isNotEmpty && config.databaseType == DatabaseType.mssql) {
    sqlHelper.addSqlSnippet('DELETE ');
    sqlHelper.addSqlSnippet(quote(alias));
    sqlHelper.addSqlSnippet(' FROM ');
    sqlHelper.addSqlSnippet(qualified);
    sqlHelper.addSqlSnippet(' AS ');
    sqlHelper.addSqlSnippet(quote(alias));
    return sqlHelper;
  }

  sqlHelper.addSqlSnippet('DELETE FROM ');
  sqlHelper.addSqlSnippet(qualified);

  if (alias.isNotEmpty) {
    sqlHelper.addSqlSnippet(' AS ');
    sqlHelper.addSqlSnippet(quote(alias));
  }

  return sqlHelper;
}
