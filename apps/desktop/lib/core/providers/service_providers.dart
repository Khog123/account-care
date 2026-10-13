import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/category_service.dart';
import '../services/customer_service.dart';
import '../services/customer_ledger_service.dart';
import '../services/payment_service.dart';
import '../services/dashboard_service.dart';
import '../services/product_service.dart';
import '../services/sale_service.dart';
import '../services/user_service.dart';
import '../services/inventory_service.dart';
import '../services/reports_service.dart';
import '../services/database_backup_service.dart';
import '../services/excel_export_service.dart';

import 'database_provider.dart';

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  final database = ref.watch(databaseProvider);

  return DashboardService(database);
});

final categoryServiceProvider = Provider<CategoryService>((ref) {
  final database = ref.watch(databaseProvider);

  return CategoryService(database);
});

final productServiceProvider = Provider<ProductService>((ref) {
  final database = ref.watch(databaseProvider);

  return ProductService(database);
});

final customerServiceProvider = Provider<CustomerService>((ref) {
  final database = ref.watch(databaseProvider);

  return CustomerService(database);
});

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  final database = ref.watch(databaseProvider);
  return InventoryService(database);
});

final userServiceProvider = Provider<UserService>((ref) {
  final database = ref.watch(databaseProvider);

  return UserService(database);
});

final saleServiceProvider = Provider<SaleService>((ref) {
  final database = ref.watch(databaseProvider);

  return SaleService(database);
});
final customerLedgerServiceProvider = Provider<CustomerLedgerService>((ref) {
  final database = ref.watch(databaseProvider);

  return CustomerLedgerService(database);
});

final paymentServiceProvider = Provider<PaymentService>((ref) {
  final database = ref.watch(databaseProvider);
  return PaymentService(database);
});

final reportsServiceProvider = Provider<ReportsService>((ref) {
  final database = ref.watch(databaseProvider);
  return ReportsService(database);
});

final databaseBackupServiceProvider = Provider<DatabaseBackupService>((ref) {
  final database = ref.watch(databaseProvider);
  return DatabaseBackupService(database);
});

final excelExportServiceProvider = Provider<ExcelExportService>((ref) {
  return ExcelExportService();
});
