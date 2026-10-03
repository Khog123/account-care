import 'package:flutter_test/flutter_test.dart';

import 'package:desktop/core/database/app_database.dart';
import 'package:desktop/core/services/inventory_service.dart';

void main() {
  late AppDatabase database;
  late InventoryService inventoryService;

  setUp(() {
    database = AppDatabase.test();
    inventoryService = InventoryService(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('adds stock and records inventory movement', () async {
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
            name: 'General',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.products).insert(
          ProductsCompanion.insert(
            id: 'product-1',
            businessId: 'business-1',
            categoryId: 'category-1',
            name: 'Test Product',
            purchasePriceMinor: 500,
            salePriceMinor: 800,
            stockQuantity: 10,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await inventoryService.addStock(
      businessId: 'business-1',
      productId: 'product-1',
      quantity: 5,
      movementType: 'purchase',
      movementAt: now,
    );

    final product = await (database.select(database.products)
          ..where((product) => product.id.equals('product-1')))
        .getSingle();

    expect(product.stockQuantity, 15);

    final movements =
        await (database.select(database.inventoryMovements)
              ..where(
                (movement) =>
                    movement.productId.equals('product-1'),
              ))
            .get();

    expect(movements.length, 1);
    expect(movements.single.quantityChange, 5);
    expect(movements.single.quantityBefore, 10);
    expect(movements.single.quantityAfter, 15);
    expect(movements.single.movementType, 'purchase');
    expect(movements.single.businessId, 'business-1');
  });

  test('removes stock and records inventory movement', () async {
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
            name: 'General',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.products).insert(
          ProductsCompanion.insert(
            id: 'product-1',
            businessId: 'business-1',
            categoryId: 'category-1',
            name: 'Test Product',
            purchasePriceMinor: 500,
            salePriceMinor: 800,
            stockQuantity: 10,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await inventoryService.removeStock(
      businessId: 'business-1',
      productId: 'product-1',
      quantity: 3,
      movementType: 'adjustment',
      movementAt: now,
    );

    final product = await (database.select(database.products)
          ..where((product) => product.id.equals('product-1')))
        .getSingle();

    expect(product.stockQuantity, 7);

    final movements =
        await (database.select(database.inventoryMovements)
              ..where(
                (movement) =>
                    movement.productId.equals('product-1'),
              ))
            .get();

    expect(movements.length, 1);
    expect(movements.single.quantityChange, -3);
    expect(movements.single.quantityBefore, 10);
    expect(movements.single.quantityAfter, 7);
    expect(movements.single.movementType, 'adjustment');
  });

  test('rejects removing more stock than available', () async {
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
            name: 'General',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.products).insert(
          ProductsCompanion.insert(
            id: 'product-1',
            businessId: 'business-1',
            categoryId: 'category-1',
            name: 'Test Product',
            purchasePriceMinor: 500,
            salePriceMinor: 800,
            stockQuantity: 5,
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(
      () => inventoryService.removeStock(
        businessId: 'business-1',
        productId: 'product-1',
        quantity: 6,
        movementType: 'adjustment',
        movementAt: now,
      ),
      throwsA(isA<StateError>()),
    );

    final product = await (database.select(database.products)
          ..where((product) => product.id.equals('product-1')))
        .getSingle();

    expect(product.stockQuantity, 5);

    final movements =
        await (database.select(database.inventoryMovements)
              ..where(
                (movement) =>
                    movement.productId.equals('product-1'),
              ))
            .get();

    expect(movements, isEmpty);
  });

  test('rejects zero or negative stock quantities', () async {
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
            name: 'General',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.products).insert(
          ProductsCompanion.insert(
            id: 'product-1',
            businessId: 'business-1',
            categoryId: 'category-1',
            name: 'Test Product',
            purchasePriceMinor: 500,
            salePriceMinor: 800,
            stockQuantity: 5,
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(
      () => inventoryService.addStock(
        businessId: 'business-1',
        productId: 'product-1',
        quantity: 0,
        movementType: 'purchase',
        movementAt: now,
      ),
      throwsArgumentError,
    );

    expect(
      () => inventoryService.removeStock(
        businessId: 'business-1',
        productId: 'product-1',
        quantity: -1,
        movementType: 'adjustment',
        movementAt: now,
      ),
      throwsArgumentError,
    );
  });

  test('does not modify a product from another business', () async {
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
            name: 'General',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.products).insert(
          ProductsCompanion.insert(
            id: 'product-1',
            businessId: 'business-2',
            categoryId: 'category-1',
            name: 'Other Business Product',
            purchasePriceMinor: 500,
            salePriceMinor: 800,
            stockQuantity: 10,
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(
      () => inventoryService.addStock(
        businessId: 'business-1',
        productId: 'product-1',
        quantity: 5,
        movementType: 'purchase',
        movementAt: now,
      ),
      throwsA(isA<StateError>()),
    );

    final product = await (database.select(database.products)
          ..where((product) => product.id.equals('product-1')))
        .getSingle();

    expect(product.stockQuantity, 10);

    final movements =
        await (database.select(database.inventoryMovements)
              ..where(
                (movement) =>
                    movement.productId.equals('product-1'),
              ))
            .get();

    expect(movements, isEmpty);
  });
}