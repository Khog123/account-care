import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;

import 'package:desktop/core/database/app_database.dart';
import 'package:desktop/core/services/reports_service.dart';

void main() {
  late AppDatabase database;
  late ReportsService service;

  setUp(() {
    database = AppDatabase.test();
    service = ReportsService(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> createBusiness({
    required String id,
    String name = 'Test Business',
  }) async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: id,
            name: name,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> createUser({
    required String id,
    required String businessId,
  }) async {
    final now = DateTime.now();

    await database.into(database.users).insert(
          UsersCompanion.insert(
            id: id,
            businessId: businessId,
            name: 'Test User',
            username: id,
            passwordHash: 'hash',
            role: 'admin',
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> createSale({
    required String id,
    required String businessId,
    required String userId,
    required String invoiceNumber,
    required int subtotalMinor,
    required int totalMinor,
    required int paidMinor,
    required int dueMinor,
    required DateTime soldAt,
    String status = 'completed',
  }) async {
    await database.into(database.sales).insert(
          SalesCompanion.insert(
            id: id,
            businessId: businessId,
            userId: userId,
            invoiceNumber: invoiceNumber,
            subtotalMinor: subtotalMinor,
            totalMinor: totalMinor,
            paidMinor: Value(paidMinor),
            dueMinor: Value(dueMinor),
            status: status,
            soldAt: soldAt,
            createdAt: soldAt,
          ),
        );
  }

  test('returns zero values when there are no sales', () async {
    await createBusiness(id: 'business-1');

    final result = await service.getSalesReport(
      businessId: 'business-1',
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31, 23, 59, 59),
    );

    expect(result.saleCount, 0);
    expect(result.totalSalesMinor, 0);
    expect(result.totalPaidMinor, 0);
    expect(result.totalCreditMinor, 0);
    expect(result.totalProfitMinor, 0);
  });

  test('calculates sales totals for the requested date range', () async {
    await createBusiness(id: 'business-1');

    await createUser(
      id: 'user-1',
      businessId: 'business-1',
    );

    final saleDate = DateTime(2026, 10, 10, 12);
    final now = DateTime.now();

    await database.into(database.categories).insert(
      CategoriesCompanion.insert(
        id: 'category-1',
        businessId: 'business-1',
        name: 'General',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await createSale(
      id: 'sale-1',
      businessId: 'business-1',
      userId: 'user-1',
      invoiceNumber: 'INV-001',
      subtotalMinor: 10000,
      totalMinor: 9500,
      paidMinor: 9500,
      dueMinor: 0,
      soldAt: saleDate,
    );

    await createSale(
      id: 'sale-2',
      businessId: 'business-1',
      userId: 'user-1',
      invoiceNumber: 'INV-002',
      subtotalMinor: 20000,
      totalMinor: 18000,
      paidMinor: 10000,
      dueMinor: 8000,
      soldAt: saleDate,
    );

    final result = await service.getSalesReport(
      businessId: 'business-1',
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31, 23, 59, 59),
    );

    expect(result.saleCount, 2);
    expect(result.totalSalesMinor, 27500);
    expect(result.totalPaidMinor, 19500);
    expect(result.totalCreditMinor, 8000);
  });

  test('excludes sales outside the requested date range', () async {
    await createBusiness(id: 'business-1');

    await createUser(
      id: 'user-1',
      businessId: 'business-1',
    );

    await createSale(
      id: 'sale-before',
      businessId: 'business-1',
      userId: 'user-1',
      invoiceNumber: 'INV-000',
      subtotalMinor: 5000,
      totalMinor: 5000,
      paidMinor: 5000,
      dueMinor: 0,
      soldAt: DateTime(2026, 9, 30, 23),
    );

    await createSale(
      id: 'sale-inside',
      businessId: 'business-1',
      userId: 'user-1',
      invoiceNumber: 'INV-001',
      subtotalMinor: 10000,
      totalMinor: 10000,
      paidMinor: 10000,
      dueMinor: 0,
      soldAt: DateTime(2026, 10, 10, 12),
    );

    await createSale(
      id: 'sale-after',
      businessId: 'business-1',
      userId: 'user-1',
      invoiceNumber: 'INV-002',
      subtotalMinor: 20000,
      totalMinor: 20000,
      paidMinor: 20000,
      dueMinor: 0,
      soldAt: DateTime(2026, 11, 1),
    );

    final result = await service.getSalesReport(
      businessId: 'business-1',
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31, 23, 59, 59),
    );

    expect(result.saleCount, 1);
    expect(result.totalSalesMinor, 10000);
  });

  test('excludes sales from another business', () async {
    await createBusiness(id: 'business-1');
    await createBusiness(id: 'business-2');

    await createUser(
      id: 'user-1',
      businessId: 'business-1',
    );

    await createUser(
      id: 'user-2',
      businessId: 'business-2',
    );

    final saleDate = DateTime(2026, 10, 10, 12);

    await createSale(
      id: 'sale-1',
      businessId: 'business-1',
      userId: 'user-1',
      invoiceNumber: 'INV-001',
      subtotalMinor: 10000,
      totalMinor: 10000,
      paidMinor: 10000,
      dueMinor: 0,
      soldAt: saleDate,
    );

    await createSale(
      id: 'sale-2',
      businessId: 'business-2',
      userId: 'user-2',
      invoiceNumber: 'INV-002',
      subtotalMinor: 50000,
      totalMinor: 50000,
      paidMinor: 50000,
      dueMinor: 0,
      soldAt: saleDate,
    );

    final result = await service.getSalesReport(
      businessId: 'business-1',
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31, 23, 59, 59),
    );

    expect(result.saleCount, 1);
    expect(result.totalSalesMinor, 10000);
  });

  test('excludes cancelled sales', () async {
    await createBusiness(id: 'business-1');

    await createUser(
      id: 'user-1',
      businessId: 'business-1',
    );
      
    final saleDate = DateTime(2026, 10, 10, 12);

    await createSale(
      id: 'sale-completed',
      businessId: 'business-1',
      userId: 'user-1',
      invoiceNumber: 'INV-001',
      subtotalMinor: 10000,
      totalMinor: 10000,
      paidMinor: 10000,
      dueMinor: 0,
      soldAt: saleDate,
      status: 'cancelled',
    );

    final result = await service.getSalesReport(
      businessId: 'business-1',
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31, 23, 59, 59),
    );

    expect(result.saleCount, 0);
    expect(result.totalSalesMinor, 0);
  });

    test('returns top-selling products for the requested date range', () async {
    await createBusiness(id: 'business-1');

    await createUser(
      id: 'user-1',
      businessId: 'business-1',
    );

    final now = DateTime(2026, 10, 10, 12);

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
            name: 'Product A',
            purchasePriceMinor: 500,
            salePriceMinor: 1000,
            stockQuantity: 20,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.products).insert(
          ProductsCompanion.insert(
            id: 'product-2',
            businessId: 'business-1',
            categoryId: 'category-1',
            name: 'Product B',
            purchasePriceMinor: 700,
            salePriceMinor: 1500,
            stockQuantity: 20,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await createSale(
      id: 'sale-1',
      businessId: 'business-1',
      userId: 'user-1',
      invoiceNumber: 'INV-001',
      subtotalMinor: 5000,
      totalMinor: 5000,
      paidMinor: 5000,
      dueMinor: 0,
      soldAt: now,
    );

    await database.into(database.saleItems).insert(
          SaleItemsCompanion.insert(
            id: 'item-1',
            saleId: 'sale-1',
            productId: 'product-1',
            productName: 'Product A',
            quantity: 5,
            unitPriceMinor: 1000,
            purchasePriceMinor: Value(500),
            lineTotalMinor: 5000,
          ),
        );

    await createSale(
      id: 'sale-2',
      businessId: 'business-1',
      userId: 'user-1',
      invoiceNumber: 'INV-002',
      subtotalMinor: 4500,
      totalMinor: 4500,
      paidMinor: 4500,
      dueMinor: 0,
      soldAt: now,
    );

    await database.into(database.saleItems).insert(
          SaleItemsCompanion.insert(
            id: 'item-2',
            saleId: 'sale-2',
            productId: 'product-2',
            productName: 'Product B',
            quantity: 3,
            unitPriceMinor: 1500,
            purchasePriceMinor: Value(700),
            lineTotalMinor: 4500,
          ),
        );

    final result = await service.getTopSellingProducts(
      businessId: 'business-1',
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31, 23, 59, 59),
    );

    expect(result.length, 2);

    expect(result[0].productId, 'product-1');
    expect(result[0].productName, 'Product A');
    expect(result[0].quantitySold, 5);
    expect(result[0].salesMinor, 5000);

    expect(result[1].productId, 'product-2');
    expect(result[1].productName, 'Product B');
    expect(result[1].quantitySold, 3);
    expect(result[1].salesMinor, 4500);
  });

  test('rejects an unknown business', () async {
    expect(
      () => service.getSalesReport(
        businessId: 'missing-business',
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31, 23, 59, 59),
      ),
      throwsA(isA<StateError>()),
    );
  });
}