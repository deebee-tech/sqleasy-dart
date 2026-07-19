import '../enums.dart';
import '../state.dart';

/// Fluent builder for a window function's `OVER (...)` clause.
class WindowBuilder {
  final WindowState _state = WindowState();

  WindowBuilder partitionByColumn(String tableNameOrAlias, String columnName) {
    _state.partitionByStates.add(WindowPartitionByState()
      ..tableNameOrAlias = tableNameOrAlias
      ..columnName = columnName);
    return this;
  }

  WindowBuilder partitionByColumns(
      List<({String tableNameOrAlias, String columnName})> columns) {
    for (final column in columns) {
      partitionByColumn(column.tableNameOrAlias, column.columnName);
    }
    return this;
  }

  WindowBuilder partitionByRaw(String raw) {
    _state.partitionByStates.add(WindowPartitionByState()..raw = raw);
    return this;
  }

  WindowBuilder orderByColumn(
    String tableNameOrAlias,
    String columnName, [
    OrderByDirection direction = OrderByDirection.none,
    NullsOrder nulls = NullsOrder.none,
  ]) {
    _state.orderByStates.add(WindowOrderByState()
      ..tableNameOrAlias = tableNameOrAlias
      ..columnName = columnName
      ..direction = direction
      ..nulls = nulls);
    return this;
  }

  WindowBuilder orderByRaw(String raw) {
    _state.orderByStates.add(WindowOrderByState()..raw = raw);
    return this;
  }

  /// Sets a structured `ROWS`/`RANGE BETWEEN start AND end` frame. Omit [endType] for the
  /// SQL-standard single-bound shorthand (implicitly `AND CURRENT ROW`).
  WindowBuilder frame(
    FrameUnit unit,
    FrameBoundType startType, [
    int? startOffset,
    FrameBoundType? endType,
    int? endOffset,
  ]) {
    _state.frame = WindowFrameState()
      ..unit = unit
      ..start = (WindowFrameBoundState()
        ..type = startType
        ..offset = startOffset)
      ..end = endType == null
          ? null
          : (WindowFrameBoundState()
            ..type = endType
            ..offset = endOffset);
    return this;
  }

  /// Raw-SQL form of [frame] for expressions the structured bounds can't express.
  WindowBuilder frameRaw(String raw) {
    _state.frame = WindowFrameState()
      ..unit = FrameUnit.rows
      ..start = (WindowFrameBoundState()..type = FrameBoundType.currentRow)
      ..raw = raw;
    return this;
  }

  WindowState state() => _state;
}
