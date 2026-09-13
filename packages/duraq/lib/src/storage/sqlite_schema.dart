import 'package:sqlite3/sqlite3.dart';

import '../errors.dart';

/// Brings a SQLite database up to a known schema version.
///
/// Before this, tables were created if absent and never versioned, so a new
/// column or a new status value had no safe way of reaching a database already
/// in the field, and a database written by a newer release was opened as if
/// nothing had changed.
///
/// The version lives in SQLite's own `user_version` pragma, which costs nothing
/// and needs no table of its own.
class SqliteSchema {
  /// The version [createCurrent] produces, and the version this release reads.
  final int targetVersion;

  /// How a database at version `key - 1` becomes one at version `key`.
  ///
  /// Every version between the oldest one still supported and [targetVersion]
  /// needs an entry; a gap is a programming error and is reported as one.
  final Map<int, void Function(Database db)> migrations;

  /// Creates the current schema. Must be safe to run against a database that
  /// already has it, because an unversioned database is brought here first.
  final void Function(Database db) createCurrent;

  /// Whether this database was written before versioning existed, as opposed to
  /// being empty. Usually a check for one of the tables.
  final bool Function(Database db) looksUnversioned;

  /// The version an unversioned database is taken to be at.
  final int unversionedIs;

  const SqliteSchema({
    required this.targetVersion,
    required this.createCurrent,
    required this.looksUnversioned,
    this.migrations = const {},
    this.unversionedIs = 1,
  });

  /// The schema version recorded in [db]. Zero when none has been recorded.
  static int versionOf(Database db) =>
      db.select('PRAGMA user_version').first.values.first as int? ?? 0;

  /// Records [version] in [db].
  static void setVersionOf(Database db, int version) {
    // PRAGMA takes no parameters, hence the interpolation. Callers pass an int
    // from their own source, never a value from outside the package.
    db.execute('PRAGMA user_version = $version');
  }

  /// Creates or upgrades [db] so that it is at [targetVersion].
  ///
  /// [label] names the database in any error, since a process may hold several.
  void applyTo(Database db, {String? label}) {
    final found = versionOf(db);

    if (found > targetVersion) {
      throw SchemaVersionException(
        found,
        targetVersion,
        detail: label == null ? null : 'Database: $label.',
      );
    }

    var version = found;

    if (version == 0) {
      // Either a new database or one written before versioning. Tables already
      // present mean the latter, and such a database is at [unversionedIs] by
      // definition: it is the shape every release up to that point wrote.
      // A new database is created at the current shape directly and needs no
      // migrations at all.
      final existing = looksUnversioned(db);
      createCurrent(db);
      version = existing ? unversionedIs : targetVersion;
      setVersionOf(db, version);
    }

    while (version < targetVersion) {
      final next = version + 1;
      final migration = migrations[next];
      if (migration == null) {
        throw DuraQException(
          'No migration from schema version $version to $next. This is a bug '
          'in DuraQ: the target version was raised without a step to match.',
        );
      }

      // One transaction per step, so a failure leaves the database at the last
      // version that applied in full rather than somewhere between two.
      db.execute('BEGIN IMMEDIATE');
      try {
        migration(db);
        setVersionOf(db, next);
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
      version = next;
    }
  }
}
