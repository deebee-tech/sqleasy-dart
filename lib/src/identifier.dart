/// Identifier quoting and escaping.
library;

import 'configuration.dart';
import 'errors/parser_error.dart';

/// Quotes a SQL identifier (schema/table/column/alias) for a dialect, escaping any embedded closing
/// delimiter by doubling it — the standard SQL identifier escape (`]`→`]]` for MSSQL, `"`→`""` for
/// Postgres, `` ` ``→`` `` `` for MySQL).
///
/// Identifier names are caller-controlled, so without escaping a name like `x] OR [1=1` would break
/// out of the quoting and inject SQL. A NUL byte can silently truncate the identifier in some
/// drivers, so it is rejected.
String quoteIdentifier(String? name, ConfigurationDelimiters delimiters) {
  // Parser state carries these as nullable; a null name is an empty identifier (the emitting site is
  // guarded so this never fires at runtime) — never the literal "null".
  final id = name ?? '';
  if (id.contains('\u0000')) {
    throw ParserError(ParserArea.general, 'identifier contains a NUL byte');
  }
  final escaped =
      id.split(delimiters.end).join(delimiters.end + delimiters.end);
  return delimiters.begin + escaped + delimiters.end;
}
