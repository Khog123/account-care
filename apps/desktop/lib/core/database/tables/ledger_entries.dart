import 'package:drift/drift.dart';

class LedgerEntries extends Table {
  TextColumn get id => text()();

  TextColumn get businessId => text()();

  TextColumn get customerId => text()();

  TextColumn get saleId =>
      text().nullable()();

  TextColumn get paymentId =>
      text().nullable()();

  TextColumn get entryType =>
      text().withLength(min: 1, max: 50)();

  IntColumn get amountMinor => integer()();

  TextColumn get description =>
      text().withLength(max: 500).nullable()();

  DateTimeColumn get entryAt => dateTime()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}