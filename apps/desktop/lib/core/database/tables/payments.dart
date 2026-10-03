import 'package:drift/drift.dart';

class Payments extends Table {
  TextColumn get id => text()();

  TextColumn get businessId => text()();

  TextColumn get customerId =>
      text().nullable()();

  TextColumn get saleId =>
      text().nullable()();

  TextColumn get userId => text()();

  IntColumn get amountMinor => integer()();

  TextColumn get paymentMethod =>
      text().withLength(min: 1, max: 50)();

  TextColumn get reference =>
      text().withLength(max: 200).nullable()();

  DateTimeColumn get paidAt => dateTime()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}