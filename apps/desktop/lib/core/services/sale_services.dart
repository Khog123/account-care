import 'package:drift/drift.dart';

import '../database/app_database.dart';

class SaleService {
  SaleService(this._database);

  final AppDatabase _database;

  Future<void> validateSaleItems({
    required String businessId,
    required List<SaleItemRequest> items,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('A sale must contain at least one item.');
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