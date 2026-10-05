import 'package:drift/drift.dart';

import '../database/app_database.dart';

class UserService {
  UserService(this._database);

  final AppDatabase _database;

  Future<String> createUser({
    required String userId,
    required String businessId,
    required String name,
    required String username,
    required String passwordHash,
    required String role,
  }) async {
    final trimmedName = name.trim();
    final trimmedUsername = username.trim();
    final trimmedPasswordHash = passwordHash.trim();
    final trimmedRole = role.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError(
        'User name cannot be empty.',
      );
    }

    if (trimmedUsername.isEmpty) {
      throw ArgumentError(
        'Username cannot be empty.',
      );
    }

    if (trimmedPasswordHash.isEmpty) {
      throw ArgumentError(
        'Password hash cannot be empty.',
      );
    }

    if (trimmedRole.isEmpty) {
      throw ArgumentError(
        'Role cannot be empty.',
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

    await _database.into(_database.users).insert(
          UsersCompanion.insert(
            id: userId,
            businessId: businessId,
            name: trimmedName,
            username: trimmedUsername,
            passwordHash: trimmedPasswordHash,
            role: trimmedRole,
            createdAt: now,
            updatedAt: now,
          ),
        );

    return userId;
  }

  Future<List<User>> getUsers({
    required String businessId,
    bool activeOnly = false,
  }) {
    final query = _database.select(_database.users)
      ..where(
        (user) => user.businessId.equals(businessId),
      );

    if (activeOnly) {
      query.where(
        (user) => user.isActive.equals(true),
      );
    }

    query.orderBy([
      (user) => OrderingTerm(
            expression: user.name,
            mode: OrderingMode.asc,
          ),
    ]);

    return query.get();
  }

  Future<User?> getUserById({
    required String businessId,
    required String userId,
  }) {
    return (_database.select(_database.users)
          ..where(
            (user) =>
                user.id.equals(userId) &
                user.businessId.equals(businessId),
          ))
        .getSingleOrNull();
  }

  Future<void> updateUser({
    required String businessId,
    required String userId,
    required String name,
    required String username,
    required String role,
    required bool isActive,
  }) async {
    final trimmedName = name.trim();
    final trimmedUsername = username.trim();
    final trimmedRole = role.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError(
        'User name cannot be empty.',
      );
    }

    if (trimmedUsername.isEmpty) {
      throw ArgumentError(
        'Username cannot be empty.',
      );
    }

    if (trimmedRole.isEmpty) {
      throw ArgumentError(
        'Role cannot be empty.',
      );
    }

    final user = await (_database.select(_database.users)
          ..where(
            (user) =>
                user.id.equals(userId) &
                user.businessId.equals(businessId),
          ))
        .getSingleOrNull();

    if (user == null) {
      throw StateError(
        'User not found for this business: $userId',
      );
    }

    await (_database.update(_database.users)
          ..where(
            (user) =>
                user.id.equals(userId) &
                user.businessId.equals(businessId),
          ))
        .write(
      UsersCompanion(
        name: Value(trimmedName),
        username: Value(trimmedUsername),
        role: Value(trimmedRole),
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}