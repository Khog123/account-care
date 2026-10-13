import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../database/app_database.dart';

class DatabaseBackupService {
  DatabaseBackupService(this._database);

  final AppDatabase _database;

  Future<String> createBackup(String destinationPath) async {
    final destination = File(destinationPath);

    if (await destination.exists()) {
      throw StateError(
        'A file already exists at the selected backup location. '
        'Choose a different filename.',
      );
    }

    try {
      // SQLite creates a consistent snapshot of the live database.
      await _database.customStatement('VACUUM INTO ?;', [destinationPath]);

      if (!await destination.exists() || await destination.length() == 0) {
        throw StateError('The backup file was not created correctly.');
      }

      // Verify the actual backup file in read-only mode.
      final verificationDb = sqlite.sqlite3.open(
        destinationPath,
        mode: sqlite.OpenMode.readOnly,
      );

      try {
        final integrityResult = verificationDb.select(
          'PRAGMA integrity_check;',
        );

        final integrityStatus = integrityResult.isEmpty
            ? null
            : integrityResult.first['integrity_check'];

        if (integrityStatus != 'ok') {
          throw StateError(
            'Backup integrity verification failed: $integrityStatus',
          );
        }

        final versionResult = verificationDb.select('PRAGMA user_version;');
        final version = versionResult.first['user_version'] as int;

        if (version != 3) {
          throw StateError(
            'The backup schema version is $version; expected version 3.',
          );
        }

        // Ensure the backup contains the expected core tables.

        final requiredTables = <String>{
          'businesses',
          'users',
          'categories',
          'products',
          'customers',
          'sales',
          'sale_items',
          'payments',
          'payment_allocations',
          'ledger_entries',
          'inventory_movements',
          'expenses',
        };

        final tableRows = verificationDb.select(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'table';",
        );

        final actualTables = tableRows
            .map((row) => row['name'] as String)
            .toSet();

        final missingTables = requiredTables.difference(actualTables);

        if (missingTables.isNotEmpty) {
          throw StateError(
            'Backup is missing required tables: '
            '${missingTables.join(', ')}',
          );
        }
      } finally {
        verificationDb.close();
      }

      return destinationPath;
    } catch (_) {
      // Never leave a partial or invalid backup behind.
      if (await destination.exists()) {
        await destination.delete();
      }
      rethrow;
    }
  }
}
