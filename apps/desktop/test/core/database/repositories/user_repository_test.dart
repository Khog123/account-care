import 'package:flutter_test/flutter_test.dart';
import 'package:desktop/core/database/app_database.dart';
import 'package:desktop/core/database/repositories/user_repository.dart';

void main() {
  late AppDatabase database;
  late UserRepository repository;

  setUp(() {
    database = AppDatabase.test();
    repository = UserRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates and retrieves a user by ID', () async {
    await repository.create(
      id: 'user-1',
      businessId: 'business-1',
      name: 'Ali',
      username: 'ali',
      passwordHash: 'test-hash',
      role: 'clerk',
    );

    final user = await repository.getById('user-1');

    expect(user, isNotNull);
    expect(user!.id, 'user-1');
    expect(user.businessId, 'business-1');
    expect(user.name, 'Ali');
    expect(user.username, 'ali');
    expect(user.role, 'clerk');
    expect(user.isActive, isTrue);
  });

  test('retrieves users only for the requested business', () async {
    await repository.create(
      id: 'user-1',
      businessId: 'business-1',
      name: 'Ali',
      username: 'ali',
      passwordHash: 'hash-1',
      role: 'clerk',
    );

    await repository.create(
      id: 'user-2',
      businessId: 'business-2',
      name: 'Ahmed',
      username: 'ahmed',
      passwordHash: 'hash-2',
      role: 'clerk',
    );

    final businessOneUsers =
        await repository.getByBusinessId('business-1');

    expect(businessOneUsers, hasLength(1));
    expect(businessOneUsers.first.id, 'user-1');
  });

  test('username lookup is scoped to the business', () async {
    await repository.create(
      id: 'user-1',
      businessId: 'business-1',
      name: 'Ali',
      username: 'admin',
      passwordHash: 'hash-1',
      role: 'master',
    );

    await repository.create(
      id: 'user-2',
      businessId: 'business-2',
      name: 'Ahmed',
      username: 'admin',
      passwordHash: 'hash-2',
      role: 'master',
    );

    final user =
        await repository.getByUsername(
          businessId: 'business-2',
          username: 'admin',
        );

    expect(user, isNotNull);
    expect(user!.id, 'user-2');
    expect(user.businessId, 'business-2');
  });

  test('returns null when user does not exist', () async {
    final user = await repository.getById('missing-user');

    expect(user, isNull);
  });

  test('updates user details', () async {
    await repository.create(
      id: 'user-3',
      businessId: 'business-1',
      name: 'Original Name',
      username: 'original',
      passwordHash: 'hash',
      role: 'clerk',
    );

    await repository.update(
      userId: 'user-3',
      name: 'Updated Name',
      role: 'master',
      isActive: false,
    );

    final user = await repository.getById('user-3');

    expect(user, isNotNull);
    expect(user!.name, 'Updated Name');
    expect(user.role, 'master');
    expect(user.isActive, isFalse);
  });
}