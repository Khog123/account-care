import 'package:drift/drift.dart';

import '../app_database.dart';

class SaleRepository {
  SaleRepository(this._database);

  final AppDatabase _database;

  Future<List<Sale>> getByBusinessId(String businessId) {
    return (_database.select(_database.sales)
          ..where((sale) => sale.businessId.equals(businessId))
          ..orderBy([
            (sale) => OrderingTerm.desc(sale.soldAt),
          ]))
        .get();
  }

  Future<Sale?> getById(String saleId) {
    return (_database.select(_database.sales)
          ..where((sale) => sale.id.equals(saleId)))
        .getSingleOrNull();
  }

  Future<Sale?> getByInvoiceNumber({
    required String businessId,
    required String invoiceNumber,
  }) {
    return (_database.select(_database.sales)
          ..where(
            (sale) =>
                sale.businessId.equals(businessId) &
                sale.invoiceNumber.equals(invoiceNumber),
          ))
        .getSingleOrNull();
  }

  Future<List<Sale>> getByDateRange({
    required String businessId,
    required DateTime start,
    required DateTime end,
  }) {
    return (_database.select(_database.sales)
          ..where(
            (sale) =>
                sale.businessId.equals(businessId) &
                sale.soldAt.isBetweenValues(start, end),
          )
          ..orderBy([
            (sale) => OrderingTerm.desc(sale.soldAt),
          ]))
        .get();
  }
}