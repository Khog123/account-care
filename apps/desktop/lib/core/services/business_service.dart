import 'package:drift/drift.dart';

import '../database/app_database.dart';

class BusinessService {
  BusinessService(this._database);

  final AppDatabase _database;

  Future<String> createBusiness({
    required String businessId,
    required String name,
    String currencyCode = 'PKR',
  }) async {
    final trimmedName = name.trim();
    final trimmedCurrencyCode = currencyCode.trim().toUpperCase();

    if (trimmedName.isEmpty) {
      throw ArgumentError(
        'Business name cannot be empty.',
      );
    }

    if (trimmedCurrencyCode.isEmpty) {
      throw ArgumentError(
        'Currency code cannot be empty.',
      );
    }

    final now = DateTime.now();

    await _database.into(_database.businesses).insert(
          BusinessesCompanion.insert(
            id: businessId,
            name: trimmedName,
            currencyCode: Value(trimmedCurrencyCode),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return businessId;
  }

  Future<BusinessesData?> getBusinessById({
    required String businessId,
  }) {
    return (_database.select(_database.businesses)
          ..where(
            (business) => business.id.equals(businessId),
          ))
        .getSingleOrNull();
  }

  Future<void> updateBusiness({
    required String businessId,
    required String name,
    required String currencyCode,
    required bool isActive,
  }) async {
    final trimmedName = name.trim();
    final trimmedCurrencyCode = currencyCode.trim().toUpperCase();

    if (trimmedName.isEmpty) {
      throw ArgumentError(
        'Business name cannot be empty.',
      );
    }

    if (trimmedCurrencyCode.isEmpty) {
      throw ArgumentError(
        'Currency code cannot be empty.',
      );
    }

    final business = await (_database.select(_database.businesses)
          ..where(
            (business) => business.id.equals(businessId),
          ))
        .getSingleOrNull();

    if (business == null) {
      throw StateError(
        'Business not found: $businessId',
      );
    }

    await (_database.update(_database.businesses)
          ..where(
            (business) => business.id.equals(businessId),
          ))
        .write(
      BusinessesCompanion(
        name: Value(trimmedName),
        currencyCode: Value(trimmedCurrencyCode),
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}