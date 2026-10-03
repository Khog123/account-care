import 'package:drift/drift.dart';

class Customers extends Table {
  TextColumn get id => text()();

  TextColumn get businessId => text()();

  TextColumn get name => text().withLength(min: 1, max: 200)();

  TextColumn get phone =>
      text().withLength(min: 1, max: 50).nullable()();

  TextColumn get address =>
      text().withLength(max: 500).nullable()();

  IntColumn get openingBalanceMinor =>
      integer().withDefault(const Constant(0))();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}