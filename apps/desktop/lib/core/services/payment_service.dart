import 'package:drift/drift.dart';

import '../database/app_database.dart';

class PaymentService {
  PaymentService(this._database);

  final AppDatabase _database;

  Future<String> recordPayment({
    required String businessId,
    required String customerId,
    required String userId,
    required String paymentId,
    required int amountMinor,
    required String paymentMethod,
    required DateTime paidAt,
  }) async {
    if (amountMinor <= 0) {
      throw ArgumentError(
        'Payment amount must be greater than zero.',
      );
    }

    if (paymentMethod.trim().isEmpty) {
      throw ArgumentError(
        'Payment method cannot be empty.',
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

    if (!customer.isActive) {
      throw StateError(
        'Customer is inactive: ${customer.name}',
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

    if (!user.isActive) {
      throw StateError(
        'User is inactive: ${user.name}',
      );
    }

    return _database.transaction(() async {
      final now = DateTime.now();

      await _database.into(_database.payments).insert(
            PaymentsCompanion.insert(
              id: paymentId,
              businessId: businessId,
              customerId: Value(customerId),
              userId: userId,
              amountMinor: amountMinor,
              paymentMethod: paymentMethod,
              paidAt: paidAt,
              createdAt: now,
            ),
          );

      await _database.into(_database.ledgerEntries).insert(
            LedgerEntriesCompanion.insert(
              id: _generateId(),
              businessId: businessId,
              customerId: customerId,
              paymentId: Value(paymentId),
              entryType: 'payment',
              amountMinor: amountMinor,
              description: Value(
                'Customer payment',
              ),
              entryAt: paidAt,
              createdAt: now,
            ),
          );

      return paymentId;
    });
  }

  String _generateId() {
    return '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';
  }

  static int _idCounter = 0;
}