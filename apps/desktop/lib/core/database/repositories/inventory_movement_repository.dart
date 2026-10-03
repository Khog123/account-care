import 'package:drift/drift.dart';

import '../app_database.dart';

class InventoryMovementRepository {
  InventoryMovementRepository(this._database);

  final AppDatabase _database;

  Future<List<InventoryMovement>> getByBusinessId(String businessId) {
    return (_database.select(_database.inventoryMovements)
          ..where((movement) => movement.businessId.equals(businessId))
          ..orderBy([
            (movement) => OrderingTerm.desc(movement.movementAt),
          ]))
        .get();
  }

  Future<InventoryMovement?> getById(String movementId) {
    return (_database.select(_database.inventoryMovements)
          ..where((movement) => movement.id.equals(movementId)))
        .getSingleOrNull();
  }

  Future<List<InventoryMovement>> getByProductId(String productId) {
    return (_database.select(_database.inventoryMovements)
          ..where((movement) => movement.productId.equals(productId))
          ..orderBy([
            (movement) => OrderingTerm.desc(movement.movementAt),
          ]))
        .get();
  }

  Future<List<InventoryMovement>> getBySaleId(String saleId) {
    return (_database.select(_database.inventoryMovements)
          ..where((movement) => movement.saleId.equals(saleId))
          ..orderBy([
            (movement) => OrderingTerm.desc(movement.movementAt),
          ]))
        .get();
  }

  Future<List<InventoryMovement>> getByDateRange({
    required String businessId,
    required DateTime start,
    required DateTime end,
  }) {
    return (_database.select(_database.inventoryMovements)
          ..where(
            (movement) =>
                movement.businessId.equals(businessId) &
                movement.movementAt.isBetweenValues(start, end),
          )
          ..orderBy([
            (movement) => OrderingTerm.desc(movement.movementAt),
          ]))
        .get();
  }
}