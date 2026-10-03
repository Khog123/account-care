import 'package:drift/drift.dart';

import '../app_database.dart';

class LedgerEntryRepository {
  LedgerEntryRepository(this._database);

  final AppDatabase _database;

  Future<List<LedgerEntry>> getByBusinessId(String businessId) {
    return (_database.select(_database.ledgerEntries)
          ..where((entry) => entry.businessId.equals(businessId))
          ..orderBy([
            (entry) => OrderingTerm.desc(entry.entryAt),
          ]))
        .get();
  }

  Future<LedgerEntry?> getById(String ledgerEntryId) {
    return (_database.select(_database.ledgerEntries)
          ..where((entry) => entry.id.equals(ledgerEntryId)))
        .getSingleOrNull();
  }

  Future<List<LedgerEntry>> getByCustomerId(String customerId) {
    return (_database.select(_database.ledgerEntries)
          ..where((entry) => entry.customerId.equals(customerId))
          ..orderBy([
            (entry) => OrderingTerm.desc(entry.entryAt),
          ]))
        .get();
  }

  Future<List<LedgerEntry>> getBySaleId(String saleId) {
    return (_database.select(_database.ledgerEntries)
          ..where((entry) => entry.saleId.equals(saleId))
          ..orderBy([
            (entry) => OrderingTerm.desc(entry.entryAt),
          ]))
        .get();
  }

  Future<List<LedgerEntry>> getByPaymentId(String paymentId) {
    return (_database.select(_database.ledgerEntries)
          ..where((entry) => entry.paymentId.equals(paymentId))
          ..orderBy([
            (entry) => OrderingTerm.desc(entry.entryAt),
          ]))
        .get();
  }

  Future<List<LedgerEntry>> getByDateRange({
    required String businessId,
    required DateTime start,
    required DateTime end,
  }) {
    return (_database.select(_database.ledgerEntries)
          ..where(
            (entry) =>
                entry.businessId.equals(businessId) &
                entry.entryAt.isBetweenValues(start, end),
          )
          ..orderBy([
            (entry) => OrderingTerm.desc(entry.entryAt),
          ]))
        .get();
  }
}