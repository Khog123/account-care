import 'package:flutter_test/flutter_test.dart';

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
}