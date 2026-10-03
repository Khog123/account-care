import 'package:drift/drift.dart';

class Products extends Table {
  TextColumn get id => text()();

  TextColumn get businessId => text()();

  TextColumn get categoryId => text()();

  TextColumn get name => text().withLength(min: 1, max: 200)();

  TextColumn get sku =>
      text().withLength(min: 1, max: 100).nullable()();

  IntColumn get purchasePriceMinor =>
      integer()();

  IntColumn get salePriceMinor =>
      integer()();

  IntColumn get stockQuantity =>
      integer()();

  IntColumn get lowStockThreshold =>
      integer().withDefault(const Constant(0))();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}