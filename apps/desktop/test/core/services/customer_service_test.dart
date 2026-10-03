import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;

import 'package:desktop/core/database/app_database.dart';
import 'package:desktop/core/services/customer_service.dart';

void main() {
  late AppDatabase database;
  late CustomerService customerService;

  setUp(() {
    database = AppDatabase.test();
    customerService = CustomerService(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates a customer for a business', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final customerId = await customerService.createCustomer(
      businessId: 'business-1',
      customerId: 'customer-1',
      name: 'Ali Khan',
      phone: '03001234567',
      address: 'Mingora',
      openingBalanceMinor: 5000,
    );

    expect(customerId, 'customer-1');

    final customer = await (database.select(database.customers)
          ..where((customer) => customer.id.equals('customer-1')))
        .getSingle();

    expect(customer.businessId, 'business-1');
    expect(customer.name, 'Ali Khan');
    expect(customer.phone, '03001234567');
    expect(customer.address, 'Mingora');
    expect(customer.openingBalanceMinor, 5000);
    expect(customer.isActive, isTrue);
  });

  test('rejects an empty customer name', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(
      () => customerService.createCustomer(
        businessId: 'business-1',
        customerId: 'customer-1',
        name: '   ',
      ),
      throwsArgumentError,
    );

    final customers = await database.select(database.customers).get();

    expect(customers, isEmpty);
  });

  test('rejects a negative opening balance', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(
      () => customerService.createCustomer(
        businessId: 'business-1',
        customerId: 'customer-1',
        name: 'Ali Khan',
        openingBalanceMinor: -1000,
      ),
      throwsArgumentError,
    );

    final customers = await database.select(database.customers).get();

    expect(customers, isEmpty);
  });

  test('rejects a customer for a nonexistent business', () async {
    expect(
      () => customerService.createCustomer(
        businessId: 'business-1',
        customerId: 'customer-1',
        name: 'Ali Khan',
      ),
      throwsA(isA<StateError>()),
    );

    final customers = await database.select(database.customers).get();

    expect(customers, isEmpty);
  });

  test('gets a customer only within the requested business', () async {
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
            businessId: 'business-2',
            name: 'Other Customer',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final customer = await customerService.getCustomerById(
      businessId: 'business-1',
      customerId: 'customer-1',
    );

    expect(customer, isNull);
  });

  test('updates customer information', () async {
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
            name: 'Old Name',
            phone: const Value('03000000000'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await customerService.updateCustomer(
      businessId: 'business-1',
      customerId: 'customer-1',
      name: 'New Name',
      phone: '03111111111',
      address: 'Swat',
      isActive: true,
    );

    final customer = await (database.select(database.customers)
          ..where((customer) => customer.id.equals('customer-1')))
        .getSingle();

    expect(customer.name, 'New Name');
    expect(customer.phone, '03111111111');
    expect(customer.address, 'Swat');
    expect(customer.isActive, isTrue);
  });

  test('does not update a customer from another business', () async {
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
            businessId: 'business-2',
            name: 'Original Name',
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(
      () => customerService.updateCustomer(
        businessId: 'business-1',
        customerId: 'customer-1',
        name: 'Changed Name',
        isActive: true,
      ),
      throwsA(isA<StateError>()),
    );

    final customer = await (database.select(database.customers)
          ..where((customer) => customer.id.equals('customer-1')))
        .getSingle();

    expect(customer.name, 'Original Name');
  });
}