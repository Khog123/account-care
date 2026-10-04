import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;

import 'package:desktop/core/database/app_database.dart';
import 'package:desktop/core/services/category_service.dart';

void main() {
  late AppDatabase database;
  late CategoryService categoryService;

  setUp(() {
    database = AppDatabase.test();
    categoryService = CategoryService(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates a category for a business', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final categoryId = await categoryService.createCategory(
      businessId: 'business-1',
      categoryId: 'category-1',
      name: 'Beverages',
    );

    expect(categoryId, 'category-1');

    final category = await (database.select(database.categories)
          ..where((category) => category.id.equals('category-1')))
        .getSingle();

    expect(category.businessId, 'business-1');
    expect(category.name, 'Beverages');
    expect(category.isActive, isTrue);
  });

  test('rejects an empty category name', () async {
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
      () => categoryService.createCategory(
        businessId: 'business-1',
        categoryId: 'category-1',
        name: '   ',
      ),
      throwsArgumentError,
    );

    final categories = await database.select(database.categories).get();

    expect(categories, isEmpty);
  });

  test('rejects a category for a nonexistent business', () async {
    expect(
      () => categoryService.createCategory(
        businessId: 'business-1',
        categoryId: 'category-1',
        name: 'Beverages',
      ),
      throwsA(isA<StateError>()),
    );

    final categories = await database.select(database.categories).get();

    expect(categories, isEmpty);
  });

  test('gets a category only within the requested business', () async {
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

    await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            id: 'category-1',
            businessId: 'business-2',
            name: 'Other Category',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final category = await categoryService.getCategoryById(
      businessId: 'business-1',
      categoryId: 'category-1',
    );

    expect(category, isNull);
  });

  test('updates category information', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            id: 'category-1',
            businessId: 'business-1',
            name: 'Old Category',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await categoryService.updateCategory(
      businessId: 'business-1',
      categoryId: 'category-1',
      name: 'New Category',
      isActive: false,
    );

    final category = await (database.select(database.categories)
          ..where((category) => category.id.equals('category-1')))
        .getSingle();

    expect(category.name, 'New Category');
    expect(category.isActive, isFalse);
  });

  test('does not update a category from another business', () async {
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

    await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            id: 'category-1',
            businessId: 'business-2',
            name: 'Original Category',
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(
      () => categoryService.updateCategory(
        businessId: 'business-1',
        categoryId: 'category-1',
        name: 'Changed Category',
        isActive: true,
      ),
      throwsA(isA<StateError>()),
    );

    final category = await (database.select(database.categories)
          ..where((category) => category.id.equals('category-1')))
        .getSingle();

    expect(category.name, 'Original Category');
  });
}