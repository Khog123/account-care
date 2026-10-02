import 'package:drift/drift.dart';

class Businesses extends Table {
  TextColumn get id => text()();

  TextColumn get name => text().withLength(min: 1, max: 200)();

  TextColumn get currencyCode =>
      text().withLength(min: 3, max: 3).withDefault(const Constant('PKR'))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}