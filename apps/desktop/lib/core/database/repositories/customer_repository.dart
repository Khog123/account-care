import 'package:drift/drift.dart';

import '../app_database.dart';

class CustomerRepository {
  CustomerRepository(this._database);

  final AppDatabase _database;

  Future<List<Customer>> getByBusinessId(String businessId) {
    return (_database.select(_database.customers)
          ..where((customer) => customer.businessId.equals(businessId)))
        .get();
  }

  Future<Customer?> getById(String customerId) {
    return (_database.select(_database.customers)
          ..where((customer) => customer.id.equals(customerId)))
        .getSingleOrNull();
  }

  Future<List<Customer>> search({
    required String businessId,
    required String query,
  }) {
    final pattern = '%$query%';

    return (_database.select(_database.customers)
          ..where(
            (customer) =>
                customer.businessId.equals(businessId) &
                (customer.name.like(pattern) |
                    customer.phone.like(pattern)),
          ))
        .get();
  }

  Future<void> create({
    required String id,
    required String businessId,
    required String name,
    String? phone,
    String? address,
    int openingBalanceMinor = 0,
  }) async {
    final now = DateTime.now();

    await _database.into(_database.customers).insert(
          CustomersCompanion.insert(
            id: id,
            businessId: businessId,
            name: name,
            phone: Value(phone),
            address: Value(address),
            openingBalanceMinor: Value(openingBalanceMinor),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> update({
    required String customerId,
    required String name,
    String? phone,
    String? address,
    required bool isActive,
  }) async {
    await (_database.update(_database.customers)
          ..where((customer) => customer.id.equals(customerId)))
        .write(
      CustomersCompanion(
        name: Value(name),
        phone: Value(phone),
        address: Value(address),
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}