import 'package:drift/drift.dart';

class Expenses extends Table {
  TextColumn get id => text()();

  TextColumn get businessId => text()();

  TextColumn get userId => text()();

  TextColumn get category =>
      text().withLength(min: 1, max: 100)();

  IntColumn get amountMinor => integer()();

  TextColumn get description =>
      text().withLength(max: 500).nullable()();

  DateTimeColumn get expenseAt => dateTime()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}