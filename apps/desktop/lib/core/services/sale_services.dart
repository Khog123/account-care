import 'package:drift/drift.dart';

import '../database/app_database.dart';

class SaleService {
  SaleService(this._database);

  final AppDatabase _database;

  Future<String> completeSale({
    required String businessId,
    required String userId,
    required String saleId,
    required String invoiceNumber,
    required List<SaleItemRequest> items,
    String? customerId,
    int discountMinor = 0,
    int paidMinor = 0,
    required String status,
    required DateTime soldAt,
  }) async {
    final trimmedBusinessId = businessId.trim();
    final trimmedUserId = userId.trim();
    final trimmedSaleId = saleId.trim();
    final trimmedInvoiceNumber = invoiceNumber.trim();
    final trimmedCustomerId = customerId?.trim();
    final trimmedStatus = status.trim().toLowerCase();

    if (trimmedBusinessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty.');
    }

    if (trimmedUserId.isEmpty) {
      throw ArgumentError('User ID cannot be empty.');
    }

    if (trimmedSaleId.isEmpty) {
      throw ArgumentError('Sale ID cannot be empty.');
    }

    if (trimmedInvoiceNumber.isEmpty) {
      throw ArgumentError('Invoice number cannot be empty.');
    }

    if (discountMinor < 0) {
      throw ArgumentError('Discount cannot be negative.');
    }

    if (paidMinor < 0) {
      throw ArgumentError('Paid amount cannot be negative.');
    }

    if (trimmedStatus != 'completed') {
      throw ArgumentError(
        'A completed sale must have status "completed".',
      );
    }

    if (trimmedCustomerId != null &&
        trimmedCustomerId.isEmpty) {
      throw ArgumentError(
        'Customer ID cannot be empty.',
      );
    }

    final business = await (_database.select(_database.businesses)
          ..where(
            (business) =>
                business.id.equals(trimmedBusinessId),
          ))
        .getSingleOrNull();

    if (business == null) {
      throw StateError(
        'Business not found: $trimmedBusinessId',
      );
    }

    if (!business.isActive) {
      throw StateError(
        'Business is inactive: $trimmedBusinessId',
      );
    }

    final user = await (_database.select(_database.users)
          ..where(
            (user) =>
                user.id.equals(trimmedUserId) &
                user.businessId.equals(trimmedBusinessId),
          ))
        .getSingleOrNull();

    if (user == null) {
      throw StateError(
        'User not found for this business: $trimmedUserId',
      );
    }

    if (!user.isActive) {
      throw StateError(
        'User is inactive: ${user.name}',
      );
    }

    if (trimmedCustomerId != null) {
      final customer = await (_database.select(
        _database.customers,
      )
            ..where(
              (customer) =>
                  customer.id.equals(trimmedCustomerId) &
                  customer.businessId.equals(
                    trimmedBusinessId,
                  ),
            ))
          .getSingleOrNull();

      if (customer == null) {
        throw StateError(
          'Customer not found for this business: '
          '$trimmedCustomerId',
        );
      }

      if (!customer.isActive) {
        throw StateError(
          'Customer is inactive: ${customer.name}',
        );
      }
    }

    final existingSale = await (_database.select(_database.sales)
          ..where(
            (sale) =>
                sale.businessId.equals(trimmedBusinessId) &
                sale.id.equals(trimmedSaleId),
          ))
        .getSingleOrNull();

    if (existingSale != null) {
      throw StateError(
        'Sale already exists: $trimmedSaleId',
      );
    }

    final existingInvoice =
        await (_database.select(_database.sales)
              ..where(
                (sale) =>
                    sale.businessId.equals(
                      trimmedBusinessId,
                    ) &
                    sale.invoiceNumber.equals(
                      trimmedInvoiceNumber,
                    ),
              ))
            .getSingleOrNull();

    if (existingInvoice != null) {
      throw StateError(
        'Invoice number already exists: '
        '$trimmedInvoiceNumber',
      );
    }

    await validateSaleItems(
      businessId: trimmedBusinessId,
      items: items,
    );

    return _database.transaction(() async {
      var subtotalMinor = 0;

      final saleItems = <SaleItemInsert>[];

      for (final item in items) {
        final product = await (_database.select(
          _database.products,
        )
              ..where(
                (product) =>
                    product.id.equals(item.productId) &
                    product.businessId.equals(
                      trimmedBusinessId,
                    ),
              ))
            .getSingleOrNull();

        if (product == null) {
          throw StateError(
            'Product not found for this business: '
            '${item.productId}',
          );
        }

        final lineSubtotal =
            product.salePriceMinor * item.quantity;

        if (item.discountMinor < 0 ||
            item.discountMinor > lineSubtotal) {
          throw ArgumentError(
            'Invalid discount for product: ${product.name}',
          );
        }

        final lineTotal =
            lineSubtotal - item.discountMinor;

        subtotalMinor += lineTotal;

        saleItems.add(
          SaleItemInsert(
            id: _generateId(),
            productId: product.id,
            productName: product.name,
            quantity: item.quantity,
            unitPriceMinor: product.salePriceMinor,
            purchasePriceMinor:
                product.purchasePriceMinor,
            discountMinor: item.discountMinor,
            lineTotalMinor: lineTotal,
          ),
        );
      }

      if (discountMinor > subtotalMinor) {
        throw ArgumentError(
          'Sale discount cannot exceed the subtotal.',
        );
      }

      final totalMinor =
          subtotalMinor - discountMinor;

      if (paidMinor > totalMinor) {
        throw ArgumentError(
          'Paid amount cannot exceed the sale total.',
        );
      }

      final dueMinor =
          totalMinor - paidMinor;

      if (dueMinor > 0 &&
          trimmedCustomerId == null) {
        throw StateError(
          'A sale with an outstanding balance '
          'requires a customer.',
        );
      }

      final now = DateTime.now();

      await _database.into(_database.sales).insert(
            SalesCompanion.insert(
              id: trimmedSaleId,
              businessId: trimmedBusinessId,
              customerId: Value(trimmedCustomerId),
              userId: trimmedUserId,
              invoiceNumber: trimmedInvoiceNumber,
              subtotalMinor: subtotalMinor,
              discountMinor: Value(discountMinor),
              totalMinor: totalMinor,
              paidMinor: Value(paidMinor),
              dueMinor: Value(dueMinor),
              status: trimmedStatus,
              soldAt: soldAt,
              createdAt: now,
            ),
          );

      for (final item in saleItems) {
        await _database.into(_database.saleItems).insert(
              SaleItemsCompanion.insert(
                id: item.id,
                saleId: trimmedSaleId,
                productId: item.productId,
                productName: item.productName,
                quantity: item.quantity,
                unitPriceMinor: item.unitPriceMinor,
                purchasePriceMinor: Value(
                    item.purchasePriceMinor,
                  ),
                discountMinor: Value(
                  item.discountMinor,
                ),
                lineTotalMinor: item.lineTotalMinor,
              ),
            );

        final product = await (_database.select(
          _database.products,
        )
              ..where(
                (product) =>
                    product.id.equals(item.productId) &
                    product.businessId.equals(
                      trimmedBusinessId,
                    ),
              ))
            .getSingle();

        final quantityBefore =
            product.stockQuantity;

        final quantityAfter =
            quantityBefore - item.quantity;

        if (quantityAfter < 0) {
          throw StateError(
            'Insufficient stock for product: '
            '${product.name}',
          );
        }

        await (_database.update(_database.products)
              ..where(
                (product) =>
                    product.id.equals(item.productId) &
                    product.businessId.equals(
                      trimmedBusinessId,
                    ),
              ))
            .write(
          ProductsCompanion(
            stockQuantity: Value(quantityAfter),
            updatedAt: Value(now),
          ),
        );

        await _database
            .into(_database.inventoryMovements)
            .insert(
              InventoryMovementsCompanion.insert(
                id: _generateId(),
                businessId: trimmedBusinessId,
                productId: item.productId,
                saleId: Value(trimmedSaleId),
                quantityChange: -item.quantity,
                quantityBefore: quantityBefore,
                quantityAfter: quantityAfter,
                movementType: 'sale',
                movementAt: soldAt,
                createdAt: now,
              ),
            );
      }

      if (paidMinor > 0) {
        await _database.into(_database.payments).insert(
              PaymentsCompanion.insert(
                id: _generateId(),
                businessId: trimmedBusinessId,
                customerId: Value(trimmedCustomerId),
                saleId: Value(trimmedSaleId),
                userId: trimmedUserId,
                amountMinor: paidMinor,
                paymentMethod: 'cash',
                paidAt: soldAt,
                createdAt: now,
              ),
            );
      }

      if (dueMinor > 0) {
        final requiredCustomerId = trimmedCustomerId;

        if (requiredCustomerId == null) {
          throw StateError(
            'A sale with an outstanding balance '
            'requires a customer.',
          );
        }

        await _database.into(_database.ledgerEntries).insert(
              LedgerEntriesCompanion.insert(
                id: _generateId(),
                businessId: trimmedBusinessId,
                customerId: requiredCustomerId,
                saleId: Value(trimmedSaleId),
                entryType: 'sale_credit',
                amountMinor: dueMinor,
                description: Value(
                  'Credit from sale '
                  '$trimmedInvoiceNumber',
                ),
                entryAt: soldAt,
                createdAt: now,
              ),
            );
      }

      return trimmedSaleId;
    });
  }

  Future<void> validateSaleItems({
    required String businessId,
    required List<SaleItemRequest> items,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError(
        'A sale must contain at least one item.',
      );
    }

    for (final item in items) {
      if (item.quantity <= 0) {
        throw ArgumentError(
          'Sale item quantity must be greater than zero.',
        );
      }

      if (item.discountMinor < 0) {
        throw ArgumentError(
          'Sale item discount cannot be negative.',
        );
      }

      final product = await (_database.select(
        _database.products,
      )
            ..where(
              (product) =>
                  product.id.equals(item.productId) &
                  product.businessId.equals(businessId),
            ))
          .getSingleOrNull();

      if (product == null) {
        throw StateError(
          'Product not found for this business: '
          '${item.productId}',
        );
      }

      if (!product.isActive) {
        throw StateError(
          'Product is inactive: ${product.name}',
        );
      }

      if (product.stockQuantity < item.quantity) {
        throw StateError(
          'Insufficient stock for product: ${product.name}',
        );
      }
    }
  }

  String _generateId() {
    return '${DateTime.now().microsecondsSinceEpoch}-'
        '${_idCounter++}';
  }

  static int _idCounter = 0;
}

class SaleItemRequest {
  const SaleItemRequest({
    required this.productId,
    required this.quantity,
    this.discountMinor = 0,
  });

  final String productId;
  final int quantity;
  final int discountMinor;
}

class SaleItemInsert {
  const SaleItemInsert({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPriceMinor,
    required this.purchasePriceMinor,
    required this.discountMinor,
    required this.lineTotalMinor,
  });

  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final int unitPriceMinor;
  final int purchasePriceMinor;
  final int discountMinor;
  final int lineTotalMinor;
}