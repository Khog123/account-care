import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;

import 'package:desktop/core/database/app_database.dart';
import 'package:desktop/core/services/dashboard_service.dart';

void main() {
  late AppDatabase database;
  late DashboardService dashboardService;

  setUp(() {
    database = AppDatabase.test();
    dashboardService = DashboardService(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> insertBusiness({
    String businessId = 'business-1',
  }) async {
    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: businessId,
            name: 'Test Store',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  }

  test('returns zero dashboard values for a new business', () async {
    await insertBusiness();

    final summary = await dashboardService.getSummary(
      businessId: 'business-1',
    );

    expect(summary.todaySalesMinor, 0);
    expect(summary.todayProfitMinor, 0);
    expect(summary.creditDueMinor, 0);
    expect(summary.lowStockProductCount, 0);
  });

  test('returns today sales total for the business', () async {
    await insertBusiness();

    final now = DateTime.now();

    await database.into(database.sales).insert(
          SalesCompanion.insert(
            id: 'sale-1',
            businessId: 'business-1',
            userId: 'user-1',
            invoiceNumber: 'INV-001',
            subtotalMinor: 10000,
            totalMinor: 10000,
            paidMinor: Value(10000),
            dueMinor: Value(0),
            status: 'completed',
            soldAt: now,
            createdAt: now,
          ),
        );

    await database.into(database.sales).insert(
          SalesCompanion.insert(
            id: 'sale-2',
            businessId: 'business-1',
            userId: 'user-1',
            invoiceNumber: 'INV-002',
            subtotalMinor: 5000,
            totalMinor: 5000,
            paidMinor: Value(5000),
            dueMinor: Value(0),
            status: 'completed',
            soldAt: now,
            createdAt: now,
          ),
        );

    final summary = await dashboardService.getSummary(
      businessId: 'business-1',
    );

    expect(summary.todaySalesMinor, 15000);
  });
  
    test('calculates profit after sale-level discount', () async {
    await insertBusiness();

    final now = DateTime.now();

    await database.into(database.sales).insert(
          SalesCompanion.insert(
            id: 'sale-1',
            businessId: 'business-1',
            userId: 'user-1',
            invoiceNumber: 'INV-001',
            subtotalMinor: 10000,
            discountMinor: Value(1000),
            totalMinor: 9000,
            paidMinor: Value(9000),
            dueMinor: Value(0),
            status: 'completed',
            soldAt: now,
            createdAt: now,
          ),
        );

    await database.into(database.saleItems).insert(
          SaleItemsCompanion.insert(
            id: 'sale-item-1',
            saleId: 'sale-1',
            productId: 'product-1',
            productName: 'Test Product',
            quantity: 1,
            unitPriceMinor: 10000,
            purchasePriceMinor: 6000,
            lineTotalMinor: 10000,
          ),
        );

    final summary = await dashboardService.getSummary(
      businessId: 'business-1',
    );

    expect(summary.todaySalesMinor, 9000);
    expect(summary.todayProfitMinor, 3000);
  });
  
  test('does not include sales from another business', () async {
    await insertBusiness(businessId: 'business-1');
    await insertBusiness(businessId: 'business-2');

    final now = DateTime.now();

    await database.into(database.sales).insert(
          SalesCompanion.insert(
            id: 'sale-1',
            businessId: 'business-1',
            userId: 'user-1',
            invoiceNumber: 'INV-001',
            subtotalMinor: 10000,
            totalMinor: 10000,
            paidMinor: Value(10000),
            dueMinor: Value(0),
            status: 'completed',
            soldAt: now,
            createdAt: now,
          ),
        );

    await database.into(database.sales).insert(
          SalesCompanion.insert(
            id: 'sale-2',
            businessId: 'business-2',
            userId: 'user-2',
            invoiceNumber: 'INV-002',
            subtotalMinor: 20000,
            totalMinor: 20000,
            paidMinor: Value(20000),
            dueMinor: Value(0),
            status: 'completed',
            soldAt: now,
            createdAt: now,
          ),
        );

    final summary = await dashboardService.getSummary(
      businessId: 'business-1',
    );

    expect(summary.todaySalesMinor, 10000);
  });

  test('calculates credit due from customers', () async {
    await insertBusiness();

    final now = DateTime.now();

    await database.into(database.customers).insert(
          CustomersCompanion.insert(
            id: 'customer-1',
            businessId: 'business-1',
            name: 'Ali Khan',
            openingBalanceMinor: Value(5000),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.customers).insert(
          CustomersCompanion.insert(
            id: 'customer-2',
            businessId: 'business-1',
            name: 'Ahmed Khan',
            openingBalanceMinor: Value(3000),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final summary = await dashboardService.getSummary(
      businessId: 'business-1',
    );

    expect(summary.creditDueMinor, 8000);
  });

  test('counts products at or below low stock threshold', () async {
    await insertBusiness();

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

    await database.into(database.products).insert(
          ProductsCompanion.insert(
            id: 'product-1',
            businessId: 'business-1',
            categoryId: 'category-1',
            name: 'Low Stock Product',
            purchasePriceMinor: 5000,
            salePriceMinor: 7000,
            stockQuantity: 2,
            lowStockThreshold: Value(5),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.products).insert(
          ProductsCompanion.insert(
            id: 'product-2',
            businessId: 'business-1',
            categoryId: 'category-1',
            name: 'Normal Stock Product',
            purchasePriceMinor: 5000,
            salePriceMinor: 7000,
            stockQuantity: 10,
            lowStockThreshold: Value(5),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final summary = await dashboardService.getSummary(
      businessId: 'business-1',
    );

    expect(summary.lowStockProductCount, 1);
  });

  test('does not count inactive products as low stock', () async {
    await insertBusiness();

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

    await database.into(database.products).insert(
          ProductsCompanion.insert(
            id: 'product-1',
            businessId: 'business-1',
            categoryId: 'category-1',
            name: 'Inactive Product',
            purchasePriceMinor: 5000,
            salePriceMinor: 7000,
            stockQuantity: 0,
            lowStockThreshold: Value(5),
            isActive: Value(false),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final summary = await dashboardService.getSummary(
      businessId: 'business-1',
    );

    expect(summary.lowStockProductCount, 0);
  });

  test('rejects an unknown business', () async {
    expect(
      () => dashboardService.getSummary(
        businessId: 'business-999',
      ),
      throwsStateError,
    );
  });
}