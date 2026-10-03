import 'package:drift/drift.dart';

class SaleItems extends Table {
  TextColumn get id => text()();

  TextColumn get saleId => text()();

  TextColumn get productId => text()();

  TextColumn get productName =>
      text().withLength(min: 1, max: 200)();

  IntColumn get quantity => integer()();

  IntColumn get unitPriceMinor => integer()();

  IntColumn get discountMinor =>
      integer().withDefault(const Constant(0))();

  IntColumn get lineTotalMinor => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}