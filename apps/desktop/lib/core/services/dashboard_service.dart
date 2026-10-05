import 'package:drift/drift.dart';

import '../database/app_database.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.todaySalesMinor,
    required this.todayProfitMinor,
    required this.creditDueMinor,
    required this.lowStockProductCount,
  });

  final int todaySalesMinor;
  final int todayProfitMinor;
  final int creditDueMinor;
  final int lowStockProductCount;
}

class DashboardService {
  DashboardService(this._database);

  final AppDatabase _database;

  Future<DashboardSummary> getSummary({
    required String businessId,
  }) async {
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

    final now = DateTime.now();

    final startOfDay = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final startOfTomorrow = startOfDay.add(
      const Duration(days: 1),
    );

    final sales = await (_database.select(_database.sales)
          ..where(
            (sale) =>
                sale.businessId.equals(businessId) &
                sale.soldAt.isBiggerOrEqualValue(startOfDay) &
                sale.soldAt.isSmallerThanValue(startOfTomorrow) &
                sale.status.equals('completed'),
          ))
        .get();

    final todaySalesMinor = sales.fold<int>(
      0,
      (sum, sale) => sum + sale.totalMinor,
    );

    var todayProfitMinor = 0;

    for (final sale in sales) {
      final items = await (_database.select(_database.saleItems)
            ..where(
              (item) => item.saleId.equals(sale.id),
            ))
          .get();

      for (final item in items) {
        final itemProfit =
            (item.unitPriceMinor - item.purchasePriceMinor) *
                item.quantity -
            item.discountMinor;

        todayProfitMinor += itemProfit;
      }
    }

    final customers = await (_database.select(_database.customers)
          ..where(
            (customer) =>
                customer.businessId.equals(businessId) &
                customer.isActive.equals(true),
          ))
        .get();

    var creditDueMinor = 0;

    for (final customer in customers) {
      final saleCredits = await (_database.select(_database.ledgerEntries)
            ..where(
              (entry) =>
                  entry.businessId.equals(businessId) &
                  entry.customerId.equals(customer.id) &
                  entry.entryType.equals('sale_credit'),
            ))
          .get();

      final payments = await (_database.select(_database.ledgerEntries)
            ..where(
              (entry) =>
                  entry.businessId.equals(businessId) &
                  entry.customerId.equals(customer.id) &
                  entry.entryType.equals('payment'),
            ))
          .get();

      var balance = customer.openingBalanceMinor;

      for (final entry in saleCredits) {
        balance += entry.amountMinor;
      }

      for (final entry in payments) {
        balance -= entry.amountMinor;
      }

      if (balance > 0) {
        creditDueMinor += balance;
      }
    }

    final lowStockProducts = await (_database.select(_database.products)
          ..where(
            (product) =>
                product.businessId.equals(businessId) &
                product.isActive.equals(true) &
                product.stockQuantity.isSmallerOrEqual(
                  product.lowStockThreshold,
                ),
          ))
        .get();

    return DashboardSummary(
      todaySalesMinor: todaySalesMinor,
      todayProfitMinor: todayProfitMinor,
      creditDueMinor: creditDueMinor,
      lowStockProductCount: lowStockProducts.length,
    );
  }
}