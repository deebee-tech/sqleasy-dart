import '../configuration.dart';
import '../enums.dart';
import '../sql_helper.dart';
import '../state.dart';
import 'to_sql.dart';

SqlHelper defaultUnion(
  QueryState state,
  Dialect config,
  ParserMode mode, [
  ToSqlOptions? options,
]) {
  final sqlHelper = SqlHelper(mode);

  if (state.unionStates.isEmpty) {
    return sqlHelper;
  }

  for (var i = 0; i < state.unionStates.length; i++) {
    final unionState = state.unionStates[i];

    switch (unionState.builderType) {
      case BuilderType.union:
        sqlHelper.addSqlSnippet('UNION ');
      case BuilderType.unionAll:
        sqlHelper.addSqlSnippet('UNION ALL ');
      case BuilderType.intersect:
        sqlHelper.addSqlSnippet('INTERSECT ');
      case BuilderType.except:
        sqlHelper.addSqlSnippet('EXCEPT ');
      default:
        break;
    }

    if ((unionState.raw ?? '').isNotEmpty) {
      sqlHelper.addSqlSnippet(unionState.raw!);
    } else if (unionState.subquery != null) {
      final subHelper =
          defaultToSql(unionState.subquery, config, mode, options);
      sqlHelper.addSqlSnippetWithValues(
          subHelper.getSql(), subHelper.getValues());
    }

    if (i < state.unionStates.length - 1) {
      sqlHelper.addSqlSnippet(' ');
    }
  }

  return sqlHelper;
}
