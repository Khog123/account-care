import 'package:drift/drift.dart';

import '../app_database.dart';

class CategoryRepository {
  CategoryRepository(this._database);

  final AppDatabase _database;

  Future<List<Category>> getByBusinessId(String businessId) {
    return (_database.select(_database.categories)
          ..where((category) => category.businessId.equals(businessId)))
        .get();
  }

  Future<Category?> getById(String categoryId) {
    return (_database.select(_database.categories)
          ..where((category) => category.id.equals(categoryId)))
        .getSingleOrNull();
  }

  Future<void> create({
    required String id,
    required String businessId,
    required String name,
  }) async {
    final now = DateTime.now();

    await _database.into(_database.categories).insert(
          CategoriesCompanion.insert(
            id: id,
            businessId: businessId,
            name: name,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> update({
    required String categoryId,
    required String name,
    required bool isActive,
  }) async {
    await (_database.update(_database.categories)
          ..where((category) => category.id.equals(categoryId)))
        .write(
      CategoriesCompanion(
        name: Value(name),
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}