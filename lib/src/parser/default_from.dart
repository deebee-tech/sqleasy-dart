import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';
import 'to_sql.dart';

SqlHelper defaultFrom(QueryState state, Dialect config, ParserMode mode) {
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

    if (fromState.builderType == BuilderType.fromBuilder) {
      final subHelper = defaultToSql(fromState.subquery, config, mode);

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
    }
  }

  return sqlHelper;
}
