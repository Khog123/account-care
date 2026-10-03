import 'package:drift/drift.dart';

import '../app_database.dart';

class BusinessRepository {
  BusinessRepository(this._database);

  final AppDatabase _database;

  Future<List<BusinessesData>> getAll() {
    return _database.select(_database.businesses).get();
  }

  Future<BusinessesData?> getById(String businessId) {
    return (_database.select(_database.businesses)
          ..where((business) => business.id.equals(businessId)))
        .getSingleOrNull();
  }

  Future<void> create({
    required String id,
    required String name,
    String currencyCode = 'PKR',
  }) async {
    final now = DateTime.now();

    await _database.into(_database.businesses).insert(
          BusinessesCompanion.insert(
            id: id,
            name: name,
            currencyCode: Value(currencyCode),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> update({
    required String businessId,
    required String name,
    required String currencyCode,
    required bool isActive,
  }) async {
    await (_database.update(_database.businesses)
          ..where((business) => business.id.equals(businessId)))
        .write(
      BusinessesCompanion(
        name: Value(name),
        currencyCode: Value(currencyCode),
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}