import 'dart:io';

import 'package:desktop/core/database/app_database.dart';
import 'package:desktop/core/services/database_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late AppDatabase database;
  late Directory temporaryDirectory;
  late DatabaseBackupService backupService;

  setUp(() async {
    database = AppDatabase.test();
    backupService = DatabaseBackupService(database);

    temporaryDirectory = await Directory.systemTemp.createTemp(
      'account_care_backup_test_',
    );

    // Force Drift to initialize the in-memory database and its schema.
    await database.select(database.businesses).get();
  });

  tearDown(() async {
    await database.close();

    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('creates a valid database backup', () async {
    final backupPath =
        '${temporaryDirectory.path}${Platform.pathSeparator}backup.sqlite';

    final result = await backupService.createBackup(backupPath);

    expect(result, backupPath);
    expect(await File(backupPath).exists(), isTrue);
    expect(await File(backupPath).length(), greaterThan(0));

    final verificationDb = sqlite.sqlite3.open(
      backupPath,
      mode: sqlite.OpenMode.readOnly,
    );

    try {
      final integrityResult = verificationDb.select('PRAGMA integrity_check;');

      expect(integrityResult.first['integrity_check'], 'ok');

      final versionResult = verificationDb.select('PRAGMA user_version;');

      expect(versionResult.first['user_version'], 3);

      final tables = verificationDb
          .select("SELECT name FROM sqlite_master WHERE type = 'table';")
          .map((row) => row['name'] as String)
          .toSet();

      expect(
        tables,
        containsAll({
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
        }),
      );
    } finally {
      verificationDb.close();
    }
  });

  test('refuses to overwrite an existing file', () async {
    final existingFile = File(
      '${temporaryDirectory.path}'
      '${Platform.pathSeparator}existing.sqlite',
    );

    await existingFile.writeAsString('keep this existing content');

    await expectLater(
      backupService.createBackup(existingFile.path),
      throwsA(isA<StateError>()),
    );

    expect(await existingFile.readAsString(), 'keep this existing content');
  });
}
