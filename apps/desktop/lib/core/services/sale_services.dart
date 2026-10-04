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
    if (discountMinor < 0) {
      throw ArgumentError('Discount cannot be negative.');
    }

    if (paidMinor < 0) {
      throw ArgumentError('Paid amount cannot be negative.');
    }

    await validateSaleItems(
      businessId: businessId,
      items: items,
    );

    return _database.transaction(() async {
      var subtotalMinor = 0;

      final saleItems = <SaleItemInsert>[];

      for (final item in items) {
        final product = await (_database.select(_database.products)
              ..where(
                (product) =>
                    product.id.equals(item.productId) &
                    product.businessId.equals(businessId),
              ))
            .getSingleOrNull();

        if (product == null) {
          throw StateError(
            'Product not found for this business: ${item.productId}',
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

      final totalMinor = subtotalMinor - discountMinor;

      if (paidMinor > totalMinor) {
        throw ArgumentError(
          'Paid amount cannot exceed the sale total.',
        );
      }

      final dueMinor = totalMinor - paidMinor;
      final now = DateTime.now();

      await _database.into(_database.sales).insert(
            SalesCompanion.insert(
              id: saleId,
              businessId: businessId,
              customerId: Value(customerId),
              userId: userId,
              invoiceNumber: invoiceNumber,
              subtotalMinor: subtotalMinor,
              discountMinor: Value(discountMinor),
              totalMinor: totalMinor,
              paidMinor: Value(paidMinor),
              dueMinor: Value(dueMinor),
              status: status,
              soldAt: soldAt,
              createdAt: now,
            ),
          );

      for (final item in saleItems) {
        await _database.into(_database.saleItems).insert(
              SaleItemsCompanion.insert(
                id: item.id,
                saleId: saleId,
                productId: item.productId,
                productName: item.productName,
                quantity: item.quantity,
                unitPriceMinor: item.unitPriceMinor,
                discountMinor: Value(item.discountMinor),
                lineTotalMinor: item.lineTotalMinor,
              ),
            );

        final product = await (_database.select(_database.products)
              ..where(
                (product) =>
                    product.id.equals(item.productId) &
                    product.businessId.equals(businessId),
              ))
            .getSingle();

        final quantityBefore = product.stockQuantity;
        final quantityAfter =
            quantityBefore - item.quantity;

        if (quantityAfter < 0) {
          throw StateError(
            'Insufficient stock for product: ${product.name}',
          );
        }

        await (_database.update(_database.products)
              ..where(
                (product) =>
                    product.id.equals(item.productId) &
                    product.businessId.equals(businessId),
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
                businessId: businessId,
                productId: item.productId,
                saleId: Value(saleId),
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
                businessId: businessId,
                customerId: Value(customerId),
                saleId: Value(saleId),
                userId: userId,
                amountMinor: paidMinor,
                paymentMethod: 'cash',
                paidAt: soldAt,
                createdAt: now,
              ),
            );
      }

      if (dueMinor > 0) {
        if (customerId == null) {
          throw StateError(
            'A sale with an outstanding balance requires a customer.',
          );
        }

        await _database.into(_database.ledgerEntries).insert(
              LedgerEntriesCompanion.insert(
                id: _generateId(),
                businessId: businessId,
                customerId: customerId,
                saleId: Value(saleId),
                entryType: 'sale_credit',
                amountMinor: dueMinor,
                description: Value(
                  'Credit from sale $invoiceNumber',
                ),
                entryAt: soldAt,
                createdAt: now,
              ),
            );
      }

      return saleId;
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

      final product = await (_database.select(_database.products)
            ..where(
              (product) =>
                  product.id.equals(item.productId) &
                  product.businessId.equals(businessId),
            ))
          .getSingleOrNull();

      if (product == null) {
        throw StateError(
          'Product not found for this business: ${item.productId}',
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
    return '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';
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
    required this.discountMinor,
    required this.lineTotalMinor,
  });

  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final int unitPriceMinor;
  final int discountMinor;
  final int lineTotalMinor;
}