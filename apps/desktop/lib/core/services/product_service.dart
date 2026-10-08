import 'package:drift/drift.dart';

import '../database/app_database.dart';

class ProductService {
  ProductService(this._database);

  final AppDatabase _database;

  Future<String> createProduct({
    required String businessId,
    required String productId,
    required String categoryId,
    required String name,
    required int purchasePriceMinor,
    required int salePriceMinor,
    int lowStockThreshold = 0,
    String? sku,
  }) async {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError(
        'Product name cannot be empty.',
      );
    }

    if (purchasePriceMinor < 0) {
      throw ArgumentError(
        'Purchase price cannot be negative.',
      );
    }

    if (salePriceMinor < 0) {
      throw ArgumentError(
        'Sale price cannot be negative.',
      );
    }

    if (lowStockThreshold < 0) {
      throw ArgumentError(
        'Low stock threshold cannot be negative.',
      );
    }

    final business = await (_database.select(_database.businesses)
          ..where(
            (business) => business.id.equals(businessId),
          ))
        .getSingleOrNull();

    if (business == null) {
      throw StateError(
        'Business not found: $businessId',
      );
    }

    final category = await (_database.select(_database.categories)
          ..where(
            (category) =>
                category.id.equals(categoryId) &
                category.businessId.equals(businessId),
          ))
        .getSingleOrNull();

    if (category == null) {
      throw StateError(
        'Category not found for this business: $categoryId',
      );
    }

    final now = DateTime.now();

    await _database.into(_database.products).insert(
          ProductsCompanion.insert(
            id: productId,
            businessId: businessId,
            categoryId: categoryId,
            name: trimmedName,
            sku: Value(sku),
            purchasePriceMinor: purchasePriceMinor,
            salePriceMinor: salePriceMinor,
            stockQuantity: 0,
            lowStockThreshold: Value(lowStockThreshold),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return productId;
  }

  Future<List<Product>> getProducts({
    required String businessId,
    bool activeOnly = false,
  }) {
    final query = _database.select(_database.products)
      ..where(
        (product) => product.businessId.equals(businessId),
      );

    if (activeOnly) {
      query.where(
        (product) => product.isActive.equals(true),
      );
    }

    query.orderBy([
      (product) => OrderingTerm(
            expression: product.name,
            mode: OrderingMode.asc,
          ),
    ]);

    return query.get();
  }

  Future<Product?> getProductById({
    required String businessId,
    required String productId,
  }) {
    return (_database.select(_database.products)
          ..where(
            (product) =>
                product.id.equals(productId) &
                product.businessId.equals(businessId),
          ))
        .getSingleOrNull();
  }

  Future<void> updateProduct({
    required String businessId,
    required String productId,
    required String categoryId,
    required String name,
    required int purchasePriceMinor,
    required int salePriceMinor,
    required int lowStockThreshold,
    String? sku,
    required bool isActive,
  }) async {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError(
        'Product name cannot be empty.',
      );
    }

    if (purchasePriceMinor < 0) {
      throw ArgumentError(
        'Purchase price cannot be negative.',
      );
    }

    if (salePriceMinor < 0) {
      throw ArgumentError(
        'Sale price cannot be negative.',
      );
    }

    if (lowStockThreshold < 0) {
      throw ArgumentError(
        'Low stock threshold cannot be negative.',
      );
    }

    final product = await (_database.select(_database.products)
          ..where(
            (product) =>
                product.id.equals(productId) &
                product.businessId.equals(businessId),
          ))
        .getSingleOrNull();

    if (product == null) {
      throw StateError(
        'Product not found for this business: $productId',
      );
    }

    final category = await (_database.select(_database.categories)
          ..where(
            (category) =>
                category.id.equals(categoryId) &
                category.businessId.equals(businessId),
          ))
        .getSingleOrNull();

    if (category == null) {
      throw StateError(
        'Category not found for this business: $categoryId',
      );
    }

    await (_database.update(_database.products)
          ..where(
            (product) =>
                product.id.equals(productId) &
                product.businessId.equals(businessId),
          ))
        .write(
      ProductsCompanion(
        categoryId: Value(categoryId),
        name: Value(trimmedName),
        sku: Value(sku),
        purchasePriceMinor: Value(purchasePriceMinor),
        salePriceMinor: Value(salePriceMinor),
        lowStockThreshold: Value(lowStockThreshold),
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deactivateProduct({
    required String businessId,
    required String productId,
  }) async {
    final product = await (_database.select(_database.products)
          ..where(
            (product) =>
                product.id.equals(productId) &
                product.businessId.equals(businessId),
          ))
        .getSingleOrNull();

    if (product == null) {
      throw StateError(
        'Product not found for this business: $productId',
      );
    }

    if (!product.isActive) {
      return;
    }

    await (_database.update(_database.products)
          ..where(
            (product) =>
                product.id.equals(productId) &
                product.businessId.equals(businessId),
          ))
        .write(
      ProductsCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> restoreProduct({
    required String businessId,
    required String productId,
  }) async {
    final product = await (_database.select(_database.products)
          ..where(
            (product) =>
                product.id.equals(productId) &
                product.businessId.equals(businessId),
          ))
        .getSingleOrNull();

    if (product == null) {
      throw StateError(
        'Product not found for this business: $productId',
      );
    }

    if (product.isActive) {
      return;
    }

    await (_database.update(_database.products)
          ..where(
            (product) =>
                product.id.equals(productId) &
                product.businessId.equals(businessId),
          ))
        .write(
      ProductsCompanion(
        isActive: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}