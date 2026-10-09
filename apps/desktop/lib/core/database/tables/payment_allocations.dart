import 'package:drift/drift.dart';

class PaymentAllocations extends Table {
  TextColumn get id => text()();

  TextColumn get businessId => text()();

  TextColumn get paymentId => text()();

  TextColumn get saleId => text()();

  IntColumn get amountMinor => integer()();

  DateTimeColumn get allocatedAt => dateTime()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
