
import '../app_database.dart';

class SaleItemRepository {
  SaleItemRepository(this._database);

  final AppDatabase _database;

  Future<List<SaleItem>> getBySaleId(String saleId) {
    return (_database.select(_database.saleItems)
          ..where((item) => item.saleId.equals(saleId)))
        .get();
  }

  Future<SaleItem?> getById(String saleItemId) {
    return (_database.select(_database.saleItems)
          ..where((item) => item.id.equals(saleItemId)))
        .getSingleOrNull();
  }

  Future<List<SaleItem>> getByProductId(String productId) {
    return (_database.select(_database.saleItems)
          ..where((item) => item.productId.equals(productId)))
        .get();
  }
}