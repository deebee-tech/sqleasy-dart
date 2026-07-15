/// The four dialect entry points — the public way to obtain a builder.
library;

import 'builder/multi_builder.dart';
import 'builder/query_builder.dart';
import 'configuration.dart';

/// Main entry point for Microsoft SQL Server: bracket identifiers, `?` placeholders, `dbo` schema,
/// and a self-contained `sp_executesql` for prepared statements.
class MssqlQuery {
  MssqlQuery([RuntimeConfiguration? rc])
      : _configuration = mssqlConfiguration(rc);

  final Dialect _configuration;

  Dialect get configuration => _configuration;

  QueryBuilder newBuilder([RuntimeConfiguration? rc]) =>
      QueryBuilder(rc != null ? mssqlConfiguration(rc) : _configuration);

  MultiBuilder newMultiBuilder([RuntimeConfiguration? rc]) =>
      MultiBuilder(rc != null ? mssqlConfiguration(rc) : _configuration);
}

/// Main entry point for MySQL: backtick identifiers, `?` placeholders, no default schema.
class MysqlQuery {
  MysqlQuery([RuntimeConfiguration? rc])
      : _configuration = mysqlConfiguration(rc);

  final Dialect _configuration;

  Dialect get configuration => _configuration;

  QueryBuilder newBuilder([RuntimeConfiguration? rc]) =>
      QueryBuilder(rc != null ? mysqlConfiguration(rc) : _configuration);

  MultiBuilder newMultiBuilder([RuntimeConfiguration? rc]) =>
      MultiBuilder(rc != null ? mysqlConfiguration(rc) : _configuration);
}

/// Main entry point for PostgreSQL: double-quoted identifiers, `$n` placeholders, `public` schema.
class PostgresQuery {
  PostgresQuery([RuntimeConfiguration? rc])
      : _configuration = postgresConfiguration(rc);

  final Dialect _configuration;

  Dialect get configuration => _configuration;

  QueryBuilder newBuilder([RuntimeConfiguration? rc]) =>
      QueryBuilder(rc != null ? postgresConfiguration(rc) : _configuration);

  MultiBuilder newMultiBuilder([RuntimeConfiguration? rc]) =>
      MultiBuilder(rc != null ? postgresConfiguration(rc) : _configuration);
}

/// Main entry point for SQLite: double-quoted identifiers, `?` placeholders, no default schema.
class SqliteQuery {
  SqliteQuery([RuntimeConfiguration? rc])
      : _configuration = sqliteConfiguration(rc);

  final Dialect _configuration;

  Dialect get configuration => _configuration;

  QueryBuilder newBuilder([RuntimeConfiguration? rc]) =>
      QueryBuilder(rc != null ? sqliteConfiguration(rc) : _configuration);

  MultiBuilder newMultiBuilder([RuntimeConfiguration? rc]) =>
      MultiBuilder(rc != null ? sqliteConfiguration(rc) : _configuration);
}
