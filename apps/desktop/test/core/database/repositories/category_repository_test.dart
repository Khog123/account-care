import 'package:flutter_test/flutter_test.dart';
import 'package:desktop/core/database/app_database.dart';
import 'package:desktop/core/database/repositories/category_repository.dart';

void main() {
  late AppDatabase database;
  late CategoryRepository repository;

  setUp(() {
    database = AppDatabase.test();
    repository = CategoryRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates and retrieves a category', () async {
    await repository.create(
      id: 'category-1',
      businessId: 'business-1',
      name: 'Beverages',
    );

    final category = await repository.getById('category-1');

    expect(category, isNotNull);
    expect(category!.id, 'category-1');
    expect(category.businessId, 'business-1');
    expect(category.name, 'Beverages');
    expect(category.isActive, isTrue);
  });

  test('retrieves only categories belonging to the requested business',
      () async {
    await repository.create(
      id: 'category-1',
      businessId: 'business-1',
      name: 'Beverages',
    );

    await repository.create(
      id: 'category-2',
      businessId: 'business-2',
      name: 'Snacks',
    );

    final categories =
        await repository.getByBusinessId('business-1');

    expect(categories, hasLength(1));
    expect(categories.first.id, 'category-1');
  });

  test('returns null when category does not exist', () async {
    final category = await repository.getById('missing-category');

    expect(category, isNull);
  });

  test('updates category details', () async {
    await repository.create(
      id: 'category-3',
      businessId: 'business-1',
      name: 'Old Name',
    );

    await repository.update(
      categoryId: 'category-3',
      name: 'Updated Name',
      isActive: false,
    );

    final category = await repository.getById('category-3');

    expect(category, isNotNull);
    expect(category!.name, 'Updated Name');
    expect(category.isActive, isFalse);
  });
}