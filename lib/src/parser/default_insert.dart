import '../configuration.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';
import '../enums.dart';

SqlHelper defaultInsert(QueryState state, Dialect config, ParserMode mode) {
  final sqlHelper = SqlHelper(mode);

  final insertState = state.insertState;
  if (insertState == null) {
    throw ParserError(ParserArea.general, 'No insert state provided');
  }

  if ((insertState.raw ?? '').isNotEmpty) {
    sqlHelper.addSqlSnippet(insertState.raw!);
    return sqlHelper;
  }

  sqlHelper.addSqlSnippet('INSERT INTO ');

  if ((insertState.owner ?? '').isNotEmpty) {
    sqlHelper.addSqlSnippet(
        quoteIdentifier(insertState.owner, config.identifierDelimiters));
    sqlHelper.addSqlSnippet('.');
  }

  sqlHelper.addSqlSnippet(
      quoteIdentifier(insertState.tableName, config.identifierDelimiters));

  if (insertState.columns.isNotEmpty) {
    sqlHelper.addSqlSnippet(' (');
    for (var i = 0; i < insertState.columns.length; i++) {
      sqlHelper.addSqlSnippet(
        quoteIdentifier(insertState.columns[i], config.identifierDelimiters),
      );

      if (i < insertState.columns.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }
    }
    sqlHelper.addSqlSnippet(')');
  }

  if (insertState.values.isNotEmpty) {
    sqlHelper.addSqlSnippet(' VALUES ');

    for (var r = 0; r < insertState.values.length; r++) {
      sqlHelper.addSqlSnippet('(');

      final row = insertState.values[r];
      for (var c = 0; c < row.length; c++) {
        sqlHelper.addDynamicValue(row[c]);

        if (c < row.length - 1) {
          sqlHelper.addSqlSnippet(', ');
        }
      }

      sqlHelper.addSqlSnippet(')');

      if (r < insertState.values.length - 1) {
        sqlHelper.addSqlSnippet(', ');
      }
    }
  }

  return sqlHelper;
}
