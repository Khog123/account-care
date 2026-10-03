import 'package:drift/drift.dart';

import '../database/app_database.dart';

class InventoryService {
  InventoryService(this._database);

  final AppDatabase _database;

  Future<String> addStock({
    required String businessId,
    required String productId,
    required int quantity,
    required String movementType,
    required DateTime movementAt,
    String? reference,
    String? notes,
  }) async {
    _validateQuantity(quantity);
    _validateMovementType(movementType);

    return _database.transaction(() async {
      final product = await _getProduct(
        businessId: businessId,
        productId: productId,
      );

      final quantityBefore = product.stockQuantity;
      final quantityAfter = quantityBefore + quantity;
      final now = DateTime.now();
      final movementId = _generateId();

      await (_database.update(_database.products)
            ..where((product) => product.id.equals(productId)))
          .write(
        ProductsCompanion(
          stockQuantity: Value(quantityAfter),
          updatedAt: Value(now),
        ),
      );

      await _database.into(_database.inventoryMovements).insert(
            InventoryMovementsCompanion.insert(
              id: movementId,
              businessId: businessId,
              productId: productId,
              quantityChange: quantity,
              quantityBefore: quantityBefore,
              quantityAfter: quantityAfter,
              movementType: movementType,
              reference: Value(reference),
              notes: Value(notes),
              movementAt: movementAt,
              createdAt: now,
            ),
          );

      return movementId;
    });
  }

  Future<String> removeStock({
    required String businessId,
    required String productId,
    required int quantity,
    required String movementType,
    required DateTime movementAt,
    String? reference,
    String? notes,
  }) async {
    _validateQuantity(quantity);
    _validateMovementType(movementType);

    return _database.transaction(() async {
      final product = await _getProduct(
        businessId: businessId,
        productId: productId,
      );

      final quantityBefore = product.stockQuantity;

      if (quantity > quantityBefore) {
        throw StateError(
          'Insufficient stock for product: ${product.name}',
        );
      }

      final quantityAfter = quantityBefore - quantity;
      final now = DateTime.now();
      final movementId = _generateId();

      await (_database.update(_database.products)
            ..where((product) => product.id.equals(productId)))
          .write(
        ProductsCompanion(
          stockQuantity: Value(quantityAfter),
          updatedAt: Value(now),
        ),
      );

      await _database.into(_database.inventoryMovements).insert(
            InventoryMovementsCompanion.insert(
              id: movementId,
              businessId: businessId,
              productId: productId,
              quantityChange: -quantity,
              quantityBefore: quantityBefore,
              quantityAfter: quantityAfter,
              movementType: movementType,
              reference: Value(reference),
              notes: Value(notes),
              movementAt: movementAt,
              createdAt: now,
            ),
          );

      return movementId;
    });
  }

  Future<Product> _getProduct({
    required String businessId,
    required String productId,
  }) async {
    final product = await (_database.select(_database.products)
          ..where(
            (product) =>
                product.id.equals(productId) &
                product.businessId.equals(businessId),
          ))
        .getSingleOrNull();

    if (product == null) {
      throw StateError(
        'Product not found for this business: $productId',
      );
    }

    return product;
  }

  void _validateQuantity(int quantity) {
    if (quantity <= 0) {
      throw ArgumentError(
        'Stock quantity must be greater than zero.',
      );
    }
  }

  void _validateMovementType(String movementType) {
    if (movementType.trim().isEmpty) {
      throw ArgumentError(
        'Movement type cannot be empty.',
      );
    }
  }

  String _generateId() {
    return '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';
  }

  static int _idCounter = 0;
}