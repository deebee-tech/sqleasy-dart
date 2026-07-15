import '../configuration.dart';
import '../enums.dart';
import '../parser/to_sql.dart' as parser;
import '../state.dart';
import 'query_builder.dart';

/// Composes multiple [QueryBuilder] statements into a single SQL string, optionally wrapped in a
/// transaction. Obtain one from a dialect entry point (e.g. `PostgresQuery().newMultiBuilder()`).
class MultiBuilder {
  MultiBuilder(this._config);

  final Dialect _config;
  List<QueryBuilder> _builders = [];
  MultiBuilderTransactionState _transactionState =
      MultiBuilderTransactionState.transactionOn;

  /// Adds a named builder to the batch and returns it for configuration.
  QueryBuilder addBuilder(String builderName) {
    final builder = QueryBuilder(_config);
    builder.state.builderName = builderName;
    _builders.add(builder);
    return builder;
  }

  /// Removes a previously added builder from the batch by name.
  void removeBuilder(String builderName) {
    _builders =
        _builders.where((b) => b.state.builderName != builderName).toList();
  }

  /// Reorders the batch to match the given builder names; names not present are dropped and repeated
  /// names are deduplicated (first occurrence wins) so a statement is never emitted twice.
  void reorderBuilders(List<String> builderNames) {
    final reordered = <QueryBuilder>[];
    for (final name in {...builderNames}) {
      for (final b in _builders) {
        if (b.state.builderName == name) {
          reordered.add(b);
          break;
        }
      }
    }
    _builders = reordered;
  }

  /// Sets whether the batch is wrapped in a transaction.
  void setTransactionState(MultiBuilderTransactionState transactionState) {
    _transactionState = transactionState;
  }

  /// The current transaction state of the batch.
  MultiBuilderTransactionState get transactionState => _transactionState;

  /// The [QueryState] of every builder in the batch, in order.
  List<QueryState> states() => _builders.map((b) => b.state).toList();

  /// Renders the batch as a single prepared SQL string (transaction-wrapped when enabled).
  String parse() => parser.parseMulti(states(), _transactionState, _config);

  /// Renders the batch as a single raw SQL string with values inlined. DEBUG / TEST only.
  String parseRaw() =>
      parser.parseMultiRaw(states(), _transactionState, _config);

  /// The execution-safe form of the batch: each builder rendered as its own prepared
  /// `(sql, params)`, in batch order. This — not [parse] — is what you run: a batch executes
  /// statement by statement, because placeholder numbering restarts per statement (so the single
  /// [parse] string is not a runnable parameterized call) and [parse]/[parseRaw] carry no bound
  /// values. Open a transaction on your own connection, run each in order, and consult
  /// [transactionState] to decide whether to wrap them in BEGIN/COMMIT — the delimiters are NOT
  /// included here.
  List<parser.PreparedSql> preparedStatements() =>
      _builders.map((b) => b.parsePrepared()).toList();
}
