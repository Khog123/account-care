import 'package:drift/drift.dart';

import '../app_database.dart';

class ExpenseRepository {
  ExpenseRepository(this._database);

  final AppDatabase _database;

  Future<List<Expense>> getByBusinessId(String businessId) {
    return (_database.select(_database.expenses)
          ..where((expense) => expense.businessId.equals(businessId))
          ..orderBy([
            (expense) => OrderingTerm.desc(expense.expenseAt),
          ]))
        .get();
  }

  Future<Expense?> getById(String expenseId) {
    return (_database.select(_database.expenses)
          ..where((expense) => expense.id.equals(expenseId)))
        .getSingleOrNull();
  }

  Future<List<Expense>> getByCategory({
    required String businessId,
    required String category,
  }) {
    return (_database.select(_database.expenses)
          ..where(
            (expense) =>
                expense.businessId.equals(businessId) &
                expense.category.equals(category),
          )
          ..orderBy([
            (expense) => OrderingTerm.desc(expense.expenseAt),
          ]))
        .get();
  }

  Future<List<Expense>> getByDateRange({
    required String businessId,
    required DateTime start,
    required DateTime end,
  }) {
    return (_database.select(_database.expenses)
          ..where(
            (expense) =>
                expense.businessId.equals(businessId) &
                expense.expenseAt.isBetweenValues(start, end),
          )
          ..orderBy([
            (expense) => OrderingTerm.desc(expense.expenseAt),
          ]))
        .get();
  }
}