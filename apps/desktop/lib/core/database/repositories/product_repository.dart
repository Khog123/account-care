import 'package:drift/drift.dart';

import '../app_database.dart';

class ProductRepository {
  ProductRepository(this._database);

  final AppDatabase _database;

  Future<List<Product>> getByBusinessId(String businessId) {
    return (_database.select(_database.products)
          ..where((product) => product.businessId.equals(businessId)))
        .get();
  }

  Future<Product?> getById(String productId) {
    return (_database.select(_database.products)
          ..where((product) => product.id.equals(productId)))
        .getSingleOrNull();
  }

  Future<List<Product>> getActiveByBusinessId(String businessId) {
    return (_database.select(_database.products)
          ..where(
            (product) =>
                product.businessId.equals(businessId) &
                product.isActive.equals(true),
          ))
        .get();
  }

  Future<void> create({
    required String id,
    required String businessId,
    required String categoryId,
    required String name,
    String? sku,
    required int purchasePriceMinor,
    required int salePriceMinor,
    int stockQuantity = 0,
    int lowStockThreshold = 0,
  }) async {
    final now = DateTime.now();

    await _database.into(_database.products).insert(
          ProductsCompanion.insert(
            id: id,
            businessId: businessId,
            categoryId: categoryId,
            name: name,
            sku: Value(sku),
            purchasePriceMinor: purchasePriceMinor,
            salePriceMinor: salePriceMinor,
            stockQuantity: stockQuantity,
            lowStockThreshold: Value(lowStockThreshold),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> update({
    required String productId,
    required String categoryId,
    required String name,
    String? sku,
    required int purchasePriceMinor,
    required int salePriceMinor,
    required int lowStockThreshold,
    required bool isActive,
  }) async {
    await (_database.update(_database.products)
          ..where((product) => product.id.equals(productId)))
        .write(
      ProductsCompanion(
        categoryId: Value(categoryId),
        name: Value(name),
        sku: Value(sku),
        purchasePriceMinor: Value(purchasePriceMinor),
        salePriceMinor: Value(salePriceMinor),
        lowStockThreshold: Value(lowStockThreshold),
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}