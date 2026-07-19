import '../configuration.dart';
import '../enums.dart';
import '../errors/parser_error.dart';
import '../identifier.dart';
import '../sql_helper.dart';
import '../state.dart';

const _area = ParserArea.call;

/// `name`/variable identifiers are spliced into the SQL as bare syntax (`@name`, `name :=`), never
/// through [quoteIdentifier] — quoting a T-SQL local variable or a MySQL session variable is not
/// valid syntax at all. Since that text is not a bound value either, it must be restricted to a
/// safe identifier shape here, or a caller-supplied name could inject arbitrary SQL.
final _safeNamePattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

void _assertSafeParamName(String name) {
  if (!_safeNamePattern.hasMatch(name)) {
    throw ParserError(_area, 'invalid parameter/variable name: "$name"');
  }
}

String _qualifiedCallName(Dialect config, String? owner, String name) {
  var out = '';
  if ((owner ?? '').isNotEmpty) {
    out += '${quoteIdentifier(owner, config.identifierDelimiters)}.';
  }
  out += quoteIdentifier(name, config.identifierDelimiters);
  return out;
}

/// Emits one argument's value/raw text — shared by every dialect's `In`/`InOut` handling.
void _emitArgValue(SqlHelper sqlHelper, CallParamState param) {
  if (param.raw != null) {
    sqlHelper.addSqlSnippet(param.raw!);
    return;
  }
  sqlHelper.addDynamicValue(param.value);
}

// ---------------------------------------------------------------------------
// Postgres: `CALL name(...)` for procedures, `SELECT name(...)` /
// `SELECT * FROM name(...)` for functions. No variables exist — an `Out`
// argument is simply passed as NULL; named args are `name := value`.
// ---------------------------------------------------------------------------

void _emitPostgresArgs(SqlHelper sqlHelper, List<CallParamState> params) {
  sqlHelper.addSqlSnippet('(');

  var sawNamed = false;
  for (var i = 0; i < params.length; i++) {
    final param = params[i];
    final named = param.name != null;

    if (named) {
      sawNamed = true;
    } else if (sawNamed) {
      throw ParserError(
          _area, 'a positional argument cannot follow a named argument');
    }

    if (named) {
      _assertSafeParamName(param.name!);
      sqlHelper.addSqlSnippet('${param.name} := ');
    }

    if (param.raw != null) {
      sqlHelper.addSqlSnippet(param.raw!);
    } else if (param.direction == CallParamDirection.out) {
      // No variables in Postgres — the OUT value comes back as a result column of the CALL; the
      // argument slot itself is just a placeholder.
      sqlHelper.addDynamicValue(null);
    } else {
      sqlHelper.addDynamicValue(param.value);
    }

    if (i < params.length - 1) {
      sqlHelper.addSqlSnippet(', ');
    }
  }

  sqlHelper.addSqlSnippet(')');
}

void _emitPostgresCall(SqlHelper sqlHelper, Dialect config, CallState call) {
  if (call.kind == CallKind.procedure) {
    sqlHelper.addSqlSnippet('CALL ');
  } else if (call.returnIntent == CallReturnIntent.resultSet) {
    sqlHelper.addSqlSnippet('SELECT * FROM ');
  } else {
    sqlHelper.addSqlSnippet('SELECT ');
  }

  sqlHelper.addSqlSnippet(_qualifiedCallName(config, call.owner, call.name));
  _emitPostgresArgs(sqlHelper, call.params);
}

// ---------------------------------------------------------------------------
// MySQL: `CALL name(...)` for procedures, `SELECT name(...)` for functions
// (no table-valued functions). No named-argument syntax at all; OUT/INOUT
// arguments are session variables (`@name`), referenced positionally. An
// InOut parameter needs its variable seeded first, via a prefixed `SET`.
// ---------------------------------------------------------------------------

void _emitMysqlArgs(SqlHelper sqlHelper, List<CallParamState> params) {
  sqlHelper.addSqlSnippet('(');

  for (var i = 0; i < params.length; i++) {
    final param = params[i];

    if (param.name != null && param.direction == CallParamDirection.in_) {
      throw ParserError(
          _area, 'MySQL does not support named parameters in CALL');
    }

    if (param.raw != null) {
      sqlHelper.addSqlSnippet(param.raw!);
    } else if (param.direction == CallParamDirection.out ||
        param.direction == CallParamDirection.inOut) {
      if ((param.name ?? '').isEmpty) {
        throw ParserError(_area,
            'OUT/INOUT parameters require a session variable name on MySQL');
      }
      _assertSafeParamName(param.name!);
      sqlHelper.addSqlSnippet('@${param.name}');
    } else {
      sqlHelper.addDynamicValue(param.value);
    }

    if (i < params.length - 1) {
      sqlHelper.addSqlSnippet(', ');
    }
  }

  sqlHelper.addSqlSnippet(')');
}

void _emitMysqlCall(SqlHelper sqlHelper, Dialect config, CallState call) {
  if (call.kind == CallKind.function) {
    if (call.returnIntent == CallReturnIntent.resultSet) {
      throw ParserError(_area, 'MySQL does not support table-valued functions');
    }

    sqlHelper.addSqlSnippet('SELECT ');
    sqlHelper.addSqlSnippet(_qualifiedCallName(config, call.owner, call.name));
    _emitMysqlArgs(sqlHelper, call.params);
    return;
  }

  // Seed every InOut session variable before the CALL — MySQL user variables carry over between
  // statements in the same session, but a fresh one is untyped/NULL, so InOut needs an explicit
  // starting value.
  for (final param in call.params) {
    if (param.direction == CallParamDirection.inOut) {
      _assertSafeParamName(param.name!);
      sqlHelper.addSqlSnippet('SET @${param.name} = ');
      sqlHelper.addDynamicValue(param.value);
      sqlHelper.addSqlSnippet('; ');
    }
  }

  sqlHelper.addSqlSnippet('CALL ');
  sqlHelper.addSqlSnippet(_qualifiedCallName(config, call.owner, call.name));
  _emitMysqlArgs(sqlHelper, call.params);
}

// ---------------------------------------------------------------------------
// MSSQL: `EXEC name ...` for procedures, `SELECT name(...)` (scalar) /
// `SELECT * FROM name(...)` (table-valued) for functions. OUT/INOUT
// parameters need a `DECLARE`d local variable, emitted ahead of the EXEC, and
// are always referenced in named form (`@name = @name OUTPUT`) so they can
// mix freely with positional IN arguments earlier in the call.
// ---------------------------------------------------------------------------

void _emitMssqlDeclarations(SqlHelper sqlHelper, List<CallParamState> params) {
  for (final param in params) {
    if (param.direction != CallParamDirection.out &&
        param.direction != CallParamDirection.inOut) {
      continue;
    }

    if ((param.name ?? '').isEmpty) {
      throw ParserError(
          _area, 'OUT/INOUT parameters require a variable name on MSSQL');
    }
    if ((param.sqlType ?? '').isEmpty) {
      throw ParserError(
          _area, 'OUT/INOUT parameters require an explicit sqlType on MSSQL');
    }
    _assertSafeParamName(param.name!);

    sqlHelper.addSqlSnippet('DECLARE @${param.name} ${param.sqlType}');
    if (param.direction == CallParamDirection.inOut) {
      sqlHelper.addSqlSnippet(' = ');
      sqlHelper.addDynamicValue(param.value);
    }
    sqlHelper.addSqlSnippet('; ');
  }
}

void _emitMssqlProcedureArgs(SqlHelper sqlHelper, List<CallParamState> params) {
  if (params.isEmpty) {
    return;
  }

  sqlHelper.addSqlSnippet(' ');

  var sawNamed = false;
  for (var i = 0; i < params.length; i++) {
    final param = params[i];
    final hasVariable = param.direction == CallParamDirection.out ||
        param.direction == CallParamDirection.inOut;
    // OUT/INOUT are always emitted in named form (`@name = @name OUTPUT`), so they may follow
    // positional IN arguments without breaking T-SQL's positional-before-named ordering rule.
    final named = hasVariable || param.name != null;

    if (named) {
      sawNamed = true;
    } else if (sawNamed) {
      throw ParserError(
          _area, 'a positional argument cannot follow a named argument');
    }

    if (hasVariable) {
      // `name` was already validated by `_emitMssqlDeclarations`.
      sqlHelper.addSqlSnippet('@${param.name} = @${param.name} OUTPUT');
    } else if (param.raw != null) {
      sqlHelper.addSqlSnippet(param.raw!);
    } else {
      if (param.name != null) {
        _assertSafeParamName(param.name!);
        sqlHelper.addSqlSnippet('@${param.name} = ');
      }
      // `param.raw` is already handled by the branch above — only a bound value reaches here.
      sqlHelper.addDynamicValue(param.value);
    }

    if (i < params.length - 1) {
      sqlHelper.addSqlSnippet(', ');
    }
  }
}

void _emitMssqlFunctionArgs(SqlHelper sqlHelper, List<CallParamState> params) {
  sqlHelper.addSqlSnippet('(');

  for (var i = 0; i < params.length; i++) {
    final param = params[i];
    if (param.name != null) {
      throw ParserError(_area,
          'MSSQL does not support named parameters when invoking a function');
    }

    _emitArgValue(sqlHelper, param);

    if (i < params.length - 1) {
      sqlHelper.addSqlSnippet(', ');
    }
  }

  sqlHelper.addSqlSnippet(')');
}

void _emitMssqlCall(SqlHelper sqlHelper, Dialect config, CallState call) {
  _emitMssqlDeclarations(sqlHelper, call.params);

  if (call.kind == CallKind.procedure) {
    sqlHelper.addSqlSnippet('EXEC ');
    sqlHelper.addSqlSnippet(_qualifiedCallName(config, call.owner, call.name));
    _emitMssqlProcedureArgs(sqlHelper, call.params);
    return;
  }

  sqlHelper.addSqlSnippet(call.returnIntent == CallReturnIntent.resultSet
      ? 'SELECT * FROM '
      : 'SELECT ');
  sqlHelper.addSqlSnippet(_qualifiedCallName(config, call.owner, call.name));
  _emitMssqlFunctionArgs(sqlHelper, call.params);
}

/// Renders a `CALL`/`EXEC`/`SELECT func(...)` statement for [QueryState.callState]. SQLite has no
/// stored procedures or functions at all and refuses every call outright. OUT/INOUT parameters are
/// refused for functions on every dialect — a function's result is its return expression, not an
/// output parameter, and none of the `SELECT`-based function emissions below have anywhere to put
/// one.
SqlHelper defaultCall(QueryState state, Dialect config, ParserMode mode) {
  final sqlHelper = SqlHelper(mode);

  final callState = state.callState;
  if (callState == null) {
    throw ParserError(_area, 'No call state provided');
  }

  if (callState.name.isEmpty) {
    throw ParserError(_area, 'callProcedure/callFunction requires a name');
  }

  if (config.databaseType == DatabaseType.sqlite) {
    throw ParserError(_area,
        'SQLite does not support stored procedures or functions (CALL/EXEC)');
  }

  if (callState.kind == CallKind.function) {
    for (final param in callState.params) {
      if (param.direction != CallParamDirection.in_) {
        throw ParserError(
          _area,
          'OUT/INOUT parameters are only supported for procedure calls, not functions',
        );
      }
    }
  }

  if (config.databaseType == DatabaseType.postgres) {
    _emitPostgresCall(sqlHelper, config, callState);
  } else if (config.databaseType == DatabaseType.mysql) {
    _emitMysqlCall(sqlHelper, config, callState);
  } else {
    _emitMssqlCall(sqlHelper, config, callState);
  }

  return sqlHelper;
}
