import 'package:flutter_test/flutter_test.dart';
import 'package:desktop/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test();
  });

  tearDown(() async {
    await database.close();
  });

  test('database opens and businesses table is queryable', () async {
    final businesses = await database.select(database.businesses).get();

    expect(businesses, isEmpty);
  });

  test('users table is queryable', () async {
  final users = await database.select(database.users).get();

  expect(users, isEmpty);
});
}