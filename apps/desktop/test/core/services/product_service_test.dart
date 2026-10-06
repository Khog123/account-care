import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;

import 'package:desktop/core/database/app_database.dart';
import 'package:desktop/core/services/product_service.dart';

void main() {
  late AppDatabase database;
  late ProductService productService;

  setUp(() {
    database = AppDatabase.test();
    productService = ProductService(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates a product for a business category', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            id: 'category-1',
            businessId: 'business-1',
            name: 'Beverages',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final productId = await productService.createProduct(
      businessId: 'business-1',
      productId: 'product-1',
      categoryId: 'category-1',
      name: 'Cola',
      sku: 'COLA-001',
      purchasePriceMinor: 5000,
      salePriceMinor: 8000,
      stockQuantity: 20,
      lowStockThreshold: 5,
    );

    expect(productId, 'product-1');

    final product = await (database.select(database.products)
          ..where((product) => product.id.equals('product-1')))
        .getSingle();

    expect(product.businessId, 'business-1');
    expect(product.categoryId, 'category-1');
    expect(product.name, 'Cola');
    expect(product.sku, 'COLA-001');
    expect(product.purchasePriceMinor, 5000);
    expect(product.salePriceMinor, 8000);
    expect(product.stockQuantity, 20);
    expect(product.lowStockThreshold, 5);
    expect(product.isActive, isTrue);
  });

  test('rejects an empty product name', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            id: 'category-1',
            businessId: 'business-1',
            name: 'Beverages',
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(
      () => productService.createProduct(
        businessId: 'business-1',
        productId: 'product-1',
        categoryId: 'category-1',
        name: '   ',
        purchasePriceMinor: 5000,
        salePriceMinor: 8000,
      ),
      throwsArgumentError,
    );

    final products = await database.select(database.products).get();

    expect(products, isEmpty);
  });

  test('rejects negative prices or stock values', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            id: 'category-1',
            businessId: 'business-1',
            name: 'Beverages',
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(
      () => productService.createProduct(
        businessId: 'business-1',
        productId: 'product-1',
        categoryId: 'category-1',
        name: 'Cola',
        purchasePriceMinor: -1,
        salePriceMinor: 8000,
      ),
      throwsArgumentError,
    );

    expect(
      () => productService.createProduct(
        businessId: 'business-1',
        productId: 'product-2',
        categoryId: 'category-1',
        name: 'Juice',
        purchasePriceMinor: 5000,
        salePriceMinor: 8000,
        stockQuantity: -1,
      ),
      throwsArgumentError,
    );

    final products = await database.select(database.products).get();

    expect(products, isEmpty);
  });

  test('rejects a category belonging to another business', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Business One',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-2',
            name: 'Business Two',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            id: 'category-1',
            businessId: 'business-2',
            name: 'Other Category',
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(
      () => productService.createProduct(
        businessId: 'business-1',
        productId: 'product-1',
        categoryId: 'category-1',
        name: 'Cola',
        purchasePriceMinor: 5000,
        salePriceMinor: 8000,
      ),
      throwsA(isA<StateError>()),
    );

    final products = await database.select(database.products).get();

    expect(products, isEmpty);
  });

  test('gets a product only within the requested business', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Business One',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-2',
            name: 'Business Two',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            id: 'category-2',
            businessId: 'business-2',
            name: 'Other Category',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.products).insert(
      ProductsCompanion.insert(
        id: 'product-1',
        businessId: 'business-2',
        categoryId: 'category-2',
        name: 'Other Product',
        purchasePriceMinor: 5000,
        salePriceMinor: 8000,
        stockQuantity: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final product = await productService.getProductById(
      businessId: 'business-1',
      productId: 'product-1',
    );

    expect(product, isNull);
  });

  test('updates product information', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            id: 'category-1',
            businessId: 'business-1',
            name: 'Beverages',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.products).insert(
          ProductsCompanion.insert(
            id: 'product-1',
            businessId: 'business-1',
            categoryId: 'category-1',
            name: 'Old Product',
            purchasePriceMinor: 5000,
            salePriceMinor: 8000,
            stockQuantity: 10,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await productService.updateProduct(
      businessId: 'business-1',
      productId: 'product-1',
      categoryId: 'category-1',
      name: 'Updated Product',
      purchasePriceMinor: 6000,
      salePriceMinor: 9000,
      stockQuantity: 10,
      lowStockThreshold: 5,
      sku: 'SKU-UPDATED',
      isActive: true,
    );

    final product = await (database.select(database.products)
          ..where((product) => product.id.equals('product-1')))
        .getSingle();

    expect(product.name, 'Updated Product');
    expect(product.sku, 'SKU-UPDATED');
    expect(product.purchasePriceMinor, 6000);
    expect(product.salePriceMinor, 9000);
    expect(product.stockQuantity, 10);
    expect(product.lowStockThreshold, 5);
    expect(product.isActive, isTrue);
  });

  test('does not update a product from another business', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Business One',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-2',
            name: 'Business Two',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            id: 'category-2',
            businessId: 'business-2',
            name: 'Other Category',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.products).insert(
          ProductsCompanion.insert(
            id: 'product-1',
            businessId: 'business-2',
            categoryId: 'category-2',
            name: 'Original Product',
            purchasePriceMinor: 5000,
            salePriceMinor: 8000,
            stockQuantity: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(
      () => productService.updateProduct(
        businessId: 'business-1',
        productId: 'product-1',
        categoryId: 'category-2',
        name: 'Changed Product',
        purchasePriceMinor: 6000,
        salePriceMinor: 9000,
        stockQuantity: 10,
        lowStockThreshold: 0,
        sku: 'CHANGED',
        isActive: true,
      ),
      throwsA(isA<StateError>()),
    );

    final product = await (database.select(database.products)
          ..where((product) => product.id.equals('product-1')))
        .getSingle();

    expect(product.name, 'Original Product');
  });

  test('deactivates a product without deleting it', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            id: 'category-1',
            businessId: 'business-1',
            name: 'Beverages',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.products).insert(
          ProductsCompanion.insert(
            id: 'product-1',
            businessId: 'business-1',
            categoryId: 'category-1',
            name: 'Cola',
            purchasePriceMinor: 5000,
            salePriceMinor: 8000,
            stockQuantity: 10,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await productService.deactivateProduct(
      businessId: 'business-1',
      productId: 'product-1',
    );

    final product = await (database.select(database.products)
          ..where((product) => product.id.equals('product-1')))
        .getSingle();

    expect(product.isActive, isFalse);
    expect(product.stockQuantity, 10);
    expect(product.name, 'Cola');
  });

  test('restores a deactivated product', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            id: 'category-1',
            businessId: 'business-1',
            name: 'Beverages',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.products).insert(
          ProductsCompanion.insert(
            id: 'product-1',
            businessId: 'business-1',
            categoryId: 'category-1',
            name: 'Cola',
            purchasePriceMinor: 5000,
            salePriceMinor: 8000,
            stockQuantity: 10,
            isActive: const Value(false),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await productService.restoreProduct(
      businessId: 'business-1',
      productId: 'product-1',
    );

    final product = await (database.select(database.products)
          ..where((product) => product.id.equals('product-1')))
        .getSingle();

    expect(product.isActive, isTrue);
    expect(product.stockQuantity, 10);
    expect(product.name, 'Cola');
  });

  test('does not deactivate a product from another business', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Business One',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-2',
            name: 'Business Two',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            id: 'category-2',
            businessId: 'business-2',
            name: 'Other Category',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.products).insert(
          ProductsCompanion.insert(
            id: 'product-1',
            businessId: 'business-2',
            categoryId: 'category-2',
            name: 'Other Product',
            purchasePriceMinor: 5000,
            salePriceMinor: 8000,
            stockQuantity: 10,
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(
      () => productService.deactivateProduct(
        businessId: 'business-1',
        productId: 'product-1',
      ),
      throwsA(isA<StateError>()),
    );

    final product = await (database.select(database.products)
          ..where((product) => product.id.equals('product-1')))
        .getSingle();

    expect(product.isActive, isTrue);
  });
}
