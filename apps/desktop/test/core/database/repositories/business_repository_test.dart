import 'package:flutter_test/flutter_test.dart';
import 'package:desktop/core/database/app_database.dart';
import 'package:desktop/core/database/repositories/business_repository.dart';

void main() {
  late AppDatabase database;
  late BusinessRepository repository;

  setUp(() {
    database = AppDatabase.test();
    repository = BusinessRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates and retrieves a business', () async {
    await repository.create(
      id: 'business-1',
      name: 'Test Store',
    );

    final business = await repository.getById('business-1');

    expect(business, isNotNull);
    expect(business!.id, 'business-1');
    expect(business.name, 'Test Store');
    expect(business.currencyCode, 'PKR');
    expect(business.isActive, isTrue);
  });

  test('returns null for a business that does not exist', () async {
    final business = await repository.getById('missing-business');

    expect(business, isNull);
  });

  test('updates a business', () async {
    await repository.create(
      id: 'business-2',
      name: 'Original Store',
    );

    await repository.update(
      businessId: 'business-2',
      name: 'Updated Store',
      currencyCode: 'USD',
      isActive: false,
    );

    final business = await repository.getById('business-2');

    expect(business, isNotNull);
    expect(business!.name, 'Updated Store');
    expect(business.currencyCode, 'USD');
    expect(business.isActive, isFalse);
  });

  test('gets all businesses', () async {
    await repository.create(
      id: 'business-3',
      name: 'Store A',
    );

    await repository.create(
      id: 'business-4',
      name: 'Store B',
    );

    final businesses = await repository.getAll();

    expect(businesses, hasLength(2));
  });
}