import '../errors/parser_error.dart';
import '../state.dart';

/// Resolves the table targeted by UPDATE or DELETE.
///
/// Prefers the `updateTable` / `deleteFrom` entry tracked by [QueryState.mutationTargetIndex].
/// Falls back to the sole `fromStates` entry when no mutation index is set. Refuses ambiguous
/// stacks (multiple FROM sources without a recorded mutation target).
FromState resolveMutationTarget(
  QueryState state,
  ParserArea area,
  String missingMessage,
) {
  if (state.fromStates.isEmpty) {
    throw ParserError(area, missingMessage);
  }

  final index = state.mutationTargetIndex;
  if (index != null) {
    if (index < 0 || index >= state.fromStates.length) {
      throw ParserError(area, missingMessage);
    }
    return state.fromStates[index];
  }

  if (state.fromStates.length > 1) {
    throw ParserError(
      area,
      'Ambiguous UPDATE/DELETE target: call updateTable/deleteFrom after fromTable, or clearFrom first',
    );
  }

  return state.fromStates[0];
}
