import 'package:drift/drift.dart';

import '../database/app_database.dart';

class CategoryService {
  CategoryService(this._database);

  final AppDatabase _database;

  Future<String> createCategory({
    required String businessId,
    required String categoryId,
    required String name,
  }) async {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError(
        'Category name cannot be empty.',
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

    final now = DateTime.now();

    await _database.into(_database.categories).insert(
          CategoriesCompanion.insert(
            id: categoryId,
            businessId: businessId,
            name: trimmedName,
            createdAt: now,
            updatedAt: now,
          ),
        );

    return categoryId;
  }

  Future<List<Category>> getCategories({
    required String businessId,
    bool activeOnly = false,
  }) {
    final query = _database.select(_database.categories)
      ..where(
        (category) => category.businessId.equals(businessId),
      );

    if (activeOnly) {
      query.where(
        (category) => category.isActive.equals(true),
      );
    }

    query.orderBy([
      (category) => OrderingTerm(
            expression: category.name,
            mode: OrderingMode.asc,
          ),
    ]);

    return query.get();
  }

  Future<Category?> getCategoryById({
    required String businessId,
    required String categoryId,
  }) {
    return (_database.select(_database.categories)
          ..where(
            (category) =>
                category.id.equals(categoryId) &
                category.businessId.equals(businessId),
          ))
        .getSingleOrNull();
  }

  Future<void> updateCategory({
    required String businessId,
    required String categoryId,
    required String name,
    required bool isActive,
  }) async {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError(
        'Category name cannot be empty.',
      );
    }

    final category = await (_database.select(_database.categories)
          ..where(
            (category) =>
                category.id.equals(categoryId) &
                category.businessId.equals(businessId),
          ))
        .getSingleOrNull();

    if (category == null) {
      throw StateError(
        'Category not found for this business: $categoryId',
      );
    }

    await (_database.update(_database.categories)
          ..where(
            (category) =>
                category.id.equals(categoryId) &
                category.businessId.equals(businessId),
          ))
        .write(
      CategoriesCompanion(
        name: Value(trimmedName),
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}