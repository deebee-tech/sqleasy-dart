/// MSSQL's `sp_executesql` parameter rendering.
///
/// MSSQL is the one dialect where inlined literal formatting is *executed* rather than merely
/// displayed: `parsePrepared()` wraps the statement in `exec sp_executesql`, declares each parameter
/// with a T-SQL type, and inlines its value — so `params` comes back empty. Every number and date
/// divergence in [sql_value] is therefore a **correctness** bug here, not just a golden-string one.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../errors/parser_error.dart';
import 'sql_value.dart';

String _toHex(Uint8List bytes) {
  final buffer = StringBuffer();
  for (final b in bytes) {
    buffer.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

/// The T-SQL type declared for an `@pN` parameter, inferred from its value.
String mssqlParameterType(Object? value) {
  if (value is Uint8List) {
    return 'varbinary(max)';
  }

  if (value is String) {
    return 'nvarchar(max)';
  }

  if (value is num) {
    if (!value.isFinite) {
      throw ParserError(
          ParserArea.general, 'value is not a finite number: $value');
    }

    // Only a SAFE integer is declared as an integral type. `Number.isInteger(1e21)` is true, but it
    // renders as `1e+21` — not a legal `bigint` literal, so SQL Server rejects the batch. Beyond
    // 2^53 nothing is exactly an integer anyway; `float` accepts scientific notation.
    if (isSafeIntegral(value)) {
      // NOTE: `isIntegral`, not `value is int`. An integral DOUBLE (5.0) must land in exactly the
      // same band as the int 5 — that is what TypeScript does, and the corpus froze it. Using
      // `is int` here would declare `float` on the Dart VM and `tinyint` on dart2js, from one input.
      //
      // T-SQL `tinyint` is UNSIGNED 0–255. A negative in that band raises an arithmetic-overflow
      // error on the whole batch, which is why the lower bound is 0 and not -128.
      if (value >= 0 && value <= 255) {
        return 'tinyint';
      } else if (value >= -32768 && value <= 32767) {
        return 'smallint';
      } else if (value >= -2147483648 && value <= 2147483647) {
        return 'int';
      } else {
        return 'bigint';
      }
    }

    return 'float';
  }

  if (value is bool) {
    return 'bit';
  }

  if (value is BigInt) {
    return 'bigint';
  }

  return 'nvarchar(max)';
}

/// A value as a T-SQL literal for the `sp_executesql` value list.
String mssqlParameterValue(Object? value) {
  if (value == null) {
    return 'NULL';
  }
  if (value is Uint8List) {
    return '0x${_toHex(value)}';
  }
  if (value is num) {
    return formatNumber(value);
  }
  if (value is bool) {
    return value ? '1' : '0';
  }
  if (value is DateTime) {
    return "'${formatDateTime(value)}'";
  }
  if (value is String) {
    return "N'${value.replaceAll("'", "''")}'";
  }
  // Match TypeScript's `typeof 'bigint'` arm: bare decimal digits, declared as `bigint`.
  if (value is BigInt) {
    return value.toString();
  }

  return "N'${jsonEncode(value).replaceAll("'", "''")}'";
}
