import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/category_service.dart';
import '../services/customer_service.dart';
import '../services/dashboard_service.dart';
import '../services/product_service.dart';
import '../services/sale_services.dart';
import '../services/user_service.dart';
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

final userServiceProvider = Provider<UserService>((ref) {
  final database = ref.watch(databaseProvider);

  return UserService(database);
});

final saleServiceProvider = Provider<SaleService>((ref) {
  final database = ref.watch(databaseProvider);

  return SaleService(database);
});