import 'package:drift/drift.dart';

import '../database/app_database.dart';

class CustomerLedgerService {
  CustomerLedgerService(this._database);

  final AppDatabase _database;

  Future<int> getOutstandingBalance({
    required String businessId,
    required String customerId,
  }) async {
    final customer = await (_database.select(_database.customers)
          ..where(
            (customer) =>
                customer.id.equals(customerId) &
                customer.businessId.equals(businessId),
          ))
        .getSingleOrNull();

    if (customer == null) {
      throw StateError(
        'Customer not found for this business: $customerId',
      );
    }

    final entries = await getLedgerEntries(
      businessId: businessId,
      customerId: customerId,
    );

    var balanceMinor = customer.openingBalanceMinor;

    for (final entry in entries) {
      switch (entry.entryType) {
        case 'sale_credit':
          balanceMinor += entry.amountMinor;
          break;

        case 'payment':
          balanceMinor -= entry.amountMinor;
          break;
      }
    }

    return balanceMinor;
  }

  Future<List<LedgerEntry>> getLedgerEntries({
    required String businessId,
    required String customerId,
  }) {
    return (_database.select(_database.ledgerEntries)
          ..where(
            (entry) =>
                entry.businessId.equals(businessId) &
                entry.customerId.equals(customerId),
          )
          ..orderBy([
            (entry) => OrderingTerm.desc(entry.entryAt),
          ]))
        .get();
  }
}
