import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'business_provider.dart';
import 'service_providers.dart';

final productListProvider = FutureProvider<List<Product>>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);

  if (businessId == null || businessId.isEmpty) {
    throw StateError('No active business selected.');
  }

  final productService = ref.watch(productServiceProvider);

  return productService.getProducts(
    businessId: businessId,
    activeOnly: true,
  );
});

final activeCategoryListProvider =
    FutureProvider<List<Category>>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);

  if (businessId == null || businessId.isEmpty) {
    throw StateError('No active business selected.');
  }

  final categoryService = ref.watch(categoryServiceProvider);

  return categoryService.getCategories(
    businessId: businessId,
    activeOnly: true,
  );
});
