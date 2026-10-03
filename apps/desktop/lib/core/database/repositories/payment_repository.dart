import 'package:drift/drift.dart';

import '../app_database.dart';

class PaymentRepository {
  PaymentRepository(this._database);

  final AppDatabase _database;

  Future<List<Payment>> getByBusinessId(String businessId) {
    return (_database.select(_database.payments)
          ..where((payment) => payment.businessId.equals(businessId))
          ..orderBy([
            (payment) => OrderingTerm.desc(payment.paidAt),
          ]))
        .get();
  }

  Future<Payment?> getById(String paymentId) {
    return (_database.select(_database.payments)
          ..where((payment) => payment.id.equals(paymentId)))
        .getSingleOrNull();
  }

  Future<List<Payment>> getByCustomerId(String customerId) {
    return (_database.select(_database.payments)
          ..where((payment) => payment.customerId.equals(customerId))
          ..orderBy([
            (payment) => OrderingTerm.desc(payment.paidAt),
          ]))
        .get();
  }

  Future<List<Payment>> getBySaleId(String saleId) {
    return (_database.select(_database.payments)
          ..where((payment) => payment.saleId.equals(saleId))
          ..orderBy([
            (payment) => OrderingTerm.desc(payment.paidAt),
          ]))
        .get();
  }

  Future<List<Payment>> getByDateRange({
    required String businessId,
    required DateTime start,
    required DateTime end,
  }) {
    return (_database.select(_database.payments)
          ..where(
            (payment) =>
                payment.businessId.equals(businessId) &
                payment.paidAt.isBetweenValues(start, end),
          )
          ..orderBy([
            (payment) => OrderingTerm.desc(payment.paidAt),
          ]))
        .get();
  }
}