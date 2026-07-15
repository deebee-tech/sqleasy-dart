/// The SQL accumulator: collects fragments and bound values while a parser walks a query state.
library;

import 'enums.dart';
import 'errors/parser_error.dart';
import 'values/sql_value.dart';

const _nul = '\u0000';

/// Marks where one bound value sits in a prepared-mode SQL string, until the final pass swaps it for
/// the dialect's real placeholder.
///
/// The clause walk must NOT emit the dialect's own `?`/`$` directly. The final pass locates
/// placeholders by scanning the rendered SQL, and a `?` or `$` inside a caller-supplied raw fragment
/// is indistinguishable from a real one — `selectRaw("'why?' AS q")` had its literal rewritten while
/// the true placeholder was left dangling. A NUL byte cannot appear in a raw fragment or an
/// identifier (both reject it), so this token cannot be forged from caller text.
const placeholderToken = '$_nul?$_nul';

/// Replaces each [placeholderToken] with the dialect's placeholder, in emission order. [nth] receives
/// the zero-based index, which Postgres needs for `$1`, `$2`, … and MSSQL for `@p0`, `@p1`, ….
String renderPlaceholders(String sql, String Function(int index) nth) {
  final parts = sql.split(placeholderToken);
  final buffer = StringBuffer(parts.first);
  for (var i = 1; i < parts.length; i++) {
    buffer.write(nth(i - 1));
    buffer.write(parts[i]);
  }
  return buffer.toString();
}

/// Accumulates SQL fragments and their bound values while a parser walks a query state.
///
/// Deliberately dialect-agnostic: it emits [placeholderToken], never a dialect's `?`/`$`, so it needs
/// no [Dialect]. The dialect's placeholder is applied once, at the top-level parse.
class SqlHelper {
  SqlHelper(this._parserMode);

  final List<String> _parts = [];
  final List<Object?> _values = [];
  final ParserMode _parserMode;

  /// Emits one bound value: a [placeholderToken] in prepared mode (with the value recorded for
  /// binding), or the value inlined in raw mode.
  ///
  /// Appends directly rather than returning text for the caller to pass back through [addSqlSnippet],
  /// so that `addSqlSnippet` can reject *every* NUL byte it sees — otherwise it could not tell our
  /// token from a NUL sequence in a caller's raw fragment.
  void addDynamicValue(Object? value) {
    assertBindableValue(value);
    final normalized = normalizeBoundValue(value);

    if (_parserMode == ParserMode.prepared) {
      _values.add(normalized);
      _parts.add(placeholderToken);
      return;
    }

    _parts.add(valueToDebugString(normalized));
  }

  /// Appends a SQL fragment. Every caller-supplied raw fragment takes this path, so a NUL byte is
  /// refused outright: it could forge a [placeholderToken] and steal a bound value's position, and it
  /// silently truncates the statement in some drivers.
  void addSqlSnippet(String sql) {
    if (sql.contains(_nul)) {
      throw ParserError(ParserArea.general, 'SQL fragment contains a NUL byte');
    }
    _parts.add(sql);
  }

  /// Splices a sub-parser's already-rendered SQL and its bound values into this helper. The sub-SQL
  /// legitimately carries [placeholderToken]s, so it bypasses the NUL check — its own fragments were
  /// validated when the sub-parser built them.
  void addSqlSnippetWithValues(String sqlString, List<Object?> values) {
    _values.addAll(values);
    _parts.add(sqlString);
  }

  void clear() {
    _parts.clear();
    _values.clear();
  }

  /// The rendered SQL, still carrying [placeholderToken] for each bound value. The top-level parse
  /// swaps the tokens for the dialect's placeholder via [renderPlaceholders].
  String getSql() => _parts.join();

  /// DEBUG / TEST rendering only — inlines each value UNQUOTED and UNESCAPED. Not execution-safe.
  String getSqlDebug() {
    final values = _values;
    return renderPlaceholders(
      _parts.join(),
      (index) => index < values.length ? valueToDebugString(values[index]) : '',
    );
  }

  /// One value per emitted placeholder — never filtered. Stripping null would shift every later bound
  /// parameter by one and corrupt the write. SQL NULL is a bound null.
  List<Object?> getValues() => List.of(_values);
}
