/// The one place a Dart value becomes SQL text.
///
/// **Nothing outside this file may call `toString()` on a [num] or a [DateTime].** That rule is the
/// entire reason this file exists, and it is not stylistic.
///
/// ## Why
///
/// SQLEasy's contract is defined by a golden corpus generated from the TypeScript implementation,
/// and JavaScript has exactly one number type. Dart has two — and, worse, Dart does not agree with
/// itself about them:
///
/// | expression            | Dart VM (Flutter mobile/desktop) | dart2js (Flutter **web**) |
/// |-----------------------|----------------------------------|---------------------------|
/// | `5.0 is int`          | `false`                          | **`true`**                |
/// | `(5.0).toString()`    | `"5.0"`                          | **`"5"`**                 |
///
/// On dart2js every number is a JavaScript double, so an integral `double` *is* an `int` and prints
/// without a fractional part. On the VM it is not and does not.
///
/// So a port that reaches for `value is int` or `value.toString()` produces **different SQL on
/// Flutter web than on Flutter mobile** for the same input: `5.0` binds as `@p0 tinyint` / `= 5` on
/// the web and `@p0 float` / `= 5.0` on mobile. Nothing throws. The tests pass on whichever platform
/// you happened to run them on.
///
/// Every function here is therefore written to be platform-independent, and the test suite asserts
/// that by running on the VM *and* under dart2js. Running only one cannot catch this class of bug.
library;

import 'dart:convert';

import '../errors/parser_error.dart';

/// Whether [value] should be rendered as an integer. Equivalent to JavaScript's `Number.isInteger`.
///
/// Do NOT reach for `value is int` here, in either clause. That expression is not portable:
///
/// * it is `false` for `5.0` on the Dart VM but `true` for `5.0` on dart2js; and
/// * dart2js compiles it to roughly `Math.floor(x) === x`, and `Math.floor(Infinity) === Infinity`,
///   so **`double.infinity is int` is `true` on the web** and `false` on the VM.
///
/// The second one is not hypothetical — it broke this very function, and the dart2js test run caught
/// it. Testing `isFinite` first, and comparing against `roundToDouble()`, is true on both platforms
/// for `5` and `5.0`, and false on both for `5.5`, `NaN` and `Infinity`.
bool isIntegral(num value) => value.isFinite && value == value.roundToDouble();

/// Whether [value] is an integer that `double` can represent exactly.
///
/// Mirrors JavaScript's `Number.isSafeInteger`, which the MSSQL parameter-type inference depends on:
/// an integer beyond 2^53 is declared `float`, not `bigint`, because it renders in scientific
/// notation (`1e+21`) and T-SQL has no scientific-notation `bigint` literal.
bool isSafeIntegral(num value) =>
    isIntegral(value) && value.abs() <= 9007199254740991; // 2^53 - 1

/// Renders [value] as a SQL numeric literal, identically on every platform and identically to
/// JavaScript — which is what the golden corpus froze.
///
/// Dart's `toString()` and JavaScript's `String(n)` agree on every magnitude *except one thing*:
/// **Dart appends `.0` to an integral double and JavaScript never does.** Verified across the range:
///
/// | value              | JavaScript                | Dart VM                     |
/// |--------------------|---------------------------|-----------------------------|
/// | `5.0`              | `5`                       | `5.0`                       |
/// | `2^53`             | `9007199254740992`        | `9007199254740992.0`        |
/// | `1e20`             | `100000000000000000000`   | `100000000000000000000.0`   |
/// | `1e21`             | `1e+21`                   | `1e+21`      ← agree        |
/// | `5.5`              | `5.5`                     | `5.5`        ← agree        |
///
/// Both switch to exponential notation at 1e21 and produce the same text there, so stripping a
/// trailing `.0` is the entire correction. Under dart2js `toString()` *is* JavaScript's, so it never
/// emits `.0` and the strip is a no-op — which is exactly why this must be tested on both platforms.
String formatNumber(num value) {
  if (!value.isFinite) {
    throw ParserError(
        ParserArea.general, 'value is not a finite number: $value');
  }

  // -0.0 prints as "-0.0" on the Dart VM; JavaScript's String(-0) is "0". Handle it before the
  // strip below, which would otherwise leave "-0".
  if (value == 0) {
    return '0';
  }

  final text = value.toString();

  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// Renders [value] as an ISO 8601 instant, identically to JavaScript's `Date.toISOString()`.
///
/// Two divergences are corrected here:
///
/// * **Zone.** A JS `Date` is an instant and `toISOString()` always converts to UTC and always ends
///   in `Z`. Dart's `toIso8601String()` on a *local* `DateTime` neither converts nor appends `Z`, so
///   `DateTime(2024, 1, 15, 12)` in Berlin would silently render as `2024-01-15T12:00:00.000` —
///   wrong instant, no zone marker.
/// * **Precision.** A JS `Date` holds milliseconds and always prints exactly three fractional
///   digits. Dart's `DateTime` holds *microseconds* and prints six whenever they are non-zero.
String formatDateTime(DateTime value) {
  final utc = value.toUtc();
  final truncated = DateTime.utc(
    utc.year,
    utc.month,
    utc.day,
    utc.hour,
    utc.minute,
    utc.second,
    utc.millisecond,
  );

  return truncated.toIso8601String();
}

/// Normalizes a value for binding or inlining.
///
/// A `DateTime` is reduced to UTC millisecond precision — the same form [formatDateTime] renders, and
/// the most a JavaScript `Date` (and therefore the cross-language contract) can represent. Without
/// this, a bound parameter would carry Dart's microseconds (`.123456Z`) while the TypeScript twin
/// binds `.123Z`, so the two would disagree at the driver boundary even though their SQL text agreed.
/// Everything else passes through unchanged.
Object? normalizeBoundValue(Object? value) {
  if (value is DateTime) {
    final u = value.toUtc();
    return DateTime.utc(
        u.year, u.month, u.day, u.hour, u.minute, u.second, u.millisecond);
  }
  return value;
}

/// Refuses a value that has no SQL representation, at the point it is bound or inlined.
///
/// `NaN`/`double.infinity` would otherwise render as the bare words `NaN`/`Infinity` when inlined
/// (invalid SQL in every dialect) or sail straight into the bound parameters, surfacing as a
/// driver-level error far from the call that caused it. Fail where the caller is.
void assertBindableValue(Object? value) {
  if (value is num && !value.isFinite) {
    throw ParserError(
        ParserArea.general, 'value is not a finite number: $value');
  }
}

/// Renders [value] inline, unquoted and unescaped, for DEBUG / TEST output only.
///
/// This is the Dart twin of TypeScript's `SqlHelper.getValueStringFromDataType`. It is **not
/// execution-safe** — a string `a'b` renders as `= a'b`, not `= 'a''b'` — and exists so the golden
/// corpus can carry readable SQL. Never hand its output to a driver; execute the parameterized
/// `(sql, params)` instead.
String valueToDebugString(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is String) {
    return value;
  }
  if (value is num) {
    return formatNumber(value);
  }
  if (value is bool) {
    return value ? 'true' : 'false';
  }
  if (value is DateTime) {
    return formatDateTime(value);
  }
  if (value is BigInt) {
    return value.toString();
  }

  return jsonEncode(value);
}
