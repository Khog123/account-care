import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;

import 'package:desktop/core/database/app_database.dart';
import 'package:desktop/core/services/payment_service.dart';

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


    final allPaymentLedgerEntries =
        await (database.select(database.ledgerEntries)
              ..where(
                (entry) => entry.paymentId.equals('fifo-payment-1'),
              ))
            .get();

    final paymentLedgerEntries = allPaymentLedgerEntries
        .where((entry) => entry.entryType == 'payment')
        .toList();


    expect(paymentLedgerEntries, hasLength(1));
    expect(paymentLedgerEntries.single.amountMinor, 220000);
  });
}
