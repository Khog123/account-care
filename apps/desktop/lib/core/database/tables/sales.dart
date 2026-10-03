import 'package:drift/drift.dart';

class Sales extends Table {
  TextColumn get id => text()();

  TextColumn get businessId => text()();

  TextColumn get customerId =>
      text().nullable()();

  TextColumn get userId => text()();

  TextColumn get invoiceNumber =>
      text().withLength(min: 1, max: 100)();

  IntColumn get subtotalMinor => integer()();

  IntColumn get discountMinor =>
      integer().withDefault(const Constant(0))();

  IntColumn get totalMinor => integer()();

  IntColumn get paidMinor =>
      integer().withDefault(const Constant(0))();

  IntColumn get dueMinor =>
      integer().withDefault(const Constant(0))();

  TextColumn get status =>
      text().withLength(min: 1, max: 50)();

  DateTimeColumn get soldAt => dateTime()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}