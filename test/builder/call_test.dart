import 'package:sqleasy/sqleasy.dart';
import 'package:sqleasy/src/enums.dart' show QueryType;
import 'package:sqleasy/src/state.dart' show CallParamState;
import 'package:test/test.dart';

/// Mirrors the "Stored procedures & functions (CALL / EXEC)" describe block in the TypeScript
/// port's tests/shared/call.test.ts, adapted to the Dart API (named `owner`/`alias` parameters
/// instead of empty-string sentinels; `builder.state` instead of `builder.state()`).
void main() {
  group('callProcedure', () {
    test('Postgres emits CALL name(...)', () {
      final builder = PostgresQuery().newBuilder();
      builder.callProcedure('archive_user').procParam(42);

      expect(builder.parseRaw(), 'CALL "public"."archive_user"(42);');
      expect(builder.parse(), 'CALL "public"."archive_user"(\$1);');
      final prepared = builder.parsePrepared();
      expect(prepared.sql, 'CALL "public"."archive_user"(\$1);');
      expect(prepared.params, [42]);
    });

    test('Postgres callProcedureWithOwner overrides the default owner', () {
      final builder = PostgresQuery().newBuilder();
      builder.callProcedureWithOwner('sales', 'close_order').procParam(7);

      expect(builder.parseRaw(), 'CALL "sales"."close_order"(7);');
    });

    test('MySQL emits CALL name(...) with no owner by default', () {
      final builder = MysqlQuery().newBuilder();
      builder.callProcedure('archive_user').procParam(42);

      expect(builder.parseRaw(), 'CALL `archive_user`(42);');
      final prepared = builder.parsePrepared();
      expect(prepared.sql, 'CALL `archive_user`(?);');
      expect(prepared.params, [42]);
    });

    test('MSSQL emits EXEC name ...', () {
      final builder = MssqlQuery().newBuilder();
      builder.callProcedure('archive_user').procParam(42);

      expect(builder.parseRaw(), 'EXEC [dbo].[archive_user] 42;');
    });

    test('MSSQL EXEC with no parameters omits the trailing space', () {
      final builder = MssqlQuery().newBuilder();
      builder.callProcedure('cleanup');

      expect(builder.parseRaw(), 'EXEC [dbo].[cleanup];');
    });

    test('SQLite has no stored procedures/functions and throws', () {
      final builder = SqliteQuery().newBuilder();
      builder.callProcedure('archive_user').procParam(42);

      expect(
        () => builder.parsePrepared(),
        throwsA(isA<ParserError>().having(
            (e) => e.toString(),
            'message',
            contains(
                'SQLite does not support stored procedures or functions (CALL/EXEC)'))),
      );
    });

    test('a call requires a name', () {
      final builder = PostgresQuery().newBuilder();
      builder.callProcedure('');

      expect(
        () => builder.parsePrepared(),
        throwsA(isA<ParserError>().having((e) => e.toString(), 'message',
            contains('callProcedure/callFunction requires a name'))),
      );
    });

    test('throws when no call state is provided', () {
      final builder = PostgresQuery().newBuilder();
      builder.selectAll();
      builder.state.queryType = QueryType.call;

      expect(
        () => builder.parseRaw(),
        throwsA(isA<ParserError>().having((e) => e.toString(), 'message',
            contains('No call state provided'))),
      );
    });

    test('MSSQL OUT/INOUT parameters require a variable name', () {
      final builder = MssqlQuery().newBuilder();
      builder.callProcedure('archive_user');
      builder.state.callState!.params.add(CallParamState()
        ..direction = CallParamDirection.out
        ..sqlType = 'INT');

      expect(
        () => builder.parsePrepared(),
        throwsA(isA<ParserError>().having((e) => e.toString(), 'message',
            contains('OUT/INOUT parameters require a variable name on MSSQL'))),
      );
    });
  });

  group('callFunction', () {
    test('Postgres scalar emits SELECT name(...)', () {
      final builder = PostgresQuery().newBuilder();
      builder.callFunction('add_two').procParam(1).procParam(2);

      expect(builder.parseRaw(), 'SELECT "public"."add_two"(1, 2);');
    });

    test('Postgres ResultSet emits SELECT * FROM name(...)', () {
      final builder = PostgresQuery().newBuilder();
      builder
          .callFunction('users_over', CallReturnIntent.resultSet)
          .procParam(18);

      expect(builder.parseRaw(), 'SELECT * FROM "public"."users_over"(18);');
    });

    test('MySQL scalar emits SELECT name(...)', () {
      final builder = MysqlQuery().newBuilder();
      builder.callFunction('add_two').procParam(1).procParam(2);

      expect(builder.parseRaw(), 'SELECT `add_two`(1, 2);');
    });

    test('MySQL refuses a table-valued (ResultSet) function', () {
      final builder = MysqlQuery().newBuilder();
      builder
          .callFunction('users_over', CallReturnIntent.resultSet)
          .procParam(18);

      expect(
        () => builder.parsePrepared(),
        throwsA(isA<ParserError>().having((e) => e.toString(), 'message',
            contains('MySQL does not support table-valued functions'))),
      );
    });

    test('MSSQL scalar emits SELECT name(...)', () {
      final builder = MssqlQuery().newBuilder();
      builder.callFunction('add_two').procParam(1).procParam(2);

      expect(builder.parseRaw(), 'SELECT [dbo].[add_two](1, 2);');
    });

    test('MSSQL ResultSet emits SELECT * FROM name(...)', () {
      final builder = MssqlQuery().newBuilder();
      builder
          .callFunction('users_over', CallReturnIntent.resultSet)
          .procParam(18);

      expect(builder.parseRaw(), 'SELECT * FROM [dbo].[users_over](18);');
    });

    test('callFunction refuses CallReturnIntent.voidReturn', () {
      final builder = PostgresQuery().newBuilder();

      expect(
        () => builder.callFunction('add_two', CallReturnIntent.voidReturn),
        throwsA(isA<ParserError>().having(
            (e) => e.toString(),
            'message',
            contains(
                'callFunction requires CallReturnIntent.Scalar or CallReturnIntent.ResultSet'))),
      );
    });

    test('callFunctionWithOwner refuses CallReturnIntent.voidReturn', () {
      final builder = PostgresQuery().newBuilder();

      expect(
        () => builder.callFunctionWithOwner(
            'public', 'add_two', CallReturnIntent.voidReturn),
        throwsA(isA<ParserError>().having(
            (e) => e.toString(),
            'message',
            contains(
                'callFunction requires CallReturnIntent.Scalar or CallReturnIntent.ResultSet'))),
      );
    });

    test('SQLite throws for functions too', () {
      final builder = SqliteQuery().newBuilder();
      builder.callFunction('add_two').procParam(1).procParam(2);

      expect(
        () => builder.parsePrepared(),
        throwsA(isA<ParserError>().having(
            (e) => e.toString(),
            'message',
            contains(
                'SQLite does not support stored procedures or functions (CALL/EXEC)'))),
      );
    });
  });

  group('named parameters', () {
    test('Postgres procParamNamed emits name := value', () {
      final builder = PostgresQuery().newBuilder();
      builder
          .callProcedure('set_status')
          .procParamNamed('user_id', 1)
          .procParamNamed('status', 'active');

      expect(
        builder.parseRaw(),
        'CALL "public"."set_status"(user_id := 1, status := active);',
      );
    });

    test('Postgres refuses a positional argument after a named one', () {
      final builder = PostgresQuery().newBuilder();
      builder
          .callProcedure('set_status')
          .procParamNamed('user_id', 1)
          .procParam('active');

      expect(
        () => builder.parsePrepared(),
        throwsA(isA<ParserError>().having((e) => e.toString(), 'message',
            contains('a positional argument cannot follow a named argument'))),
      );
    });

    test('MSSQL procParamNamed emits @name = value', () {
      final builder = MssqlQuery().newBuilder();
      builder.callProcedure('set_status').procParamNamed('user_id', 1);

      expect(builder.parseRaw(), 'EXEC [dbo].[set_status] @user_id = 1;');
    });

    test('MSSQL refuses a positional argument after a named one', () {
      final builder = MssqlQuery().newBuilder();
      builder
          .callProcedure('set_status')
          .procParamNamed('user_id', 1)
          .procParam('active');

      expect(
        () => builder.parsePrepared(),
        throwsA(isA<ParserError>().having((e) => e.toString(), 'message',
            contains('a positional argument cannot follow a named argument'))),
      );
    });

    test('MySQL refuses named parameters entirely', () {
      final builder = MysqlQuery().newBuilder();
      builder.callProcedure('set_status').procParamNamed('user_id', 1);

      expect(
        () => builder.parsePrepared(),
        throwsA(isA<ParserError>().having((e) => e.toString(), 'message',
            contains('MySQL does not support named parameters in CALL'))),
      );
    });

    test('MSSQL functions refuse named parameters', () {
      final builder = MssqlQuery().newBuilder();
      builder.callFunction('add_two').procParamNamed('a', 1).procParam(2);

      expect(
        () => builder.parsePrepared(),
        throwsA(isA<ParserError>().having(
            (e) => e.toString(),
            'message',
            contains(
                'MSSQL does not support named parameters when invoking a function'))),
      );
    });

    test('invalid names are rejected rather than spliced into the SQL', () {
      final builder = PostgresQuery().newBuilder();
      builder
          .callProcedure('set_status')
          .procParamNamed('user_id); DROP TABLE users; --', 1);

      expect(
        () => builder.parsePrepared(),
        throwsA(isA<ParserError>().having((e) => e.toString(), 'message',
            contains('invalid parameter/variable name'))),
      );
    });
  });

  group('raw parameters', () {
    test('procParamRaw is spliced verbatim as an argument', () {
      final builder = PostgresQuery().newBuilder();
      builder
          .callProcedure('bump_score')
          .procParam(1)
          .procParamRaw('score + 1');

      expect(builder.parseRaw(), 'CALL "public"."bump_score"(1, score + 1);');
    });

    test('MSSQL procedures splice a raw argument in positionally', () {
      final builder = MssqlQuery().newBuilder();
      builder
          .callProcedure('bump_score')
          .procParam(1)
          .procParamRaw('score + 1');

      expect(builder.parseRaw(), 'EXEC [dbo].[bump_score] 1, score + 1;');
    });

    test('MSSQL functions splice a raw argument in positionally', () {
      final builder = MssqlQuery().newBuilder();
      builder.callFunction('bump_score').procParam(1).procParamRaw('score + 1');

      expect(builder.parseRaw(), 'SELECT [dbo].[bump_score](1, score + 1);');
    });
  });

  group('OUT / INOUT parameters', () {
    test('MSSQL procParamOut declares a variable and emits it as OUTPUT', () {
      final builder = MssqlQuery().newBuilder();
      builder
          .callProcedure('archive_user')
          .procParam(42)
          .procParamOut('archived_count', 'INT');

      expect(
        builder.parseRaw(),
        'DECLARE @archived_count INT; '
        'EXEC [dbo].[archive_user] 42, @archived_count = @archived_count OUTPUT;',
      );
    });

    test('MSSQL procParamOut requires an explicit sqlType', () {
      final builder = MssqlQuery().newBuilder();
      builder.callProcedure('archive_user').procParamOut('archived_count');

      expect(
        () => builder.parsePrepared(),
        throwsA(isA<ParserError>().having(
            (e) => e.toString(),
            'message',
            contains(
                'OUT/INOUT parameters require an explicit sqlType on MSSQL'))),
      );
    });

    test(
        'MSSQL procParamInOut declares and seeds the variable, bound as a parameter',
        () {
      final builder = MssqlQuery().newBuilder();
      builder
          .callProcedure('adjust_balance')
          .procParamInOut('balance', 100, 'INT');

      expect(
        builder.parseRaw(),
        'DECLARE @balance INT = 100; '
        'EXEC [dbo].[adjust_balance] @balance = @balance OUTPUT;',
      );

      // MSSQL inlines every value into a self-contained `sp_executesql` batch, so `parsePrepared`
      // carries no separate `params` here (same contract as every other MSSQL statement).
      final prepared = builder.parsePrepared();
      expect(prepared.params, isEmpty);
      expect(prepared.sql, contains('DECLARE @balance INT = @p0;'));
      expect(prepared.sql, contains('@p0 = 100'));
    });

    test(
        'MySQL procParamOut references a session variable positionally, no DECLARE needed',
        () {
      final builder = MysqlQuery().newBuilder();
      builder
          .callProcedure('archive_user')
          .procParam(42)
          .procParamOut('archived_count');

      expect(builder.parseRaw(), 'CALL `archive_user`(42, @archived_count);');
    });

    test('MySQL procParamOut requires a session variable name', () {
      final builder = MysqlQuery().newBuilder();
      final call = builder.callProcedure('archive_user');
      call.state.callState!.params
          .add(CallParamState()..direction = CallParamDirection.out);

      expect(
        () => builder.parsePrepared(),
        throwsA(isA<ParserError>().having(
            (e) => e.toString(),
            'message',
            contains(
                'OUT/INOUT parameters require a session variable name on MySQL'))),
      );
    });

    test('MySQL procParamInOut seeds the session variable via a prefixed SET',
        () {
      final builder = MysqlQuery().newBuilder();
      builder
          .callProcedure('adjust_balance')
          .procParam(7)
          .procParamInOut('balance', 100);

      expect(builder.parseRaw(),
          'SET @balance = 100; CALL `adjust_balance`(7, @balance);');

      final prepared = builder.parsePrepared();
      expect(prepared.sql,
          'SET @balance = ?; CALL `adjust_balance`(?, @balance);');
      expect(prepared.params, [100, 7]);
    });

    test(
        'Postgres procParamOut passes NULL — there are no variables to declare',
        () {
      final builder = PostgresQuery().newBuilder();
      builder
          .callProcedure('archive_user')
          .procParam(42)
          .procParamOut('archived_count');

      final prepared = builder.parsePrepared();
      expect(prepared.sql,
          'CALL "public"."archive_user"(\$1, archived_count := \$2);');
      expect(prepared.params, [42, null]);
    });

    test('OUT/INOUT parameters are refused on function calls', () {
      final builder = PostgresQuery().newBuilder();
      builder.callFunction('add_two').procParam(1).procParamOut('result');

      expect(
        () => builder.parsePrepared(),
        throwsA(isA<ParserError>().having(
            (e) => e.toString(),
            'message',
            contains(
                'OUT/INOUT parameters are only supported for procedure calls, not functions'))),
      );
    });
  });

  group('combinations refused elsewhere', () {
    test('a CTE cannot be combined with a call', () {
      final builder = PostgresQuery().newBuilder();
      builder
          .cteRaw('recent', 'SELECT 1')
          .callProcedure('archive_user')
          .procParam(1);

      expect(
        () => builder.parsePrepared(),
        throwsA(isA<ParserError>().having(
            (e) => e.toString(),
            'message',
            contains(
                'A CTE cannot be combined with a procedure/function call'))),
      );
    });

    test('RETURNING cannot be combined with a call', () {
      final builder = PostgresQuery().newBuilder();
      builder.callProcedure('archive_user').procParam(1);
      builder.returning(['id']);

      expect(
        () => builder.parsePrepared(),
        throwsA(isA<ParserError>().having(
            (e) => e.toString(),
            'message',
            contains(
                'RETURNING/OUTPUT cannot be combined with a procedure/function call'))),
      );
    });

    test('calling a procParam* method before callProcedure/callFunction throws',
        () {
      final builder = PostgresQuery().newBuilder();

      expect(
        () => builder.procParam(1),
        throwsA(isA<ParserError>().having(
            (e) => e.toString(),
            'message',
            contains(
                'call a procParam* method only after callProcedure/callFunction'))),
      );
    });

    test(
        'selecting after a call resets the query type, and the stale call state then throws',
        () {
      final builder = PostgresQuery().newBuilder();
      builder.callProcedure('archive_user').procParam(1);
      builder.selectAll().fromTable('users', alias: 'u');

      expect(
        () => builder.parsePrepared(),
        throwsA(isA<ParserError>().having((e) => e.toString(), 'message',
            contains('Procedure/function call state requires queryType Call'))),
      );
    });
  });

  group('clearCall', () {
    test('removes a previously configured call and resets the query type', () {
      final builder = PostgresQuery().newBuilder();
      builder.callProcedure('archive_user').procParam(1);
      builder.clearCall();

      expect(builder.state.callState, isNull);
      builder.selectAll().fromTable('users', alias: 'u');
      expect(builder.parseRaw(), 'SELECT * FROM "public"."users" AS "u";');
    });
  });

  group('procParams', () {
    test('appends several positional IN arguments in order', () {
      final builder = PostgresQuery().newBuilder();
      builder.callProcedure('add_three').procParams([1, 2, 3]);

      expect(builder.parseRaw(), 'CALL "public"."add_three"(1, 2, 3);');
    });
  });

  group('MultiBuilder integration', () {
    test('a call can be batched alongside other statements', () {
      final multi = PostgresQuery().newMultiBuilder();
      multi.setTransactionState(MultiBuilderTransactionState.transactionOff);
      multi.addBuilder('archive').callProcedure('archive_user').procParam(1);
      multi.addBuilder('select').selectAll().fromTable('users', alias: 'u');

      expect(
        multi.parseRaw(),
        'CALL "public"."archive_user"(1);SELECT * FROM "public"."users" AS "u";',
      );

      final prepared = multi.preparedStatements();
      expect(prepared[0].sql, 'CALL "public"."archive_user"(\$1);');
      expect(prepared[0].params, [1]);
    });
  });
}
