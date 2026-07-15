import '../configuration.dart';
import '../enums.dart';
import '../state.dart';

/// Builds the `ON` conditions of a JOIN.
///
/// Obtained inside a [QueryBuilder.joinTable] callback; you do not construct it directly.
class JoinOnBuilder {
  JoinOnBuilder(this._config);

  final Dialect _config;
  final List<JoinOnState> _states = [];

  JoinOnBuilder _child() => JoinOnBuilder(_config);

  /// A column-to-column condition: `leftAlias.leftColumn <op> rightAlias.rightColumn`.
  JoinOnBuilder on(
    String leftAlias,
    String leftColumn,
    JoinOperator operator,
    String rightAlias,
    String rightColumn,
  ) {
    _states.add(JoinOnState()
      ..joinOperator = operator
      ..joinOnOperator = JoinOnOperator.on
      ..aliasLeft = leftAlias
      ..columnLeft = leftColumn
      ..aliasRight = rightAlias
      ..columnRight = rightColumn);
    return this;
  }

  /// A column-to-value condition: `alias.column <op> ?`. The value is bound, never interpolated.
  JoinOnBuilder onValue(
    String alias,
    String column,
    JoinOperator operator,
    Object? value,
  ) {
    _states.add(JoinOnState()
      ..joinOperator = operator
      ..joinOnOperator = JoinOnOperator.value
      ..aliasLeft = alias
      ..columnLeft = column
      ..valueRight = value);
    return this;
  }

  /// A raw ON fragment, emitted verbatim.
  JoinOnBuilder onRaw(String raw) {
    _states.add(JoinOnState()
      ..joinOnOperator = JoinOnOperator.raw
      ..raw = raw);
    return this;
  }

  /// A parenthesized group of conditions.
  JoinOnBuilder onGroup(void Function(JoinOnBuilder builder) builder) {
    _states.add(JoinOnState()..joinOnOperator = JoinOnOperator.groupBegin);

    final child = _child();
    builder(child);

    // Splice the group's own conditions between the delimiters. Without this the child builder is
    // populated and thrown away — the group renders as `()` and any onValue inside is never bound.
    _states.addAll(child.states());

    _states.add(JoinOnState()..joinOnOperator = JoinOnOperator.groupEnd);
    return this;
  }

  JoinOnBuilder and() {
    _states.add(JoinOnState()
      ..joinOperator = JoinOperator.none
      ..joinOnOperator = JoinOnOperator.and);
    return this;
  }

  JoinOnBuilder or() {
    _states.add(JoinOnState()
      ..joinOperator = JoinOperator.none
      ..joinOnOperator = JoinOnOperator.or);
    return this;
  }

  /// The accumulated ON conditions. Consumed by the parent builder.
  List<JoinOnState> states() => _states;
}
