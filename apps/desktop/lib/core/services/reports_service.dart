import 'package:drift/drift.dart';

import '../database/app_database.dart';

class SalesReport {
  const SalesReport({
    required this.saleCount,
    required this.totalSalesMinor,
    required this.totalPaidMinor,
    required this.totalCreditMinor,
    required this.totalProfitMinor,
  });

  final int saleCount;
  final int totalSalesMinor;
  final int totalPaidMinor;
  final int totalCreditMinor;
  final int totalProfitMinor;
}

class TopSellingProduct {
  const TopSellingProduct({
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.salesMinor,
  });

  final String productId;
  final String productName;
  final int quantitySold;
  final int salesMinor;
}

class ReportsService {
  ReportsService(this._database);

  final AppDatabase _database;

  Future<SalesReport> getSalesReport({
    required String businessId,
    required DateTime from,
    required DateTime to,
  }) async {
    final trimmedBusinessId = businessId.trim();

    if (trimmedBusinessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty.');
    }

    if (from.isAfter(to)) {
      throw ArgumentError(
        'Report start date cannot be after end date.',
      );
    }

    final business = await (_database.select(_database.businesses)
          ..where(
            (business) =>
                business.id.equals(trimmedBusinessId),
          ))
        .getSingleOrNull();

    if (business == null) {
      throw StateError(
        'Business not found: $trimmedBusinessId',
      );
    }

    final sales = await (_database.select(_database.sales)
          ..where(
            (sale) =>
                sale.businessId.equals(trimmedBusinessId) &
                sale.soldAt.isBiggerOrEqualValue(from) &
                sale.soldAt.isSmallerOrEqualValue(to) &
                sale.status.equals('completed'),
          ))
        .get();

    var totalSalesMinor = 0;
    var totalPaidMinor = 0;
    var totalCreditMinor = 0;
    var totalProfitMinor = 0;

    for (final sale in sales) {
      totalSalesMinor += sale.totalMinor;
      totalPaidMinor += sale.paidMinor;
      totalCreditMinor += sale.dueMinor;

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

        totalProfitMinor += itemProfit;
      }

      // Sale-level discount applies after line-item totals.
      totalProfitMinor -= sale.discountMinor;
    }

    return SalesReport(
      saleCount: sales.length,
      totalSalesMinor: totalSalesMinor,
      totalPaidMinor: totalPaidMinor,
      totalCreditMinor: totalCreditMinor,
      totalProfitMinor: totalProfitMinor,
    );
  }

  Future<List<TopSellingProduct>> getTopSellingProducts({
    required String businessId,
    required DateTime from,
    required DateTime to,
  }) async {
    final trimmedBusinessId = businessId.trim();

    if (trimmedBusinessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty.');
    }

    if (from.isAfter(to)) {
      throw ArgumentError(
        'Report start date cannot be after end date.',
      );
    }

    final business = await (_database.select(_database.businesses)
          ..where(
            (business) =>
                business.id.equals(trimmedBusinessId),
          ))
        .getSingleOrNull();

    if (business == null) {
      throw StateError(
        'Business not found: $trimmedBusinessId',
      );
    }

    final rows = await _database.customSelect(
      '''
      SELECT
        sale_items.product_id AS product_id,
        sale_items.product_name AS product_name,
        SUM(sale_items.quantity) AS quantity_sold,
        SUM(sale_items.line_total_minor) AS sales_minor
      FROM sale_items
      INNER JOIN sales
        ON sales.id = sale_items.sale_id
      WHERE sales.business_id = ?
        AND sales.sold_at >= ?
        AND sales.sold_at <= ?
        AND sales.status = 'completed'
      GROUP BY
        sale_items.product_id,
        sale_items.product_name
      ORDER BY
        quantity_sold DESC,
        sales_minor DESC,
        product_name ASC
      ''',
      variables: [
        Variable<String>(trimmedBusinessId),
        Variable<DateTime>(from),
        Variable<DateTime>(to),
      ],
      readsFrom: {
        _database.sales,
        _database.saleItems,
      },
    ).get();

    return rows.map((row) {
      return TopSellingProduct(
        productId: row.read<String>('product_id'),
        productName: row.read<String>('product_name'),
        quantitySold: row.read<int>('quantity_sold'),
        salesMinor: row.read<int>('sales_minor'),
      );
    }).toList();
  }
}