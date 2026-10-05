import 'package:drift/drift.dart';

import '../database/app_database.dart';

class CustomerService {
  CustomerService(this._database);

  final AppDatabase _database;

  Future<String> createCustomer({
    required String businessId,
    required String customerId,
    required String name,
    String? phone,
    String? address,
    int openingBalanceMinor = 0,
  }) async {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError(
        'Customer name cannot be empty.',
      );
    }

    if (openingBalanceMinor < 0) {
      throw ArgumentError(
        'Opening balance cannot be negative.',
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

    await _database.into(_database.customers).insert(
          CustomersCompanion.insert(
            id: customerId,
            businessId: businessId,
            name: trimmedName,
            phone: Value(phone),
            address: Value(address),
            openingBalanceMinor: Value(openingBalanceMinor),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return customerId;
  }

  Future<List<Customer>> getCustomers({
    required String businessId,
    bool activeOnly = false,
  }) {
    final query = _database.select(_database.customers)
      ..where(
        (customer) => customer.businessId.equals(businessId),
      );

    if (activeOnly) {
      query.where(
        (customer) => customer.isActive.equals(true),
      );
    }

    query.orderBy([
      (customer) => OrderingTerm(
            expression: customer.name,
            mode: OrderingMode.asc,
          ),
    ]);

    return query.get();
  }

  Future<Customer?> getCustomerById({
    required String businessId,
    required String customerId,
  }) {
    return (_database.select(_database.customers)
          ..where(
            (customer) =>
                customer.id.equals(customerId) &
                customer.businessId.equals(businessId),
          ))
        .getSingleOrNull();
  }

  Future<void> updateCustomer({
    required String businessId,
    required String customerId,
    required String name,
    String? phone,
    String? address,
    required bool isActive,
  }) async {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError(
        'Customer name cannot be empty.',
      );
    }

    final customer = await (_database.select(_database.customers)
          ..where(
            (customer) =>
                customer.id.equals(customerId) &
                customer.businessId.equals(businessId),
          ))
        .getSingleOrNull();

    if (customer == null) {
      throw StateError(
        'Customer not found for this business: $customerId',
      );
    }

    await (_database.update(_database.customers)
          ..where(
            (customer) =>
                customer.id.equals(customerId) &
                customer.businessId.equals(businessId),
          ))
        .write(
      CustomersCompanion(
        name: Value(trimmedName),
        phone: Value(phone),
        address: Value(address),
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}