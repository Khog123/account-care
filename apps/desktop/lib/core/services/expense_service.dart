import 'package:drift/drift.dart';

import '../database/app_database.dart';

class ExpenseService {
  ExpenseService(this._database);

  final AppDatabase _database;

  Future<String> recordExpense({
    required String businessId,
    required String userId,
    required String expenseId,
    required String category,
    required int amountMinor,
    String? description,
    required DateTime expenseAt,
  }) async {
    if (amountMinor <= 0) {
      throw ArgumentError(
        'Expense amount must be greater than zero.',
      );
    }

    if (category.trim().isEmpty) {
      throw ArgumentError(
        'Expense category cannot be empty.',
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

    final now = DateTime.now();

    await _database.into(_database.expenses).insert(
          ExpensesCompanion.insert(
            id: expenseId,
            businessId: businessId,
            userId: userId,
            category: category.trim(),
            amountMinor: amountMinor,
            description: Value(description),
            expenseAt: expenseAt,
            createdAt: now,
            updatedAt: now,
          ),
        );

    return expenseId;
  }

  Future<Expense?> getExpenseById({
    required String businessId,
    required String expenseId,
  }) {
    return (_database.select(_database.expenses)
          ..where(
            (expense) =>
                expense.id.equals(expenseId) &
                expense.businessId.equals(businessId),
          ))
        .getSingleOrNull();
  }
}