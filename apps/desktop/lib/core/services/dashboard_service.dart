import 'package:drift/drift.dart';

import '../database/app_database.dart';

class DashboardDailyPoint {
  const DashboardDailyPoint({
    required this.date,
    required this.salesMinor,
    required this.creditMinor,
  });

  final DateTime date;
  final int salesMinor;
  final int creditMinor;
}

class DashboardRecentSale {
  const DashboardRecentSale({
    required this.invoiceNumber,
    required this.customerName,
    required this.soldAt,
    required this.totalMinor,
    required this.paidMinor,
    required this.dueMinor,
  });

  final String invoiceNumber;
  final String customerName;
  final DateTime soldAt;
  final int totalMinor;
  final int paidMinor;
  final int dueMinor;
}

class DashboardDebtor {
  const DashboardDebtor({required this.name, required this.outstandingMinor});

  final String name;
  final int outstandingMinor;
}

class DashboardTopProduct {
  const DashboardTopProduct({
    required this.name,
    required this.quantitySold,
    required this.salesMinor,
  });

  final String name;
  final int quantitySold;
  final int salesMinor;
}

class DashboardSummary {
  const DashboardSummary({
    required this.todaySalesMinor,
    required this.todayProfitMinor,
    required this.creditDueMinor,
    required this.lowStockProductCount,
    required this.salesChangePercent,
    required this.activeProductCount,
    required this.newProductCount,
    required this.inactiveProductCount,
    required this.outstandingChangePercent,
    required this.dailyPoints,
    required this.recentSales,
    required this.topDebtors,
    required this.topProducts,
  });

  final int todaySalesMinor;
  final int todayProfitMinor;
  final int creditDueMinor;
  final int lowStockProductCount;

  final double? salesChangePercent;
  final int activeProductCount;
  final int newProductCount;
  final int inactiveProductCount;
  final double? outstandingChangePercent;

  final List<DashboardDailyPoint> dailyPoints;
  final List<DashboardRecentSale> recentSales;
  final List<DashboardDebtor> topDebtors;
  final List<DashboardTopProduct> topProducts;
}

class DashboardService {
  DashboardService(this._database);

  final AppDatabase _database;

  Future<DashboardSummary> getSummary({required String businessId}) async {
    final business = await (_database.select(
      _database.businesses,
    )..where((b) => b.id.equals(businessId))).getSingleOrNull();

    if (business == null) {
      throw StateError('Business not found: $businessId');
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final sevenDaysAgo = today.subtract(const Duration(days: 6));
    final comparisonDay = today.subtract(const Duration(days: 7));

    final completedSales =
        await (_database.select(_database.sales)
              ..where(
                (sale) =>
                    sale.businessId.equals(businessId) &
                    sale.status.equals('completed'),
              )
              ..orderBy([
                (sale) => OrderingTerm(
                  expression: sale.soldAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    final todaysSales = completedSales
        .where(
          (sale) =>
              !sale.soldAt.isBefore(today) && sale.soldAt.isBefore(tomorrow),
        )
        .toList();

    final todaySalesMinor = todaysSales.fold<int>(
      0,
      (sum, sale) => sum + sale.totalMinor,
    );

    final previousDaySales = completedSales
        .where(
          (sale) =>
              !sale.soldAt.isBefore(comparisonDay) &&
              sale.soldAt.isBefore(comparisonDay.add(const Duration(days: 1))),
        )
        .fold<int>(0, (sum, sale) => sum + sale.totalMinor);

    final salesChangePercent = _percentageChange(
      todaySalesMinor,
      previousDaySales,
    );

    // Preserve the existing profit calculation, including item discounts
    // and the sale-level discount.
    var todayProfitMinor = 0;

    for (final sale in todaysSales) {
      final items = await (_database.select(
        _database.saleItems,
      )..where((item) => item.saleId.equals(sale.id))).get();

      var saleProfitMinor = 0;

      for (final item in items) {
        saleProfitMinor +=
            (item.unitPriceMinor - item.purchasePriceMinor) * item.quantity -
            item.discountMinor;
      }

      todayProfitMinor += saleProfitMinor - sale.discountMinor;
    }

    final products = await (_database.select(
      _database.products,
    )..where((p) => p.businessId.equals(businessId))).get();

    final activeProducts = products
        .where((product) => product.isActive)
        .toList();

    final inactiveProducts = products
        .where((product) => !product.isActive)
        .toList();

    final newProductCount = activeProducts
        .where(
          (product) =>
              !product.createdAt.isBefore(sevenDaysAgo) &&
              product.createdAt.isBefore(tomorrow),
        )
        .length;

    final lowStockProductCount = activeProducts
        .where((product) => product.stockQuantity <= product.lowStockThreshold)
        .length;

    final customers =
        await (_database.select(_database.customers)..where(
              (customer) =>
                  customer.businessId.equals(businessId) &
                  customer.isActive.equals(true),
            ))
            .get();

    final allEntries = await (_database.select(
      _database.ledgerEntries,
    )..where((entry) => entry.businessId.equals(businessId))).get();

    final entriesByCustomer = <String, List<dynamic>>{};

    for (final entry in allEntries) {
      entriesByCustomer.putIfAbsent(entry.customerId, () => []).add(entry);
    }

    var creditDueMinor = 0;
    var previousOutstandingMinor = 0;
    final debtors = <DashboardDebtor>[];

    for (final customer in customers) {
      final entries = entriesByCustomer[customer.id] ?? [];

      var currentBalance = customer.openingBalanceMinor;
      var previousBalance = customer.openingBalanceMinor;

      for (final entry in entries) {
        if (entry.entryType == 'sale_credit') {
          currentBalance = (currentBalance + entry.amountMinor.toInt()).toInt();

          if (entry.entryAt.isBefore(
            comparisonDay.add(const Duration(days: 1)),
          )) {
            previousBalance = (previousBalance + entry.amountMinor.toInt())
                .toInt();
          }
        } else if (entry.entryType == 'payment') {
          currentBalance = (currentBalance - entry.amountMinor.toInt()).toInt();

          if (entry.entryAt.isBefore(
            comparisonDay.add(const Duration(days: 1)),
          )) {
            previousBalance = (previousBalance - entry.amountMinor.toInt())
                .toInt();
          }
        }
      }

      if (currentBalance > 0) {
        creditDueMinor += currentBalance;
        debtors.add(
          DashboardDebtor(
            name: customer.name,
            outstandingMinor: currentBalance,
          ),
        );
      }

      if (previousBalance > 0) {
        previousOutstandingMinor += previousBalance;
      }
    }

    debtors.sort((a, b) => b.outstandingMinor.compareTo(a.outstandingMinor));

    final topDebtors = debtors.take(5).toList();

    final outstandingChangePercent = _percentageChange(
      creditDueMinor,
      previousOutstandingMinor,
    );

    final dailyPoints = <DashboardDailyPoint>[];

    for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
      final day = sevenDaysAgo.add(Duration(days: dayOffset));
      final nextDay = day.add(const Duration(days: 1));

      final daySales = completedSales.where(
        (sale) => !sale.soldAt.isBefore(day) && sale.soldAt.isBefore(nextDay),
      );

      var salesMinor = 0;
      var creditMinor = 0;

      for (final sale in daySales) {
        salesMinor += sale.totalMinor;
        creditMinor += sale.dueMinor;
      }

      dailyPoints.add(
        DashboardDailyPoint(
          date: day,
          salesMinor: salesMinor,
          creditMinor: creditMinor,
        ),
      );
    }

    final customerNames = {
      for (final customer in customers) customer.id: customer.name,
    };

    final recentSales = completedSales.take(5).map((sale) {
      final customerName = sale.customerId == null
          ? 'Walk-in customer'
          : customerNames[sale.customerId] ?? 'Inactive customer';

      return DashboardRecentSale(
        invoiceNumber: sale.invoiceNumber,
        customerName: customerName,
        soldAt: sale.soldAt,
        totalMinor: sale.totalMinor,
        paidMinor: sale.paidMinor,
        dueMinor: sale.dueMinor,
      );
    }).toList();

    final saleIds = completedSales.map((sale) => sale.id).toList();
    final productTotals = <String, _ProductSalesTotal>{};

    if (saleIds.isNotEmpty) {
      final items = await (_database.select(
        _database.saleItems,
      )..where((item) => item.saleId.isIn(saleIds))).get();

      for (final item in items) {
        final total = productTotals.putIfAbsent(
          item.productId,
          () => _ProductSalesTotal(item.productName),
        );

        total.quantitySold += item.quantity;
        total.salesMinor += item.lineTotalMinor;
      }
    }

    final topProducts =
        productTotals.values
            .map(
              (total) => DashboardTopProduct(
                name: total.name,
                quantitySold: total.quantitySold,
                salesMinor: total.salesMinor,
              ),
            )
            .toList()
          ..sort((a, b) => b.quantitySold.compareTo(a.quantitySold));

    return DashboardSummary(
      todaySalesMinor: todaySalesMinor,
      todayProfitMinor: todayProfitMinor,
      creditDueMinor: creditDueMinor,
      lowStockProductCount: lowStockProductCount,
      salesChangePercent: salesChangePercent,
      activeProductCount: activeProducts.length,
      newProductCount: newProductCount,
      inactiveProductCount: inactiveProducts.length,
      outstandingChangePercent: outstandingChangePercent,
      dailyPoints: dailyPoints,
      recentSales: recentSales,
      topDebtors: topDebtors,
      topProducts: topProducts.take(5).toList(),
    );
  }

  double? _percentageChange(int current, int previous) {
    if (previous == 0) {
      return current == 0 ? 0 : null;
    }

    return ((current - previous) / previous) * 100;
  }
}

class _ProductSalesTotal {
  _ProductSalesTotal(this.name);

  final String name;
  int quantitySold = 0;
  int salesMinor = 0;
}
