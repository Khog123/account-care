import 'package:drift/drift.dart';

class Categories extends Table {
  TextColumn get id => text()();

  TextColumn get businessId => text()();

  TextColumn get name => text().withLength(min: 1, max: 100)();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}