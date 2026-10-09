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
    String? reference,
    required DateTime paidAt,
  }) async {
    if (businessId.trim().isEmpty ||
        customerId.trim().isEmpty ||
        userId.trim().isEmpty ||
        paymentId.trim().isEmpty) {
      throw ArgumentError(
        'Business, customer, user, and payment IDs '
        'cannot be empty.',
      );
    }

    if (amountMinor <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }

    final trimmedPaymentMethod = paymentMethod.trim();

    if (trimmedPaymentMethod.isEmpty) {
      throw ArgumentError('Payment method cannot be empty.');
    }

    final trimmedReference = reference?.trim();
    final normalizedReference =
        trimmedReference == null || trimmedReference.isEmpty
        ? null
        : trimmedReference;

    return _database.transaction(() async {
      final customer =
          await (_database.select(_database.customers)..where(
                (row) =>
                    row.id.equals(customerId) &
                    row.businessId.equals(businessId),
              ))
              .getSingleOrNull();

      if (customer == null) {
        throw StateError('Customer not found for this business: $customerId');
      }

      if (!customer.isActive) {
        throw StateError('Customer is inactive: ${customer.name}');
      }

      final user =
          await (_database.select(_database.users)..where(
                (row) =>
                    row.id.equals(userId) & row.businessId.equals(businessId),
              ))
              .getSingleOrNull();

      if (user == null) {
        throw StateError('User not found for this business: $userId');
      }

      if (!user.isActive) {
        throw StateError('User is inactive: ${user.name}');
      }

      // Calculate the customer's balance using the ledger, not just
      // the sum of invoice dues. This preserves opening-balance support.
      final ledgerEntries =
          await (_database.select(_database.ledgerEntries)..where(
                (entry) =>
                    entry.businessId.equals(businessId) &
                    entry.customerId.equals(customerId),
              ))
              .get();

      var outstandingBalanceMinor = customer.openingBalanceMinor;

      for (final entry in ledgerEntries) {
        switch (entry.entryType) {
          case 'sale_credit':
            outstandingBalanceMinor += entry.amountMinor;
            break;
          case 'payment':
            outstandingBalanceMinor -= entry.amountMinor;
            break;
        }
      }

      if (outstandingBalanceMinor <= 0) {
        throw StateError('Customer has no outstanding balance.');
      }

      if (amountMinor > outstandingBalanceMinor) {
        throw ArgumentError(
          'Payment cannot exceed the customer outstanding balance.',
        );
      }

      // Repair allocations for older customer payments recorded before
      // invoice allocation was introduced. A historical payment can only
      // be allocated to invoices sold on or before its payment date.
      await _allocateLegacyPayments(
        businessId: businessId,
        customerId: customerId,
      );

      final now = DateTime.now();

      // Insert the payment within the same transaction as its allocations,
      // invoice updates, and ledger entry.
      await _database
          .into(_database.payments)
          .insert(
            PaymentsCompanion.insert(
              id: paymentId,
              businessId: businessId,
              customerId: Value(customerId),
              userId: userId,
              amountMinor: amountMinor,
              paymentMethod: trimmedPaymentMethod,
              reference: Value(normalizedReference),
              paidAt: paidAt,
              createdAt: now,
            ),
          );

      await _allocateToInvoices(
        businessId: businessId,
        customerId: customerId,
        paymentId: paymentId,
        amountMinor: amountMinor,
        paidAt: paidAt,
        createdAt: now,
      );

      await _database
          .into(_database.ledgerEntries)
          .insert(
            LedgerEntriesCompanion.insert(
              id: _generateId(),
              businessId: businessId,
              customerId: customerId,
              paymentId: Value(paymentId),
              entryType: 'payment',
              amountMinor: amountMinor,
              description: const Value('Customer payment'),
              entryAt: paidAt,
              createdAt: now,
            ),
          );

      return paymentId;
    });
  }

  Future<void> _allocateLegacyPayments({
    required String businessId,
    required String customerId,
  }) async {
    final legacyPayments =
        await (_database.select(_database.payments)
              ..where(
                (payment) =>
                    payment.businessId.equals(businessId) &
                    payment.customerId.equals(customerId) &
                    payment.saleId.isNull(),
              )
              ..orderBy([
                (payment) => OrderingTerm.asc(payment.paidAt),
                (payment) => OrderingTerm.asc(payment.createdAt),
                (payment) => OrderingTerm.asc(payment.id),
              ]))
            .get();

    for (final payment in legacyPayments) {
      final existingAllocations =
          await (_database.select(_database.paymentAllocations)..where(
                (allocation) =>
                    allocation.businessId.equals(businessId) &
                    allocation.paymentId.equals(payment.id),
              ))
              .get();

      if (existingAllocations.isNotEmpty) {
        continue;
      }

      await _allocateToInvoices(
        businessId: businessId,
        customerId: customerId,
        paymentId: payment.id,
        amountMinor: payment.amountMinor,
        paidAt: payment.paidAt,
        createdAt: DateTime.now(),
      );
    }
  }

  Future<void> _allocateToInvoices({
    required String businessId,
    required String customerId,
    required String paymentId,
    required int amountMinor,
    required DateTime paidAt,
    required DateTime createdAt,
  }) async {
    final invoices =
        await (_database.select(_database.sales)
              ..where(
                (sale) =>
                    sale.businessId.equals(businessId) &
                    sale.customerId.equals(customerId) &
                    sale.status.equals('completed') &
                    sale.dueMinor.isBiggerThanValue(0) &
                    sale.soldAt.isSmallerOrEqualValue(paidAt),
              )
              ..orderBy([
                (sale) => OrderingTerm.asc(sale.soldAt),
                (sale) => OrderingTerm.asc(sale.createdAt),
                (sale) => OrderingTerm.asc(sale.id),
              ]))
            .get();

    var remainingMinor = amountMinor;

    for (final invoice in invoices) {
      if (remainingMinor <= 0) {
        break;
      }

      final allocatedMinor = remainingMinor < invoice.dueMinor
          ? remainingMinor
          : invoice.dueMinor;

      if (allocatedMinor <= 0) {
        continue;
      }

      await _database
          .into(_database.paymentAllocations)
          .insert(
            PaymentAllocationsCompanion.insert(
              id: _generateId(),
              businessId: businessId,
              paymentId: paymentId,
              saleId: invoice.id,
              amountMinor: allocatedMinor,
              allocatedAt: paidAt,
              createdAt: createdAt,
            ),
          );

      await (_database.update(_database.sales)..where(
            (sale) =>
                sale.id.equals(invoice.id) & sale.businessId.equals(businessId),
          ))
          .write(
            SalesCompanion(
              paidMinor: Value(invoice.paidMinor + allocatedMinor),
              dueMinor: Value(invoice.dueMinor - allocatedMinor),
            ),
          );

      remainingMinor -= allocatedMinor;
    }

    // Any remainder applies to the customer's opening balance. It is
    // represented by the payment ledger entry; it must not make an
    // invoice's due balance negative.
  }

  String _generateId() {
    return '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';
  }

  static int _idCounter = 0;
}
