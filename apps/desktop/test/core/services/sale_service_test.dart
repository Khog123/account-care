import 'package:flutter_test/flutter_test.dart';

import 'package:desktop/core/database/app_database.dart';
import 'package:desktop/core/services/sale_services.dart';

void main() {
  late AppDatabase database;
  late SaleService saleService;

  setUp(() {
    database = AppDatabase.test();
    saleService = SaleService(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('completes a cash sale and reduces stock', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
          UsersCompanion.insert(
            id: 'user-1',
            businessId: 'business-1',
            name: 'Test User',
            username: 'test-user',
            passwordHash: 'test-hash',
            role: 'master_merchant',
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
            salePriceMinor: 1000,
            stockQuantity: 10,
            createdAt: now,
            updatedAt: now,
          ),
        );

    final saleId = await saleService.completeSale(
      businessId: 'business-1',
      userId: 'user-1',
      saleId: 'sale-1',
      invoiceNumber: 'INV-001',
      items: const [
        SaleItemRequest(
          productId: 'product-1',
          quantity: 2,
        ),
      ],
      paidMinor: 2000,
      status: 'completed',
      soldAt: now,
    );

    expect(saleId, 'sale-1');

    final sale = await (database.select(database.sales)
          ..where((sale) => sale.id.equals('sale-1')))
        .getSingle();

    expect(sale.subtotalMinor, 2000);
    expect(sale.discountMinor, 0);
    expect(sale.totalMinor, 2000);
    expect(sale.paidMinor, 2000);
    expect(sale.dueMinor, 0);

    final payments = await (database.select(database.payments)
      ..where((payment) => payment.saleId.equals('sale-1')))
    .get();

expect(payments.length, 1);
expect(payments.single.amountMinor, 2000);
expect(payments.single.paymentMethod, 'cash');
expect(payments.single.businessId, 'business-1');
expect(payments.single.saleId, 'sale-1');

final ledgerEntries = await (database.select(database.ledgerEntries)
      ..where((entry) => entry.saleId.equals('sale-1')))
    .get();

expect(ledgerEntries, isEmpty);

    final saleItems = await (database.select(database.saleItems)
          ..where((item) => item.saleId.equals('sale-1')))
        .get();

    expect(saleItems.length, 1);
    expect(saleItems.single.quantity, 2);
    expect(saleItems.single.lineTotalMinor, 2000);

    final product = await (database.select(database.products)
          ..where((product) => product.id.equals('product-1')))
        .getSingle();

    expect(product.stockQuantity, 8);

    final movements =
        await (database.select(database.inventoryMovements)
              ..where(
                (movement) => movement.saleId.equals('sale-1'),
              ))
            .get();

    expect(movements.length, 1);
    expect(movements.single.quantityChange, -2);
    expect(movements.single.quantityBefore, 10);
    expect(movements.single.quantityAfter, 8);
  });

  test('rolls back the sale when an item causes insufficient stock',
      () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
          UsersCompanion.insert(
            id: 'user-1',
            businessId: 'business-1',
            name: 'Test User',
            username: 'test-user',
            passwordHash: 'test-hash',
            role: 'master_merchant',
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
            name: 'Low Stock Product',
            purchasePriceMinor: 500,
            salePriceMinor: 1000,
            stockQuantity: 2,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await expectLater(
      saleService.completeSale(
        businessId: 'business-1',
        userId: 'user-1',
        saleId: 'sale-2',
        invoiceNumber: 'INV-002',
        items: const [
          SaleItemRequest(
            productId: 'product-1',
            quantity: 5,
          ),
        ],
        paidMinor: 5000,
        status: 'completed',
        soldAt: now,
      ),
      throwsA(isA<StateError>()),
    );

    final sales = await database.select(database.sales).get();
    expect(sales, isEmpty);

    final saleItems = await database.select(database.saleItems).get();
    expect(saleItems, isEmpty);

    final movements =
        await database.select(database.inventoryMovements).get();
    expect(movements, isEmpty);

    final product = await (database.select(database.products)
          ..where((product) => product.id.equals('product-1')))
        .getSingle();

    expect(product.stockQuantity, 2);
  });
  test('creates payment and customer debt for a credit sale', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
          UsersCompanion.insert(
            id: 'user-1',
            businessId: 'business-1',
            name: 'Test User',
            username: 'test-user',
            passwordHash: 'test-hash',
            role: 'master_merchant',
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

    await database.into(database.customers).insert(
          CustomersCompanion.insert(
            id: 'customer-1',
            businessId: 'business-1',
            name: 'Test Customer',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.products).insert(
          ProductsCompanion.insert(
            id: 'product-1',
            businessId: 'business-1',
            categoryId: 'category-1',
            name: 'Credit Product',
            purchasePriceMinor: 500,
            salePriceMinor: 1000,
            stockQuantity: 10,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await saleService.completeSale(
      businessId: 'business-1',
      userId: 'user-1',
      saleId: 'sale-credit-1',
      invoiceNumber: 'INV-003',
      customerId: 'customer-1',
      items: const [
        SaleItemRequest(
          productId: 'product-1',
          quantity: 2,
        ),
      ],
      paidMinor: 500,
      status: 'completed',
      soldAt: now,
    );

    final sale = await (database.select(database.sales)
          ..where((sale) => sale.id.equals('sale-credit-1')))
        .getSingle();

    expect(sale.totalMinor, 2000);
    expect(sale.paidMinor, 500);
    expect(sale.dueMinor, 1500);
    expect(sale.customerId, 'customer-1');

    final payments = await (database.select(database.payments)
          ..where((payment) => payment.saleId.equals('sale-credit-1')))
        .get();

    expect(payments.length, 1);
    expect(payments.single.amountMinor, 500);
    expect(payments.single.paymentMethod, 'cash');
    expect(payments.single.customerId, 'customer-1');

    final ledgerEntries =
        await (database.select(database.ledgerEntries)
              ..where(
                (entry) => entry.saleId.equals('sale-credit-1'),
              ))
            .get();

    expect(ledgerEntries.length, 1);
    expect(ledgerEntries.single.customerId, 'customer-1');
    expect(ledgerEntries.single.amountMinor, 1500);
    expect(ledgerEntries.single.entryType, 'sale_credit');
  });

    test('applies sale-level discount to the final total', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
          UsersCompanion.insert(
            id: 'user-1',
            businessId: 'business-1',
            name: 'Test User',
            username: 'test-user',
            passwordHash: 'test-hash',
            role: 'master_merchant',
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
            name: 'Discount Product',
            purchasePriceMinor: 6000,
            salePriceMinor: 10000,
            stockQuantity: 10,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await saleService.completeSale(
      businessId: 'business-1',
      userId: 'user-1',
      saleId: 'sale-discount-1',
      invoiceNumber: 'INV-004',
      items: const [
        SaleItemRequest(
          productId: 'product-1',
          quantity: 1,
        ),
      ],
      discountMinor: 1000,
      paidMinor: 9000,
      status: 'completed',
      soldAt: now,
    );

    final sale = await (database.select(database.sales)
          ..where(
            (sale) => sale.id.equals('sale-discount-1'),
          ))
        .getSingle();

    expect(sale.subtotalMinor, 10000);
    expect(sale.discountMinor, 1000);
    expect(sale.totalMinor, 9000);
    expect(sale.paidMinor, 9000);
    expect(sale.dueMinor, 0);

    final saleItems = await (database.select(database.saleItems)
          ..where(
            (item) => item.saleId.equals('sale-discount-1'),
          ))
        .get();

    expect(saleItems.length, 1);
    expect(saleItems.single.lineTotalMinor, 10000);
  });
    test('creates customer debt for a fully unpaid sale', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
          UsersCompanion.insert(
            id: 'user-1',
            businessId: 'business-1',
            name: 'Test User',
            username: 'test-user',
            passwordHash: 'test-hash',
            role: 'master_merchant',
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

    await database.into(database.customers).insert(
          CustomersCompanion.insert(
            id: 'customer-1',
            businessId: 'business-1',
            name: 'Test Customer',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.products).insert(
          ProductsCompanion.insert(
            id: 'product-1',
            businessId: 'business-1',
            categoryId: 'category-1',
            name: 'Credit Product',
            purchasePriceMinor: 500,
            salePriceMinor: 1000,
            stockQuantity: 10,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await saleService.completeSale(
      businessId: 'business-1',
      userId: 'user-1',
      saleId: 'sale-unpaid-1',
      invoiceNumber: 'INV-005',
      customerId: 'customer-1',
      items: const [
        SaleItemRequest(
          productId: 'product-1',
          quantity: 2,
        ),
      ],
      paidMinor: 0,
      status: 'completed',
      soldAt: now,
    );

    final sale = await (database.select(database.sales)
          ..where(
            (sale) => sale.id.equals('sale-unpaid-1'),
          ))
        .getSingle();

    expect(sale.totalMinor, 2000);
    expect(sale.paidMinor, 0);
    expect(sale.dueMinor, 2000);

    final payments = await (database.select(database.payments)
          ..where(
            (payment) => payment.saleId.equals('sale-unpaid-1'),
          ))
        .get();

    expect(payments, isEmpty);

    final ledgerEntries =
        await (database.select(database.ledgerEntries)
              ..where(
                (entry) => entry.saleId.equals('sale-unpaid-1'),
              ))
            .get();

    expect(ledgerEntries.length, 1);
    expect(ledgerEntries.single.customerId, 'customer-1');
    expect(ledgerEntries.single.amountMinor, 2000);
    expect(ledgerEntries.single.entryType, 'sale_credit');
  });
}