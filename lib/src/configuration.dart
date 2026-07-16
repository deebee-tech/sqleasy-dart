/// Dialect configuration — the data that drives dialect-correct SQL generation.
library;

import 'enums.dart';

/// A pair of delimiters for quoting identifiers or framing transaction blocks.
class ConfigurationDelimiters {
  const ConfigurationDelimiters(this.begin, this.end);

  /// Opening delimiter (e.g. `[`, `` ` ``, or `"`).
  final String begin;

  /// Closing delimiter matching [begin].
  final String end;
}

/// Options passed when creating a query or builder.
class RuntimeConfiguration {
  /// Optional host-defined settings carried alongside runtime options.
  Object? customConfiguration;
}

/// Dialect-specific configuration that controls how SQL is generated.
///
/// A plain data object — the whole strategy for a dialect. Each dialect ships a factory (e.g.
/// [sqliteConfiguration]) that produces one, and the single builder/parser reads it to decide
/// identifier quoting, placeholder style, default schema, and transaction syntax.
class Dialect {
  Dialect({
    required this.databaseType,
    required this.defaultOwner,
    required this.identifierDelimiters,
    required this.preparedStatementPlaceholder,
    required this.runtimeConfiguration,
    required this.transactionDelimiters,
  });

  /// The [DatabaseType] identifying this dialect.
  final DatabaseType databaseType;

  /// The default schema/owner name (e.g. `dbo` for MSSQL, `public` for Postgres).
  final String defaultOwner;

  /// The delimiters used to quote identifiers.
  final ConfigurationDelimiters identifierDelimiters;

  /// The placeholder character used in prepared statements (e.g. `?` or `$`).
  final String preparedStatementPlaceholder;

  /// The runtime options bound to this dialect instance.
  final RuntimeConfiguration runtimeConfiguration;

  /// The delimiters that wrap transaction blocks (e.g. `BEGIN`/`COMMIT`).
  final ConfigurationDelimiters transactionDelimiters;
}

/// The Microsoft SQL Server dialect: bracket identifiers, `?` placeholders, `dbo` schema.
Dialect mssqlConfiguration([RuntimeConfiguration? rc]) => Dialect(
      databaseType: DatabaseType.mssql,
      defaultOwner: 'dbo',
      identifierDelimiters: const ConfigurationDelimiters('[', ']'),
      preparedStatementPlaceholder: '?',
      runtimeConfiguration: rc ?? RuntimeConfiguration(),
      transactionDelimiters: const ConfigurationDelimiters(
          'BEGIN TRANSACTION', 'COMMIT TRANSACTION'),
    );

/// The MySQL dialect: backtick identifiers, `?` placeholders, no default schema.
Dialect mysqlConfiguration([RuntimeConfiguration? rc]) => Dialect(
      databaseType: DatabaseType.mysql,
      defaultOwner: '',
      identifierDelimiters: const ConfigurationDelimiters('`', '`'),
      preparedStatementPlaceholder: '?',
      runtimeConfiguration: rc ?? RuntimeConfiguration(),
      transactionDelimiters:
          const ConfigurationDelimiters('START TRANSACTION', 'COMMIT'),
    );

/// The PostgreSQL dialect: double-quoted identifiers, `$` placeholders, `public` schema.
Dialect postgresConfiguration([RuntimeConfiguration? rc]) => Dialect(
      databaseType: DatabaseType.postgres,
      defaultOwner: 'public',
      identifierDelimiters: const ConfigurationDelimiters('"', '"'),
      preparedStatementPlaceholder: r'$',
      runtimeConfiguration: rc ?? RuntimeConfiguration(),
      transactionDelimiters: const ConfigurationDelimiters('BEGIN', 'COMMIT'),
    );

/// The SQLite dialect: double-quoted identifiers, `?` placeholders, no default schema.
Dialect sqliteConfiguration([RuntimeConfiguration? rc]) => Dialect(
      databaseType: DatabaseType.sqlite,
      defaultOwner: '',
      identifierDelimiters: const ConfigurationDelimiters('"', '"'),
      preparedStatementPlaceholder: '?',
      runtimeConfiguration: rc ?? RuntimeConfiguration(),
      transactionDelimiters: const ConfigurationDelimiters('BEGIN', 'COMMIT'),
    );
