import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull;

import 'package:desktop/core/database/app_database.dart';
import 'package:desktop/core/services/payment_service.dart';
import 'package:desktop/core/services/customer_ledger_service.dart';

void main() {
  late AppDatabase database;
  late PaymentService paymentService;

  setUp(() {
    database = AppDatabase.test();
    paymentService = PaymentService(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('records a customer payment and ledger entry', () async {
    final now = DateTime.now();

    await database
        .into(database.businesses)
        .insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-1',
            businessId: 'business-1',
            name: 'Test User',
            username: 'test-user',
            passwordHash: 'test-hash',
            role: 'master_merchant',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            id: 'customer-1',
            businessId: 'business-1',
            name: 'Test Customer',
            openingBalanceMinor: Value(2000),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final paymentId = await paymentService.recordPayment(
      businessId: 'business-1',
      customerId: 'customer-1',
      userId: 'user-1',
      paymentId: 'payment-1',
      amountMinor: 2000,
      paymentMethod: 'cash',
      paidAt: now,
    );

    expect(paymentId, 'payment-1');

    final payment = await (database.select(
      database.payments,
    )..where((payment) => payment.id.equals('payment-1'))).getSingle();

    expect(payment.businessId, 'business-1');
    expect(payment.customerId, 'customer-1');
    expect(payment.userId, 'user-1');
    expect(payment.amountMinor, 2000);
    expect(payment.paymentMethod, 'cash');

    final ledgerEntries = await (database.select(
      database.ledgerEntries,
    )..where((entry) => entry.paymentId.equals('payment-1'))).get();

    expect(ledgerEntries.length, 1);
    expect(ledgerEntries.single.businessId, 'business-1');
    expect(ledgerEntries.single.customerId, 'customer-1');
    expect(ledgerEntries.single.paymentId, 'payment-1');
    expect(ledgerEntries.single.amountMinor, 2000);
    expect(ledgerEntries.single.entryType, 'payment');
  });

  test('rejects a zero payment amount', () async {
    final now = DateTime.now();

    await database
        .into(database.businesses)
        .insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-1',
            businessId: 'business-1',
            name: 'Test User',
            username: 'test-user',
            passwordHash: 'test-hash',
            role: 'master_merchant',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            id: 'customer-1',
            businessId: 'business-1',
            name: 'Test Customer',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await expectLater(
      paymentService.recordPayment(
        businessId: 'business-1',
        customerId: 'customer-1',
        userId: 'user-1',
        paymentId: 'payment-2',
        amountMinor: 0,
        paymentMethod: 'cash',
        paidAt: now,
      ),
      throwsA(isA<ArgumentError>()),
    );

    final payments = await database.select(database.payments).get();
    expect(payments, isEmpty);

    final ledgerEntries = await database.select(database.ledgerEntries).get();
    expect(ledgerEntries, isEmpty);
  });

  test('rejects a negative payment amount', () async {
    final now = DateTime.now();

    await database
        .into(database.businesses)
        .insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-1',
            businessId: 'business-1',
            name: 'Test User',
            username: 'test-user',
            passwordHash: 'test-hash',
            role: 'master_merchant',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            id: 'customer-1',
            businessId: 'business-1',
            name: 'Test Customer',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await expectLater(
      paymentService.recordPayment(
        businessId: 'business-1',
        customerId: 'customer-1',
        userId: 'user-1',
        paymentId: 'payment-3',
        amountMinor: -500,
        paymentMethod: 'cash',
        paidAt: now,
      ),
      throwsA(isA<ArgumentError>()),
    );

    final payments = await database.select(database.payments).get();
    expect(payments, isEmpty);

    final ledgerEntries = await database.select(database.ledgerEntries).get();
    expect(ledgerEntries, isEmpty);
  });

  test('rejects payment for an inactive customer', () async {
    final now = DateTime.now();

    await database
        .into(database.businesses)
        .insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-1',
            businessId: 'business-1',
            name: 'Test User',
            username: 'test-user',
            passwordHash: 'test-hash',
            role: 'master_merchant',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            id: 'customer-1',
            businessId: 'business-1',
            name: 'Inactive Customer',
            isActive: const Value(false),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await expectLater(
      paymentService.recordPayment(
        businessId: 'business-1',
        customerId: 'customer-1',
        userId: 'user-1',
        paymentId: 'payment-4',
        amountMinor: 1000,
        paymentMethod: 'cash',
        paidAt: now,
      ),
      throwsA(isA<StateError>()),
    );

    final payments = await database.select(database.payments).get();
    expect(payments, isEmpty);

    final ledgerEntries = await database.select(database.ledgerEntries).get();
    expect(ledgerEntries, isEmpty);
  });

  test('rejects payment recorded by an inactive user', () async {
    final now = DateTime.now();

    await database
        .into(database.businesses)
        .insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-1',
            businessId: 'business-1',
            name: 'Inactive User',
            username: 'inactive-user',
            passwordHash: 'test-hash',
            role: 'master_merchant',
            isActive: const Value(false),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            id: 'customer-1',
            businessId: 'business-1',
            name: 'Test Customer',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await expectLater(
      paymentService.recordPayment(
        businessId: 'business-1',
        customerId: 'customer-1',
        userId: 'user-1',
        paymentId: 'payment-5',
        amountMinor: 1000,
        paymentMethod: 'cash',
        paidAt: now,
      ),
      throwsA(isA<StateError>()),
    );

    final payments = await database.select(database.payments).get();
    expect(payments, isEmpty);

    final ledgerEntries = await database.select(database.ledgerEntries).get();
    expect(ledgerEntries, isEmpty);
  });

  test('rolls back when payment ID already exists', () async {
    final now = DateTime.now();
    final invoiceDate = now.subtract(const Duration(days: 2));
    final legacyPaymentDate = now.subtract(const Duration(days: 1));

    await database
        .into(database.businesses)
        .insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-1',
            businessId: 'business-1',
            name: 'Test User',
            username: 'test-user',
            passwordHash: 'test-hash',
            role: 'master_merchant',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            id: 'customer-1',
            businessId: 'business-1',
            name: 'Test Customer',
            openingBalanceMinor: Value(2000),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.sales)
        .insert(
          SalesCompanion.insert(
            id: 'sale-1',
            businessId: 'business-1',
            customerId: const Value('customer-1'),
            userId: 'user-1',
            invoiceNumber: 'INV-001',
            subtotalMinor: 1000,
            discountMinor: const Value(0),
            totalMinor: 1000,
            paidMinor: const Value(0),
            dueMinor: const Value(1000),
            status: 'completed',
            soldAt: invoiceDate,
            createdAt: invoiceDate,
          ),
        );

    // This legacy payment has no allocations. recordPayment should
    // attempt to allocate it before inserting the duplicate payment ID.
    await database
        .into(database.payments)
        .insert(
          PaymentsCompanion.insert(
            id: 'payment-legacy',
            businessId: 'business-1',
            customerId: const Value('customer-1'),
            userId: 'user-1',
            amountMinor: 500,
            paymentMethod: 'cash',
            paidAt: legacyPaymentDate,
            createdAt: legacyPaymentDate,
          ),
        );

    await database
        .into(database.payments)
        .insert(
          PaymentsCompanion.insert(
            id: 'payment-6',
            businessId: 'business-1',
            customerId: const Value('customer-1'),
            userId: 'user-1',
            amountMinor: 1000,
            paymentMethod: 'cash',
            paidAt: now,
            createdAt: now,
          ),
        );

    await expectLater(
      paymentService.recordPayment(
        businessId: 'business-1',
        customerId: 'customer-1',
        userId: 'user-1',
        paymentId: 'payment-6',
        amountMinor: 500,
        paymentMethod: 'cash',
        paidAt: now,
      ),
      throwsA(isA<Exception>()),
    );

    final payments = await database.select(database.payments).get();

    expect(payments, hasLength(2));
    expect(
      payments.singleWhere((payment) => payment.id == 'payment-6').amountMinor,
      1000,
    );

    final invoice = await (database.select(
      database.sales,
    )..where((sale) => sale.id.equals('sale-1'))).getSingle();

    expect(invoice.paidMinor, 0);
    expect(invoice.dueMinor, 1000);

    final allocations = await database
        .select(database.paymentAllocations)
        .get();

    expect(allocations, isEmpty);

    final ledgerEntries = await database.select(database.ledgerEntries).get();

    expect(ledgerEntries, isEmpty);
  });

  test('records a partial payment and leaves the remaining balance', () async {
    final now = DateTime.now();

    await database
        .into(database.businesses)
        .insert(
          BusinessesCompanion.insert(
            id: 'business-2',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-2',
            businessId: 'business-2',
            name: 'Test User',
            username: 'test-user-2',
            passwordHash: 'test-hash',
            role: 'master_merchant',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            id: 'customer-2',
            businessId: 'business-2',
            name: 'Test Customer',
            openingBalanceMinor: Value(2000),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final paymentId = await paymentService.recordPayment(
      businessId: 'business-2',
      customerId: 'customer-2',
      userId: 'user-2',
      paymentId: 'payment-7',
      amountMinor: 1000,
      paymentMethod: 'cash',
      paidAt: now,
    );

    expect(paymentId, 'payment-7');

    final ledgerEntries = await database.select(database.ledgerEntries).get();

    expect(ledgerEntries, hasLength(1));
    expect(ledgerEntries.single.entryType, 'payment');
    expect(ledgerEntries.single.amountMinor, 1000);

    final remainingBalance = 2000 - ledgerEntries.single.amountMinor;

    expect(remainingBalance, 1000);
  });

  test('rejects a payment greater than the outstanding balance', () async {
    final now = DateTime.now();

    await database
        .into(database.businesses)
        .insert(
          BusinessesCompanion.insert(
            id: 'business-3',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-3',
            businessId: 'business-3',
            name: 'Test User',
            username: 'test-user-3',
            passwordHash: 'test-hash',
            role: 'master_merchant',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            id: 'customer-3',
            businessId: 'business-3',
            name: 'Test Customer',
            openingBalanceMinor: Value(2000),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await expectLater(
      paymentService.recordPayment(
        businessId: 'business-3',
        customerId: 'customer-3',
        userId: 'user-3',
        paymentId: 'payment-8',
        amountMinor: 2001,
        paymentMethod: 'cash',
        paidAt: now,
      ),
      throwsA(isA<ArgumentError>()),
    );

    final payments = await database.select(database.payments).get();
    expect(payments, isEmpty);

    final ledgerEntries = await database.select(database.ledgerEntries).get();
    expect(ledgerEntries, isEmpty);
  });

  test(
    'rejects a payment when the customer has no outstanding balance',
    () async {
      final now = DateTime.now();

      await database
          .into(database.businesses)
          .insert(
            BusinessesCompanion.insert(
              id: 'business-4',
              name: 'Test Business',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await database
          .into(database.users)
          .insert(
            UsersCompanion.insert(
              id: 'user-4',
              businessId: 'business-4',
              name: 'Test User',
              username: 'test-user-4',
              passwordHash: 'test-hash',
              role: 'master_merchant',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await database
          .into(database.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'customer-4',
              businessId: 'business-4',
              name: 'Test Customer',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await expectLater(
        paymentService.recordPayment(
          businessId: 'business-4',
          customerId: 'customer-4',
          userId: 'user-4',
          paymentId: 'payment-9',
          amountMinor: 1000,
          paymentMethod: 'cash',
          paidAt: now,
        ),
        throwsA(isA<StateError>()),
      );

      final payments = await database.select(database.payments).get();
      expect(payments, isEmpty);

      final ledgerEntries = await database.select(database.ledgerEntries).get();
      expect(ledgerEntries, isEmpty);
    },
  );

  test('repairs the ledger entry for a legacy payment exactly once', () async {
    final now = DateTime.now();
    final invoiceDate = now.subtract(const Duration(days: 2));
    final legacyPaymentDate = now.subtract(const Duration(days: 1));

    await database
        .into(database.businesses)
        .insert(
          BusinessesCompanion.insert(
            id: 'legacy-business',
            name: 'Legacy Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: 'legacy-user',
            businessId: 'legacy-business',
            name: 'Legacy Test User',
            username: 'legacy-user',
            passwordHash: 'test-hash',
            role: 'master_merchant',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            id: 'legacy-customer',
            businessId: 'legacy-business',
            name: 'Legacy Customer',
            openingBalanceMinor: const Value(100000),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.sales)
        .insert(
          SalesCompanion.insert(
            id: 'legacy-sale',
            businessId: 'legacy-business',
            customerId: const Value('legacy-customer'),
            userId: 'legacy-user',
            invoiceNumber: 'LEGACY-001',
            subtotalMinor: 100000,
            discountMinor: const Value(0),
            totalMinor: 100000,
            paidMinor: const Value(20000),
            dueMinor: const Value(80000),
            status: 'completed',
            soldAt: invoiceDate,
            createdAt: invoiceDate,
          ),
        );

    await database
        .into(database.paymentAllocations)
        .insert(
          PaymentAllocationsCompanion.insert(
            id: 'legacy-partial-allocation',
            businessId: 'legacy-business',
            paymentId: 'legacy-payment',
            saleId: 'legacy-sale',
            amountMinor: 20000,
            allocatedAt: legacyPaymentDate,
            createdAt: legacyPaymentDate,
          ),
        );

    await database
        .into(database.ledgerEntries)
        .insert(
          LedgerEntriesCompanion.insert(
            id: 'legacy-sale-credit',
            businessId: 'legacy-business',
            customerId: 'legacy-customer',
            saleId: const Value('legacy-sale'),
            entryType: 'sale_credit',
            amountMinor: 100000,
            description: const Value('Legacy invoice credit'),
            entryAt: invoiceDate,
            createdAt: invoiceDate,
          ),
        );

    // Historical payment exists, but has no allocation or payment ledger entry.
    await database
        .into(database.payments)
        .insert(
          PaymentsCompanion.insert(
            id: 'legacy-payment',
            businessId: 'legacy-business',
            customerId: const Value('legacy-customer'),
            userId: 'legacy-user',
            amountMinor: 50000,
            paymentMethod: 'cash',
            paidAt: legacyPaymentDate,
            createdAt: legacyPaymentDate,
          ),
        );

    // Recording another payment triggers the legacy-allocation repair.
    await paymentService.recordPayment(
      businessId: 'legacy-business',
      customerId: 'legacy-customer',
      userId: 'legacy-user',
      paymentId: 'new-payment',
      amountMinor: 50000,
      paymentMethod: 'cash',
      paidAt: now,
    );

    final invoice = await (database.select(
      database.sales,
    )..where((sale) => sale.id.equals('legacy-sale'))).getSingle();

    expect(invoice.paidMinor, 100000);
    expect(invoice.dueMinor, 0);

    final allLedgerEntries = await database
        .select(database.ledgerEntries)
        .get();

    final paymentLedgerEntries = allLedgerEntries
        .where(
          (entry) =>
              entry.businessId == 'legacy-business' &&
              entry.customerId == 'legacy-customer' &&
              entry.entryType == 'payment',
        )
        .toList();

    // Both the legacy payment and the new payment should be represented once.
    expect(paymentLedgerEntries, hasLength(2));
    expect(
      paymentLedgerEntries.fold<int>(
        0,
        (total, entry) => total + entry.amountMinor,
      ),
      100000,
    );
  });

  test(
    'repairs a legacy payment against opening balance without invoices',
    () async {
      final now = DateTime.now();
      final legacyPaymentDate = now.subtract(const Duration(days: 1));

      await database
          .into(database.businesses)
          .insert(
            BusinessesCompanion.insert(
              id: 'opening-business',
              name: 'Opening Balance Test Business',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await database
          .into(database.users)
          .insert(
            UsersCompanion.insert(
              id: 'opening-user',
              businessId: 'opening-business',
              name: 'Opening Balance Test User',
              username: 'opening-user',
              passwordHash: 'test-hash',
              role: 'master_merchant',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await database
          .into(database.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'opening-customer',
              businessId: 'opening-business',
              name: 'Opening Balance Customer',
              openingBalanceMinor: const Value(100000),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // A historical payment exists, but has no ledger entry or invoice.
      await database
          .into(database.payments)
          .insert(
            PaymentsCompanion.insert(
              id: 'opening-legacy-payment',
              businessId: 'opening-business',
              customerId: const Value('opening-customer'),
              userId: 'opening-user',
              amountMinor: 30000,
              paymentMethod: 'cash',
              paidAt: legacyPaymentDate,
              createdAt: legacyPaymentDate,
            ),
          );

      // Repair the legacy payment and record a new payment.
      await paymentService.recordPayment(
        businessId: 'opening-business',
        customerId: 'opening-customer',
        userId: 'opening-user',
        paymentId: 'opening-new-payment',
        amountMinor: 10000,
        paymentMethod: 'cash',
        paidAt: now,
      );

      final paymentEntries =
          await (database.select(database.ledgerEntries)..where(
                (entry) =>
                    entry.businessId.equals('opening-business') &
                    entry.customerId.equals('opening-customer') &
                    entry.entryType.equals('payment'),
              ))
              .get();

      expect(paymentEntries, hasLength(2));
      expect(
        paymentEntries.fold<int>(
          0,
          (total, entry) => total + entry.amountMinor,
        ),
        40000,
      );

      final allocations =
          await (database.select(database.paymentAllocations)..where(
                (allocation) =>
                    allocation.businessId.equals('opening-business'),
              ))
              .get();

      expect(allocations, isEmpty);

      final customerLedgerService = CustomerLedgerService(database);

      final outstandingMinor = await customerLedgerService
          .getOutstandingBalance(
            businessId: 'opening-business',
            customerId: 'opening-customer',
          );

      expect(outstandingMinor, 60000);
    },
  );

  test(
    'rejects a legacy payment allocation referencing a missing invoice',
    () async {
      final now = DateTime.now();
      final legacyPaymentDate = now.subtract(const Duration(days: 1));

      await database
          .into(database.businesses)
          .insert(
            BusinessesCompanion.insert(
              id: 'invalid-allocation-business',
              name: 'Invalid Allocation Business',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await database
          .into(database.users)
          .insert(
            UsersCompanion.insert(
              id: 'invalid-allocation-user',
              businessId: 'invalid-allocation-business',
              name: 'Invalid Allocation User',
              username: 'invalid-allocation-user',
              passwordHash: 'test-hash',
              role: 'master_merchant',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await database
          .into(database.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'invalid-allocation-customer',
              businessId: 'invalid-allocation-business',
              name: 'Invalid Allocation Customer',
              openingBalanceMinor: const Value(100000),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await database
          .into(database.payments)
          .insert(
            PaymentsCompanion.insert(
              id: 'invalid-allocation-legacy-payment',
              businessId: 'invalid-allocation-business',
              customerId: const Value('invalid-allocation-customer'),
              userId: 'invalid-allocation-user',
              amountMinor: 30000,
              paymentMethod: 'cash',
              paidAt: legacyPaymentDate,
              createdAt: legacyPaymentDate,
            ),
          );

      await database
          .into(database.paymentAllocations)
          .insert(
            PaymentAllocationsCompanion.insert(
              id: 'invalid-allocation-row',
              businessId: 'invalid-allocation-business',
              paymentId: 'invalid-allocation-legacy-payment',
              saleId: 'missing-invoice',
              amountMinor: 10000,
              allocatedAt: legacyPaymentDate,
              createdAt: legacyPaymentDate,
            ),
          );

      await expectLater(
        paymentService.recordPayment(
          businessId: 'invalid-allocation-business',
          customerId: 'invalid-allocation-customer',
          userId: 'invalid-allocation-user',
          paymentId: 'should-not-be-inserted',
          amountMinor: 10000,
          paymentMethod: 'cash',
          paidAt: now,
        ),
        throwsA(isA<StateError>()),
      );

      final attemptedPayment =
          await (database.select(database.payments)..where(
                (payment) => payment.id.equals('should-not-be-inserted'),
              ))
              .getSingleOrNull();

      expect(attemptedPayment, isNull);
    },
  );

  test(
    'rejects a legacy payment with allocations exceeding its amount',
    () async {
      final now = DateTime.now();
      final legacyPaymentDate = now.subtract(const Duration(days: 1));

      await database
          .into(database.businesses)
          .insert(
            BusinessesCompanion.insert(
              id: 'overallocated-business',
              name: 'Overallocated Test Business',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await database
          .into(database.users)
          .insert(
            UsersCompanion.insert(
              id: 'overallocated-user',
              businessId: 'overallocated-business',
              name: 'Overallocated Test User',
              username: 'overallocated-user',
              passwordHash: 'test-hash',
              role: 'master_merchant',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await database
          .into(database.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'overallocated-customer',
              businessId: 'overallocated-business',
              name: 'Overallocated Customer',
              openingBalanceMinor: const Value(100000),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await database
          .into(database.payments)
          .insert(
            PaymentsCompanion.insert(
              id: 'overallocated-legacy-payment',
              businessId: 'overallocated-business',
              customerId: const Value('overallocated-customer'),
              userId: 'overallocated-user',
              amountMinor: 30000,
              paymentMethod: 'cash',
              paidAt: legacyPaymentDate,
              createdAt: legacyPaymentDate,
            ),
          );

      await database
          .into(database.paymentAllocations)
          .insert(
            PaymentAllocationsCompanion.insert(
              id: 'overallocated-allocation-1',
              businessId: 'overallocated-business',
              paymentId: 'overallocated-legacy-payment',
              saleId: 'legacy-sale-1',
              amountMinor: 20000,
              allocatedAt: legacyPaymentDate,
              createdAt: legacyPaymentDate,
            ),
          );

      await database
          .into(database.paymentAllocations)
          .insert(
            PaymentAllocationsCompanion.insert(
              id: 'overallocated-allocation-2',
              businessId: 'overallocated-business',
              paymentId: 'overallocated-legacy-payment',
              saleId: 'legacy-sale-2',
              amountMinor: 20000,
              allocatedAt: legacyPaymentDate,
              createdAt: legacyPaymentDate,
            ),
          );

      await expectLater(
        paymentService.recordPayment(
          businessId: 'overallocated-business',
          customerId: 'overallocated-customer',
          userId: 'overallocated-user',
          paymentId: 'should-not-be-inserted',
          amountMinor: 10000,
          paymentMethod: 'cash',
          paidAt: now,
        ),
        throwsA(isA<StateError>()),
      );

      final attemptedPayment =
          await (database.select(database.payments)..where(
                (payment) => payment.id.equals('should-not-be-inserted'),
              ))
              .getSingleOrNull();

      expect(attemptedPayment, isNull);

      final legacyLedgerEntries =
          await (database.select(database.ledgerEntries)..where(
                (entry) =>
                    entry.businessId.equals('overallocated-business') &
                    entry.paymentId.equals('overallocated-legacy-payment'),
              ))
              .get();

      expect(legacyLedgerEntries, isEmpty);
    },
  );

  test(
    'clears invoice first and preserves remaining opening balance',
    () async {
      final now = DateTime.now();
      final invoiceDate = now.subtract(const Duration(days: 1));

      await database
          .into(database.businesses)
          .insert(
            BusinessesCompanion.insert(
              id: 'mixed-business',
              name: 'Mixed Balance Test Business',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await database
          .into(database.users)
          .insert(
            UsersCompanion.insert(
              id: 'mixed-user',
              businessId: 'mixed-business',
              name: 'Mixed Balance Test User',
              username: 'mixed-user',
              passwordHash: 'test-hash',
              role: 'master_merchant',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await database
          .into(database.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'mixed-customer',
              businessId: 'mixed-business',
              name: 'Mixed Balance Customer',
              openingBalanceMinor: const Value(50000),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await database
          .into(database.sales)
          .insert(
            SalesCompanion.insert(
              id: 'mixed-sale',
              businessId: 'mixed-business',
              customerId: const Value('mixed-customer'),
              userId: 'mixed-user',
              invoiceNumber: 'MIXED-001',
              subtotalMinor: 100000,
              discountMinor: const Value(0),
              totalMinor: 100000,
              paidMinor: const Value(0),
              dueMinor: const Value(100000),
              status: 'completed',
              soldAt: invoiceDate,
              createdAt: invoiceDate,
            ),
          );

      await database
          .into(database.ledgerEntries)
          .insert(
            LedgerEntriesCompanion.insert(
              id: 'mixed-sale-ledger',
              businessId: 'mixed-business',
              customerId: 'mixed-customer',
              saleId: const Value('mixed-sale'),
              entryType: 'sale_credit',
              amountMinor: 100000,
              description: const Value('Credit for MIXED-001'),
              entryAt: invoiceDate,
              createdAt: invoiceDate,
            ),
          );

      await paymentService.recordPayment(
        businessId: 'mixed-business',
        customerId: 'mixed-customer',
        userId: 'mixed-user',
        paymentId: 'mixed-payment',
        amountMinor: 120000,
        paymentMethod: 'cash',
        paidAt: now,
      );

      final invoice =
          await (database.select(database.sales)..where(
                (sale) =>
                    sale.businessId.equals('mixed-business') &
                    sale.id.equals('mixed-sale'),
              ))
              .getSingle();

      expect(invoice.paidMinor, 100000);
      expect(invoice.dueMinor, 0);

      final allocations =
          await (database.select(database.paymentAllocations)..where(
                (allocation) => allocation.paymentId.equals('mixed-payment'),
              ))
              .get();

      expect(allocations, hasLength(1));
      expect(allocations.single.saleId, 'mixed-sale');
      expect(allocations.single.amountMinor, 100000);

      final paymentLedgerEntries =
          await (database.select(database.ledgerEntries)..where(
                (entry) =>
                    entry.businessId.equals('mixed-business') &
                    entry.customerId.equals('mixed-customer') &
                    entry.paymentId.equals('mixed-payment') &
                    entry.entryType.equals('payment'),
              ))
              .get();

      expect(paymentLedgerEntries, hasLength(1));
      expect(paymentLedgerEntries.single.amountMinor, 120000);

      final customerLedgerService = CustomerLedgerService(database);
      final outstandingBalance = await customerLedgerService
          .getOutstandingBalance(
            businessId: 'mixed-business',
            customerId: 'mixed-customer',
          );

      // Rs. 500 opening balance + Rs. 1,000 invoice - Rs. 1,200 payment.
      expect(outstandingBalance, 30000);
    },
  );

  test('allocates a payment to the oldest invoices first', () async {
    final now = DateTime.now();
    final firstSaleDate = now.subtract(const Duration(days: 3));
    final secondSaleDate = now.subtract(const Duration(days: 2));
    final thirdSaleDate = now.subtract(const Duration(days: 1));

    await database
        .into(database.businesses)
        .insert(
          BusinessesCompanion.insert(
            id: 'fifo-business',
            name: 'FIFO Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: 'fifo-user',
            businessId: 'fifo-business',
            name: 'FIFO Test User',
            username: 'fifo-user',
            passwordHash: 'test-hash',
            role: 'master_merchant',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            id: 'fifo-customer',
            businessId: 'fifo-business',
            name: 'FIFO Customer',
            createdAt: now,
            updatedAt: now,
          ),
        );

    Future<void> addInvoice({
      required String saleId,
      required String invoiceNumber,
      required int amountMinor,
      required DateTime soldAt,
    }) async {
      await database
          .into(database.sales)
          .insert(
            SalesCompanion.insert(
              id: saleId,
              businessId: 'fifo-business',
              customerId: const Value('fifo-customer'),
              userId: 'fifo-user',
              invoiceNumber: invoiceNumber,
              subtotalMinor: amountMinor,
              discountMinor: const Value(0),
              totalMinor: amountMinor,
              paidMinor: const Value(0),
              dueMinor: Value(amountMinor),
              status: 'completed',
              soldAt: soldAt,
              createdAt: soldAt,
            ),
          );

      await database
          .into(database.ledgerEntries)
          .insert(
            LedgerEntriesCompanion.insert(
              id: 'ledger-$saleId',
              businessId: 'fifo-business',
              customerId: 'fifo-customer',
              saleId: Value(saleId),
              entryType: 'sale_credit',
              amountMinor: amountMinor,
              description: Value('Credit for $invoiceNumber'),
              entryAt: soldAt,
              createdAt: soldAt,
            ),
          );
    }

    await addInvoice(
      saleId: 'fifo-sale-1',
      invoiceNumber: 'FIFO-001',
      amountMinor: 100000,
      soldAt: firstSaleDate,
    );

    await addInvoice(
      saleId: 'fifo-sale-2',
      invoiceNumber: 'FIFO-002',
      amountMinor: 150000,
      soldAt: secondSaleDate,
    );

    await addInvoice(
      saleId: 'fifo-sale-3',
      invoiceNumber: 'FIFO-003',
      amountMinor: 200000,
      soldAt: thirdSaleDate,
    );

    final paymentId = await paymentService.recordPayment(
      businessId: 'fifo-business',
      customerId: 'fifo-customer',
      userId: 'fifo-user',
      paymentId: 'fifo-payment-1',
      amountMinor: 220000,
      paymentMethod: 'cash',
      paidAt: now,
    );

    expect(paymentId, 'fifo-payment-1');

    final invoices =
        await (database.select(database.sales)
              ..where((sale) => sale.businessId.equals('fifo-business'))
              ..orderBy([(sale) => OrderingTerm.asc(sale.soldAt)]))
            .get();

    expect(invoices, hasLength(3));

    // First invoice: Rs. 1,000 paid in full.
    expect(invoices[0].paidMinor, 100000);
    expect(invoices[0].dueMinor, 0);

    // Second invoice: Rs. 1,200 paid, Rs. 300 remains.
    expect(invoices[1].paidMinor, 120000);
    expect(invoices[1].dueMinor, 30000);

    // Third invoice: untouched; Rs. 2,000 remains.
    expect(invoices[2].paidMinor, 0);
    expect(invoices[2].dueMinor, 200000);

    final allocations =
        await (database.select(database.paymentAllocations)..where(
              (allocation) => allocation.paymentId.equals('fifo-payment-1'),
            ))
            .get();

    expect(allocations, hasLength(2));

    final allocatedAmounts = {
      for (final allocation in allocations)
        allocation.saleId: allocation.amountMinor,
    };

    expect(allocatedAmounts['fifo-sale-1'], 100000);
    expect(allocatedAmounts['fifo-sale-2'], 120000);
    expect(allocatedAmounts.containsKey('fifo-sale-3'), isFalse);

    final paymentRows = await (database.select(
      database.payments,
    )..where((payment) => payment.id.equals('fifo-payment-1'))).get();

    expect(paymentRows, hasLength(1));
    expect(paymentRows.single.amountMinor, 220000);

    final allPaymentLedgerEntries = await (database.select(
      database.ledgerEntries,
    )..where((entry) => entry.paymentId.equals('fifo-payment-1'))).get();

    final paymentLedgerEntries = allPaymentLedgerEntries
        .where((entry) => entry.entryType == 'payment')
        .toList();

    expect(paymentLedgerEntries, hasLength(1));
    expect(paymentLedgerEntries.single.amountMinor, 220000);
  });

  test(
    'does not duplicate existing legacy allocations on repeated reconciliation',
    () async {
      final now = DateTime.now();
      final invoiceDate = now.subtract(const Duration(days: 3));
      final legacyPaymentDate = now.subtract(const Duration(days: 2));
      final reconciliationPaymentDate = now.subtract(const Duration(days: 1));

      await database
          .into(database.businesses)
          .insert(
            BusinessesCompanion.insert(
              id: 'repeat-business',
              name: 'Repeat Reconciliation Business',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await database
          .into(database.users)
          .insert(
            UsersCompanion.insert(
              id: 'repeat-user',
              businessId: 'repeat-business',
              name: 'Repeat Test User',
              username: 'repeat-user',
              passwordHash: 'test-hash',
              role: 'master_merchant',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await database
          .into(database.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'repeat-customer',
              businessId: 'repeat-business',
              name: 'Repeat Test Customer',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await database
          .into(database.sales)
          .insert(
            SalesCompanion.insert(
              id: 'repeat-sale',
              businessId: 'repeat-business',
              customerId: const Value('repeat-customer'),
              userId: 'repeat-user',
              invoiceNumber: 'REPEAT-001',
              subtotalMinor: 100000,
              discountMinor: const Value(0),
              totalMinor: 100000,
              paidMinor: const Value(40000),
              dueMinor: const Value(60000),
              status: 'completed',
              soldAt: invoiceDate,
              createdAt: invoiceDate,
            ),
          );

      await database
          .into(database.ledgerEntries)
          .insert(
            LedgerEntriesCompanion.insert(
              id: 'repeat-sale-credit',
              businessId: 'repeat-business',
              customerId: 'repeat-customer',
              saleId: const Value('repeat-sale'),
              entryType: 'sale_credit',
              amountMinor: 100000,
              description: const Value('Repeat reconciliation invoice'),
              entryAt: invoiceDate,
              createdAt: invoiceDate,
            ),
          );

      await database
          .into(database.payments)
          .insert(
            PaymentsCompanion.insert(
              id: 'repeat-legacy-payment',
              businessId: 'repeat-business',
              customerId: const Value('repeat-customer'),
              userId: 'repeat-user',
              amountMinor: 40000,
              paymentMethod: 'cash',
              paidAt: legacyPaymentDate,
              createdAt: legacyPaymentDate,
            ),
          );

      // The existing allocation should be recognized, not duplicated.
      await database
          .into(database.paymentAllocations)
          .insert(
            PaymentAllocationsCompanion.insert(
              id: 'repeat-existing-allocation',
              businessId: 'repeat-business',
              paymentId: 'repeat-legacy-payment',
              saleId: 'repeat-sale',
              amountMinor: 40000,
              allocatedAt: legacyPaymentDate,
              createdAt: legacyPaymentDate,
            ),
          );

      // Record a small payment to trigger legacy reconciliation.
      await paymentService.recordPayment(
        businessId: 'repeat-business',
        customerId: 'repeat-customer',
        userId: 'repeat-user',
        paymentId: 'repeat-trigger-1',
        amountMinor: 10000,
        paymentMethod: 'cash',
        paidAt: reconciliationPaymentDate,
      );

      final allocationsAfterFirst = await (database.select(
        database.paymentAllocations,
      )..where((row) => row.businessId.equals('repeat-business'))).get();

      final invoiceAfterFirst = await (database.select(
        database.sales,
      )..where((row) => row.id.equals('repeat-sale'))).getSingle();

      // Trigger reconciliation again with another payment.
      await paymentService.recordPayment(
        businessId: 'repeat-business',
        customerId: 'repeat-customer',
        userId: 'repeat-user',
        paymentId: 'repeat-trigger-2',
        amountMinor: 10000,
        paymentMethod: 'cash',
        paidAt: now,
      );

      final allocationsAfterSecond = await (database.select(
        database.paymentAllocations,
      )..where((row) => row.businessId.equals('repeat-business'))).get();

      final invoiceAfterSecond = await (database.select(
        database.sales,
      )..where((row) => row.id.equals('repeat-sale'))).getSingle();

      expect(allocationsAfterFirst.length, 2);
      expect(allocationsAfterSecond.length, 3);

      // Only the two new payments should reduce the invoice further.
      expect(invoiceAfterFirst.paidMinor, 50000);
      expect(invoiceAfterFirst.dueMinor, 50000);
      expect(invoiceAfterSecond.paidMinor, 60000);
      expect(invoiceAfterSecond.dueMinor, 40000);

      final legacyAllocations = allocationsAfterSecond
          .where((row) => row.paymentId == 'repeat-legacy-payment')
          .toList();

      expect(legacyAllocations, hasLength(1));
      expect(legacyAllocations.single.amountMinor, 40000);

      final legacyPaymentLedger =
          await (database.select(database.ledgerEntries)..where(
                (row) =>
                    row.paymentId.equals('repeat-legacy-payment') &
                    row.entryType.equals('payment'),
              ))
              .get();

      expect(legacyPaymentLedger, hasLength(1));
    },
  );
}
