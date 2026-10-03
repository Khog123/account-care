import 'package:drift/drift.dart';

class InventoryMovements extends Table {
  TextColumn get id => text()();

  TextColumn get businessId => text()();

  TextColumn get productId => text()();

  TextColumn get saleId =>
      text().nullable()();

  IntColumn get quantityChange => integer()();

  IntColumn get quantityBefore => integer()();

  IntColumn get quantityAfter => integer()();

  TextColumn get movementType =>
      text().withLength(min: 1, max: 50)();

  TextColumn get reference =>
      text().withLength(max: 200).nullable()();

  TextColumn get notes =>
      text().withLength(max: 500).nullable()();

  DateTimeColumn get movementAt => dateTime()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}