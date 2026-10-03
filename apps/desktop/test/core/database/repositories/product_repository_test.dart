import 'package:flutter_test/flutter_test.dart';
import 'package:desktop/core/database/app_database.dart';
import 'package:desktop/core/database/repositories/product_repository.dart';

void main() {
  late AppDatabase database;
  late ProductRepository repository;

  setUp(() {
    database = AppDatabase.test();
    repository = ProductRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates and retrieves a product', () async {
    await repository.create(
      id: 'product-1',
      businessId: 'business-1',
      categoryId: 'category-1',
      name: 'Milk',
      sku: 'MILK-001',
      purchasePriceMinor: 15000,
      salePriceMinor: 18000,
      stockQuantity: 20,
      lowStockThreshold: 5,
    );

    final product = await repository.getById('product-1');

    expect(product, isNotNull);
    expect(product!.id, 'product-1');
    expect(product.businessId, 'business-1');
    expect(product.categoryId, 'category-1');
    expect(product.name, 'Milk');
    expect(product.sku, 'MILK-001');
    expect(product.purchasePriceMinor, 15000);
    expect(product.salePriceMinor, 18000);
    expect(product.stockQuantity, 20);
    expect(product.lowStockThreshold, 5);
    expect(product.isActive, isTrue);
  });

  test('retrieves only products belonging to the requested business',
      () async {
    await repository.create(
      id: 'product-1',
      businessId: 'business-1',
      categoryId: 'category-1',
      name: 'Milk',
      purchasePriceMinor: 15000,
      salePriceMinor: 18000,
    );

    await repository.create(
      id: 'product-2',
      businessId: 'business-2',
      categoryId: 'category-2',
      name: 'Bread',
      purchasePriceMinor: 8000,
      salePriceMinor: 10000,
    );

    final products =
        await repository.getByBusinessId('business-1');

    expect(products, hasLength(1));
    expect(products.first.id, 'product-1');
    expect(products.first.businessId, 'business-1');
  });

  test('returns only active products', () async {
    await repository.create(
      id: 'product-1',
      businessId: 'business-1',
      categoryId: 'category-1',
      name: 'Milk',
      purchasePriceMinor: 15000,
      salePriceMinor: 18000,
    );

    await repository.create(
      id: 'product-2',
      businessId: 'business-1',
      categoryId: 'category-1',
      name: 'Old Product',
      purchasePriceMinor: 10000,
      salePriceMinor: 12000,
    );

    await repository.update(
      productId: 'product-2',
      categoryId: 'category-1',
      name: 'Old Product',
      purchasePriceMinor: 10000,
      salePriceMinor: 12000,
      lowStockThreshold: 0,
      isActive: false,
    );

    final products =
        await repository.getActiveByBusinessId('business-1');

    expect(products, hasLength(1));
    expect(products.first.id, 'product-1');
  });

  test('returns null when product does not exist', () async {
    final product = await repository.getById('missing-product');

    expect(product, isNull);
  });

  test('updates product details without changing stock', () async {
    await repository.create(
      id: 'product-3',
      businessId: 'business-1',
      categoryId: 'category-1',
      name: 'Original Product',
      sku: 'OLD-SKU',
      purchasePriceMinor: 10000,
      salePriceMinor: 12000,
      stockQuantity: 50,
      lowStockThreshold: 5,
    );

    await repository.update(
      productId: 'product-3',
      categoryId: 'category-2',
      name: 'Updated Product',
      sku: 'NEW-SKU',
      purchasePriceMinor: 11000,
      salePriceMinor: 14000,
      lowStockThreshold: 10,
      isActive: true,
    );

    final product = await repository.getById('product-3');

    expect(product, isNotNull);
    expect(product!.name, 'Updated Product');
    expect(product.categoryId, 'category-2');
    expect(product.sku, 'NEW-SKU');
    expect(product.purchasePriceMinor, 11000);
    expect(product.salePriceMinor, 14000);
    expect(product.lowStockThreshold, 10);

    // Stock must remain unchanged.
    expect(product.stockQuantity, 50);
  });
}