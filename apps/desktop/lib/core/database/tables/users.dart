import 'package:drift/drift.dart';

class Users extends Table {
  TextColumn get id => text()();

  TextColumn get businessId => text()();

  TextColumn get name => text().withLength(min: 1, max: 200)();

  TextColumn get username =>
      text().withLength(min: 1, max: 100)();

  TextColumn get passwordHash =>
      text().withLength(min: 1, max: 500)();

  TextColumn get role =>
      text().withLength(min: 1, max: 50)();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}