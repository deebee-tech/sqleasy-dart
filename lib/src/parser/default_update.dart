import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';

SqlHelper defaultUpdate(QueryState state, Dialect config, ParserMode mode) {
  final sqlHelper = SqlHelper(mode);

  if (state.fromStates.isEmpty) {
    throw ParserError(ParserArea.general, 'UPDATE requires a table');
  }

  if (state.updateStates.isEmpty) {
    throw ParserError(
        ParserArea.general, 'UPDATE requires at least one SET column');
  }

  final delim = config.identifierDelimiters;
  String quote(String s) => quoteIdentifier(s, delim);

  final fromState = state.fromStates[0];
  final owner = fromState.owner ?? '';
  final alias = fromState.alias ?? '';
  final qualified = (owner.isNotEmpty ? '${quote(owner)}.' : '') +
      quote(fromState.tableName ?? '');
  // T-SQL has no `UPDATE table AS alias` — the alias must come from a FROM clause:
  // `UPDATE [alias] SET ... FROM [tbl] AS [alias]`.
  final mssqlAliased =
      alias.isNotEmpty && config.databaseType == DatabaseType.mssql;

  sqlHelper.addSqlSnippet('UPDATE ');

  if (mssqlAliased) {
    sqlHelper.addSqlSnippet(quote(alias));
  } else {
    sqlHelper.addSqlSnippet(qualified);
    if (alias.isNotEmpty) {
      sqlHelper.addSqlSnippet(' AS ');
      sqlHelper.addSqlSnippet(quote(alias));
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

  if (mssqlAliased) {
    sqlHelper.addSqlSnippet(' FROM ');
    sqlHelper.addSqlSnippet(qualified);
    sqlHelper.addSqlSnippet(' AS ');
    sqlHelper.addSqlSnippet(quote(alias));
  }

  return sqlHelper;
}
