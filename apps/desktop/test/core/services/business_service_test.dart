import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;

import 'package:desktop/core/database/app_database.dart';
import 'package:desktop/core/services/business_service.dart';

void main() {
  late AppDatabase database;
  late BusinessService businessService;

  setUp(() {
    database = AppDatabase.test();
    businessService = BusinessService(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates a business', () async {
    final businessId = await businessService.createBusiness(
      businessId: 'business-1',
      name: 'Test Store',
    );

    expect(businessId, 'business-1');

    final business = await (database.select(database.businesses)
          ..where((business) => business.id.equals('business-1')))
        .getSingle();

    expect(business.name, 'Test Store');
    expect(business.currencyCode, 'PKR');
    expect(business.isActive, isTrue);
  });

  test('rejects an empty business name', () async {
    expect(
      () => businessService.createBusiness(
        businessId: 'business-1',
        name: '   ',
      ),
      throwsArgumentError,
    );
  });

  test('rejects a duplicate business ID', () async {
    await businessService.createBusiness(
      businessId: 'business-1',
      name: 'First Store',
    );

    expect(
      () => businessService.createBusiness(
        businessId: 'business-1',
        name: 'Second Store',
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('gets a business by ID', () async {
    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Store',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    final business = await businessService.getBusinessById(
      businessId: 'business-1',
    );

    expect(business, isNotNull);
    expect(business!.name, 'Test Store');
  });

  test('returns null when business does not exist', () async {
    final business = await businessService.getBusinessById(
      businessId: 'business-999',
    );

    expect(business, isNull);
  });

  test('updates business information', () async {
    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Old Store',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    await businessService.updateBusiness(
      businessId: 'business-1',
      name: 'Updated Store',
      currencyCode: 'PKR',
      isActive: true,
    );

    final business = await (database.select(database.businesses)
          ..where((business) => business.id.equals('business-1')))
        .getSingle();

    expect(business.name, 'Updated Store');
    expect(business.currencyCode, 'PKR');
    expect(business.isActive, isTrue);
  });

  test('rejects updating a nonexistent business', () async {
    expect(
      () => businessService.updateBusiness(
        businessId: 'business-999',
        name: 'Updated Store',
        currencyCode: 'PKR',
        isActive: true,
      ),
      throwsStateError,
    );
  });

  test('rejects an empty currency code', () async {
    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Store',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    expect(
      () => businessService.updateBusiness(
        businessId: 'business-1',
        name: 'Test Store',
        currencyCode: '   ',
        isActive: true,
      ),
      throwsArgumentError,
    );
  });
}