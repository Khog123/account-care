import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';

import 'package:desktop/core/database/app_database.dart';
import 'package:desktop/core/services/customer_ledger_service.dart';

void main() {
  late AppDatabase database;
  late CustomerLedgerService ledgerService;

  setUp(() {
    database = AppDatabase.test();
    ledgerService = CustomerLedgerService(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('calculates customer outstanding balance from ledger entries',
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

    await database.into(database.customers).insert(
          CustomersCompanion.insert(
            id: 'customer-1',
            businessId: 'business-1',
            name: 'Test Customer',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.ledgerEntries).insert(
          LedgerEntriesCompanion.insert(
            id: 'ledger-1',
            businessId: 'business-1',
            customerId: 'customer-1',
            entryType: 'sale_credit',
            amountMinor: 2000,
            description: const Value('Credit sale'),
            entryAt: now,
            createdAt: now,
          ),
        );

    await database.into(database.ledgerEntries).insert(
          LedgerEntriesCompanion.insert(
            id: 'ledger-2',
            businessId: 'business-1',
            customerId: 'customer-1',
            entryType: 'payment',
            amountMinor: 500,
            description: const Value('Customer payment'),
            entryAt: now,
            createdAt: now,
          ),
        );

    final balance = await ledgerService.getOutstandingBalance(
      businessId: 'business-1',
      customerId: 'customer-1',
    );

    expect(balance, 1500);
  });

  test('returns zero when customer has no ledger entries', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
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

    final balance = await ledgerService.getOutstandingBalance(
      businessId: 'business-1',
      customerId: 'customer-1',
    );

    expect(balance, 0);
  });

  test('does not include another business customer ledger entries',
      () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Business One',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-2',
            name: 'Business Two',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.customers).insert(
          CustomersCompanion.insert(
            id: 'customer-1',
            businessId: 'business-1',
            name: 'Customer One',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.customers).insert(
          CustomersCompanion.insert(
            id: 'customer-2',
            businessId: 'business-2',
            name: 'Customer Two',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.ledgerEntries).insert(
          LedgerEntriesCompanion.insert(
            id: 'ledger-1',
            businessId: 'business-1',
            customerId: 'customer-1',
            entryType: 'sale_credit',
            amountMinor: 2000,
            entryAt: now,
            createdAt: now,
          ),
        );

    await database.into(database.ledgerEntries).insert(
          LedgerEntriesCompanion.insert(
            id: 'ledger-2',
            businessId: 'business-2',
            customerId: 'customer-2',
            entryType: 'sale_credit',
            amountMinor: 9000,
            entryAt: now,
            createdAt: now,
          ),
        );

    final balance = await ledgerService.getOutstandingBalance(
      businessId: 'business-1',
      customerId: 'customer-1',
    );

    expect(balance, 2000);
  });

  test('payment entries reduce the outstanding balance', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
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

    await database.into(database.ledgerEntries).insert(
          LedgerEntriesCompanion.insert(
            id: 'ledger-1',
            businessId: 'business-1',
            customerId: 'customer-1',
            entryType: 'sale_credit',
            amountMinor: 5000,
            entryAt: now,
            createdAt: now,
          ),
        );

    await database.into(database.ledgerEntries).insert(
          LedgerEntriesCompanion.insert(
            id: 'ledger-2',
            businessId: 'business-1',
            customerId: 'customer-1',
            entryType: 'payment',
            amountMinor: 2000,
            entryAt: now,
            createdAt: now,
          ),
        );

    await database.into(database.ledgerEntries).insert(
          LedgerEntriesCompanion.insert(
            id: 'ledger-3',
            businessId: 'business-1',
            customerId: 'customer-1',
            entryType: 'payment',
            amountMinor: 1000,
            entryAt: now,
            createdAt: now,
          ),
        );

    final balance = await ledgerService.getOutstandingBalance(
      businessId: 'business-1',
      customerId: 'customer-1',
    );

    expect(balance, 2000);
  });
}