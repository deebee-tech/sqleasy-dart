/// The phase or region of the parser an error came from.
///
/// The name is interpolated into the message, so its `name` must match the TypeScript enum's string
/// value exactly — the golden corpus records error messages as text.
enum ParserArea {
  select('Select'),
  from('From'),
  join('Join'),
  where('Where'),
  having('Having'),
  orderBy('OrderBy'),
  limitOffset('LimitOffset'),
  insert('Insert'),
  update('Update'),
  delete('Delete'),
  call('Call'),
  general('General');

  const ParserArea(this.value);

  /// The wire name, matching the TypeScript `ParserArea` string values.
  final String value;
}

/// Thrown when SQL generation fails.
///
/// The message format — `"<Area>: <message>"` — is part of the cross-language contract: the golden
/// corpus matches error text as a substring, so this must render exactly as the TypeScript
/// `ParserError` does.
class ParserError implements Exception {
  ParserError(this.area, this.message);

  final ParserArea area;
  final String message;

  @override
  String toString() => '${area.value}: $message';
}
