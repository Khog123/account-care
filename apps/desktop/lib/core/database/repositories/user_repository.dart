import 'package:drift/drift.dart';

import '../app_database.dart';

class UserRepository {
  UserRepository(this._database);

  final AppDatabase _database;

  Future<List<User>> getByBusinessId(String businessId) {
    return (_database.select(_database.users)
          ..where((user) => user.businessId.equals(businessId)))
        .get();
  }

  Future<User?> getById(String userId) {
    return (_database.select(_database.users)
          ..where((user) => user.id.equals(userId)))
        .getSingleOrNull();
  }

  Future<User?> getByUsername({
    required String businessId,
    required String username,
  }) {
    return (_database.select(_database.users)
          ..where(
            (user) =>
                user.businessId.equals(businessId) &
                user.username.equals(username),
          ))
        .getSingleOrNull();
  }

  Future<void> create({
    required String id,
    required String businessId,
    required String name,
    required String username,
    required String passwordHash,
    required String role,
  }) async {
    final now = DateTime.now();

    await _database.into(_database.users).insert(
          UsersCompanion.insert(
            id: id,
            businessId: businessId,
            name: name,
            username: username,
            passwordHash: passwordHash,
            role: role,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> update({
    required String userId,
    required String name,
    required String role,
    required bool isActive,
  }) async {
    await (_database.update(_database.users)
          ..where((user) => user.id.equals(userId)))
        .write(
      UsersCompanion(
        name: Value(name),
        role: Value(role),
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}