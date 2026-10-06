import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;

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

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
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

    await database.into(database.customers).insert(
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

    final payment = await (database.select(database.payments)
          ..where((payment) => payment.id.equals('payment-1')))
        .getSingle();

    expect(payment.businessId, 'business-1');
    expect(payment.customerId, 'customer-1');
    expect(payment.userId, 'user-1');
    expect(payment.amountMinor, 2000);
    expect(payment.paymentMethod, 'cash');

    final ledgerEntries = await (database.select(database.ledgerEntries)
          ..where((entry) => entry.paymentId.equals('payment-1')))
        .get();

    expect(ledgerEntries.length, 1);
    expect(ledgerEntries.single.businessId, 'business-1');
    expect(ledgerEntries.single.customerId, 'customer-1');
    expect(ledgerEntries.single.paymentId, 'payment-1');
    expect(ledgerEntries.single.amountMinor, 2000);
    expect(ledgerEntries.single.entryType, 'payment');
  });

  test('rejects a zero payment amount', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
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

    await database.into(database.customers).insert(
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

    final ledgerEntries =
        await database.select(database.ledgerEntries).get();
    expect(ledgerEntries, isEmpty);
  });

  test('rejects a negative payment amount', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
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

    await database.into(database.customers).insert(
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

    final ledgerEntries =
        await database.select(database.ledgerEntries).get();
    expect(ledgerEntries, isEmpty);
  });

  test('rejects payment for an inactive customer', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
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

    await database.into(database.customers).insert(
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

    final ledgerEntries =
        await database.select(database.ledgerEntries).get();
    expect(ledgerEntries, isEmpty);
  });

  test('rejects payment recorded by an inactive user', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
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

    await database.into(database.customers).insert(
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

    final ledgerEntries =
        await database.select(database.ledgerEntries).get();
    expect(ledgerEntries, isEmpty);
  });

  test('rolls back when payment ID already exists', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
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

    await database.into(database.customers).insert(
          CustomersCompanion.insert(
            id: 'customer-1',
            businessId: 'business-1',
            name: 'Test Customer',
            openingBalanceMinor: Value(2000),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.payments).insert(
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

    expect(payments.length, 1);
    expect(payments.single.amountMinor, 1000);

    final ledgerEntries =
        await database.select(database.ledgerEntries).get();

    expect(ledgerEntries, isEmpty);
  });

  test('records a partial payment and leaves the remaining balance', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-2',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
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

    await database.into(database.customers).insert(
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

    final ledgerEntries =
        await database.select(database.ledgerEntries).get();

    expect(ledgerEntries, hasLength(1));
    expect(ledgerEntries.single.entryType, 'payment');
    expect(ledgerEntries.single.amountMinor, 1000);

    final remainingBalance =
        2000 - ledgerEntries.single.amountMinor;

    expect(remainingBalance, 1000);
  });

  test('rejects a payment greater than the outstanding balance', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-3',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
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

    await database.into(database.customers).insert(
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

    final ledgerEntries =
        await database.select(database.ledgerEntries).get();
    expect(ledgerEntries, isEmpty);
  });

  test('rejects a payment when the customer has no outstanding balance',
      () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-4',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
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

    await database.into(database.customers).insert(
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

    final ledgerEntries =
        await database.select(database.ledgerEntries).get();
    expect(ledgerEntries, isEmpty);
  });}

