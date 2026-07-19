import '../enums.dart';

/// Pure, per-dialect emit helpers for scalar expressions — the dialect-correctness knowledge for a
/// handful of common functions, factored out so an expression compiler can build normalized SQL
/// without re-deriving each dialect's quirks.
///
/// Every helper takes ALREADY-BUILT operand SQL — quoted/qualified by the caller — plus the target
/// [DatabaseType], and returns a SQL fragment. No identifier quoting, no parameter binding, no
/// `{Column}` resolution: those stay with the caller. This is deliberately NOT an expression AST —
/// just the normalization helpers.
abstract final class Fn {
  /// NULL-skipping string concatenation (spreadsheet-style: one NULL operand must not null the whole
  /// result). MSSQL `CONCAT` already skips NULLs; the others coalesce each operand to `''` — on
  /// Postgres casting to text first, since its `||`/`COALESCE` reject a non-text operand. Pass two
  /// or more operands.
  static String concat(List<String> operands, DatabaseType databaseType) {
    if (databaseType == DatabaseType.mssql) {
      return 'CONCAT(${operands.join(', ')})';
    }
    final parts = operands.map((operand) =>
        databaseType == DatabaseType.postgres
            ? "COALESCE(CAST($operand AS text), '')"
            : "COALESCE($operand, '')");
    return databaseType == DatabaseType.mysql
        ? 'CONCAT(${parts.join(', ')})'
        : '(${parts.join(' || ')})';
  }

  /// Character length (NOT byte length). MySQL `LENGTH()` counts BYTES, so use `CHAR_LENGTH()`;
  /// MSSQL uses `LEN()`; Postgres/SQLite `LENGTH()` already counts characters on text.
  static String charLength(String operand, DatabaseType databaseType) {
    if (databaseType == DatabaseType.mssql) return 'LEN($operand)';
    if (databaseType == DatabaseType.mysql) return 'CHAR_LENGTH($operand)';
    return 'LENGTH($operand)';
  }

  /// Round to `places` decimal places. Postgres has no `round(double precision, integer)` overload —
  /// only `round(numeric, integer)` — so cast to numeric there; the others round a float directly.
  /// `places` is emitted verbatim (pass an `int`/`num` or built SQL `String`).
  static String round(
      String operand, Object places, DatabaseType databaseType) {
    return databaseType == DatabaseType.postgres
        ? 'ROUND(CAST($operand AS numeric), $places)'
        : 'ROUND($operand, $places)';
  }

  /// The current timestamp: `GETDATE()` on MSSQL, `NOW()` on MySQL, `datetime('now')` on SQLite, and
  /// `CURRENT_TIMESTAMP` on Postgres (also the standard fallback for an unset/unknown dialect).
  static String now(DatabaseType databaseType) => switch (databaseType) {
        DatabaseType.mssql => 'GETDATE()',
        DatabaseType.mysql => 'NOW()',
        DatabaseType.sqlite => "datetime('now')",
        _ => 'CURRENT_TIMESTAMP',
      };

  /// Fractional division — `numerator / denominator` that NEVER truncates to integer division.
  /// Postgres, MSSQL, and SQLite do INTEGER division when both operands are integers (`5 / 2` → 2);
  /// MySQL already yields a decimal. This casts the numerator to the dialect's fractional type
  /// (Postgres `numeric`, MSSQL `decimal`, SQLite `REAL`; MySQL left as a plain `/`). Division-by-zero
  /// behavior is the dialect's own — this normalizes the integer-vs-decimal split only.
  static String divide(
          String numerator, String denominator, DatabaseType databaseType) =>
      switch (databaseType) {
        DatabaseType.postgres => '(CAST($numerator AS numeric) / $denominator)',
        DatabaseType.mssql =>
          '(CAST($numerator AS decimal(38, 10)) / $denominator)',
        DatabaseType.sqlite => '(CAST($numerator AS REAL) / $denominator)',
        _ => '($numerator / $denominator)',
      };
}
