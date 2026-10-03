import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/businesses.dart';
import 'tables/users.dart';
import 'tables/categories.dart';
import 'tables/products.dart';
import 'tables/customers.dart';
import 'tables/sales.dart';
import 'tables/sale_items.dart';
import 'tables/payments.dart';
import 'tables/ledger_entries.dart';
import 'tables/inventory_movements.dart';
import 'tables/expenses.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Businesses,
    Users,
    Categories,
    Products,
    Customers,
    Sales,
    SaleItems,
    Payments,
    LedgerEntries,
    InventoryMovements,
    Expenses,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.test() : super(NativeDatabase.memory());
  
  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();

    final databaseDirectory = Directory(
      p.join(directory.path, 'account_care'),
    );

    if (!databaseDirectory.existsSync()) {
      databaseDirectory.createSync(recursive: true);
    }

    final file = File(
      p.join(databaseDirectory.path, 'account_care.sqlite'),
    );

    return NativeDatabase.createInBackground(file);
  });
}