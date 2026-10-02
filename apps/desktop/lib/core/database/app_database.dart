import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/businesses.dart';
import 'tables/users.dart';
import 'tables/categories.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Businesses,
    Users,
    Categories,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.test() : super(NativeDatabase.memory());
  
  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();

    final databaseDirectory = Directory(
      p.join(directory.path, 'account_care'),
    );

    if (!databaseDirectory.existsSync()) {
      databaseDirectory.createSync(recursive: true);
    }

    final file = File(
      p.join(databaseDirectory.path, 'account_care.sqlite'),
    );

    return NativeDatabase.createInBackground(file);
  });
}