import 'package:flutter_test/flutter_test.dart';

import 'package:desktop/core/database/app_database.dart';
import 'package:desktop/core/services/user_service.dart';

void main() {
  late AppDatabase database;
  late UserService userService;

  setUp(() {
    database = AppDatabase.test();
    userService = UserService(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> insertBusiness({
    String businessId = 'business-1',
  }) async {
    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: businessId,
            name: 'Test Store',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  }

  test('creates a user for a business', () async {
    await insertBusiness();

    final userId = await userService.createUser(
      userId: 'user-1',
      businessId: 'business-1',
      name: 'Ali Khan',
      username: 'ali',
      passwordHash: 'hashed-password',
      role: 'owner',
    );

    expect(userId, 'user-1');

    final user = await (database.select(database.users)
          ..where((user) => user.id.equals('user-1')))
        .getSingle();

    expect(user.businessId, 'business-1');
    expect(user.name, 'Ali Khan');
    expect(user.username, 'ali');
    expect(user.passwordHash, 'hashed-password');
    expect(user.role, 'owner');
    expect(user.isActive, isTrue);
  });

  test('trims user name and username', () async {
    await insertBusiness();

    await userService.createUser(
      userId: 'user-1',
      businessId: 'business-1',
      name: '  Ali Khan  ',
      username: '  ali  ',
      passwordHash: 'hashed-password',
      role: 'owner',
    );

    final user = await (database.select(database.users)
          ..where((user) => user.id.equals('user-1')))
        .getSingle();

    expect(user.name, 'Ali Khan');
    expect(user.username, 'ali');
  });

  test('rejects an empty user name', () async {
    await insertBusiness();

    expect(
      () => userService.createUser(
        userId: 'user-1',
        businessId: 'business-1',
        name: '   ',
        username: 'ali',
        passwordHash: 'hashed-password',
        role: 'owner',
      ),
      throwsArgumentError,
    );
  });

  test('rejects an empty username', () async {
    await insertBusiness();

    expect(
      () => userService.createUser(
        userId: 'user-1',
        businessId: 'business-1',
        name: 'Ali Khan',
        username: '   ',
        passwordHash: 'hashed-password',
        role: 'owner',
      ),
      throwsArgumentError,
    );
  });

  test('rejects an empty password hash', () async {
    await insertBusiness();

    expect(
      () => userService.createUser(
        userId: 'user-1',
        businessId: 'business-1',
        name: 'Ali Khan',
        username: 'ali',
        passwordHash: '   ',
        role: 'owner',
      ),
      throwsArgumentError,
    );
  });

  test('rejects an empty role', () async {
    await insertBusiness();

    expect(
      () => userService.createUser(
        userId: 'user-1',
        businessId: 'business-1',
        name: 'Ali Khan',
        username: 'ali',
        passwordHash: 'hashed-password',
        role: '   ',
      ),
      throwsArgumentError,
    );
  });

  test('rejects a user for a nonexistent business', () async {
    expect(
      () => userService.createUser(
        userId: 'user-1',
        businessId: 'business-999',
        name: 'Ali Khan',
        username: 'ali',
        passwordHash: 'hashed-password',
        role: 'owner',
      ),
      throwsStateError,
    );
  });

  test('gets a user only within the requested business', () async {
    await insertBusiness(businessId: 'business-1');
    await insertBusiness(businessId: 'business-2');

    await database.into(database.users).insert(
          UsersCompanion.insert(
            id: 'user-1',
            businessId: 'business-1',
            name: 'Ali Khan',
            username: 'ali',
            passwordHash: 'hashed-password',
            role: 'owner',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    final user = await userService.getUserById(
      businessId: 'business-2',
      userId: 'user-1',
    );

    expect(user, isNull);
  });

  test('updates user information', () async {
    await insertBusiness();

    await database.into(database.users).insert(
          UsersCompanion.insert(
            id: 'user-1',
            businessId: 'business-1',
            name: 'Old Name',
            username: 'olduser',
            passwordHash: 'old-hash',
            role: 'clerk',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    await userService.updateUser(
      businessId: 'business-1',
      userId: 'user-1',
      name: 'Updated Name',
      username: 'updateduser',
      role: 'owner',
      isActive: false,
    );

    final user = await (database.select(database.users)
          ..where((user) => user.id.equals('user-1')))
        .getSingle();

    expect(user.name, 'Updated Name');
    expect(user.username, 'updateduser');
    expect(user.role, 'owner');
    expect(user.isActive, isFalse);
    expect(user.passwordHash, 'old-hash');
  });

  test('rejects updating a user from another business', () async {
    await insertBusiness(businessId: 'business-1');
    await insertBusiness(businessId: 'business-2');

    await database.into(database.users).insert(
          UsersCompanion.insert(
            id: 'user-1',
            businessId: 'business-1',
            name: 'Ali Khan',
            username: 'ali',
            passwordHash: 'hashed-password',
            role: 'owner',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    expect(
      () => userService.updateUser(
        businessId: 'business-2',
        userId: 'user-1',
        name: 'Changed',
        username: 'changed',
        role: 'clerk',
        isActive: true,
      ),
      throwsStateError,
    );
  });

  test('rejects updating a nonexistent user', () async {
    await insertBusiness();

    expect(
      () => userService.updateUser(
        businessId: 'business-1',
        userId: 'user-999',
        name: 'Updated Name',
        username: 'updateduser',
        role: 'owner',
        isActive: true,
      ),
      throwsStateError,
    );
  });

  test('rejects empty values when updating a user', () async {
    await insertBusiness();

    await database.into(database.users).insert(
          UsersCompanion.insert(
            id: 'user-1',
            businessId: 'business-1',
            name: 'Ali Khan',
            username: 'ali',
            passwordHash: 'hashed-password',
            role: 'owner',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    expect(
      () => userService.updateUser(
        businessId: 'business-1',
        userId: 'user-1',
        name: '   ',
        username: 'ali',
        role: 'owner',
        isActive: true,
      ),
      throwsArgumentError,
    );

    expect(
      () => userService.updateUser(
        businessId: 'business-1',
        userId: 'user-1',
        name: 'Ali Khan',
        username: '   ',
        role: 'owner',
        isActive: true,
      ),
      throwsArgumentError,
    );

    expect(
      () => userService.updateUser(
        businessId: 'business-1',
        userId: 'user-1',
        name: 'Ali Khan',
        username: 'ali',
        role: '   ',
        isActive: true,
      ),
      throwsArgumentError,
    );
  });
}
