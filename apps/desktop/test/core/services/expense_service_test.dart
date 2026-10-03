import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:desktop/core/database/app_database.dart';
import 'package:desktop/core/services/expense_service.dart';

void main() {
  late AppDatabase database;
  late ExpenseService expenseService;

  setUp(() {
    database = AppDatabase.test();
    expenseService = ExpenseService(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('records an expense for a business', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
          UsersCompanion.insert(
            id: 'user-1',
            businessId: 'business-1',
            name: 'Test User',
            username: 'testuser',
            passwordHash: 'hashed-password',
            role: 'master_merchant',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final expenseId = await expenseService.recordExpense(
      businessId: 'business-1',
      userId: 'user-1',
      expenseId: 'expense-1',
      category: 'Rent',
      amountMinor: 25000,
      description: 'Monthly shop rent',
      expenseAt: now,
    );

    expect(expenseId, 'expense-1');

    final expense = await (database.select(database.expenses)
          ..where((expense) => expense.id.equals('expense-1')))
        .getSingle();

    expect(expense.businessId, 'business-1');
    expect(expense.userId, 'user-1');
    expect(expense.category, 'Rent');
    expect(expense.amountMinor, 25000);
    expect(expense.description, 'Monthly shop rent');
    expect(
      expense.expenseAt,
      now.copyWith(microsecond: 0, millisecond: 0),
      );
  });

  test('rejects zero expense amount', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
          UsersCompanion.insert(
            id: 'user-1',
            businessId: 'business-1',
            name: 'Test User',
            username: 'testuser',
            passwordHash: 'hashed-password',
            role: 'master_merchant',
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(
      () => expenseService.recordExpense(
        businessId: 'business-1',
        userId: 'user-1',
        expenseId: 'expense-1',
        category: 'Rent',
        amountMinor: 0,
        expenseAt: now,
      ),
      throwsArgumentError,
    );

    final expenses = await database.select(database.expenses).get();

    expect(expenses, isEmpty);
  });

  test('rejects negative expense amount', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
          UsersCompanion.insert(
            id: 'user-1',
            businessId: 'business-1',
            name: 'Test User',
            username: 'testuser',
            passwordHash: 'hashed-password',
            role: 'master_merchant',
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(
      () => expenseService.recordExpense(
        businessId: 'business-1',
        userId: 'user-1',
        expenseId: 'expense-1',
        category: 'Rent',
        amountMinor: -1000,
        expenseAt: now,
      ),
      throwsArgumentError,
    );

    final expenses = await database.select(database.expenses).get();

    expect(expenses, isEmpty);
  });

  test('rejects an empty expense category', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
          UsersCompanion.insert(
            id: 'user-1',
            businessId: 'business-1',
            name: 'Test User',
            username: 'testuser',
            passwordHash: 'hashed-password',
            role: 'master_merchant',
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(
      () => expenseService.recordExpense(
        businessId: 'business-1',
        userId: 'user-1',
        expenseId: 'expense-1',
        category: '   ',
        amountMinor: 1000,
        expenseAt: now,
      ),
      throwsArgumentError,
    );

    final expenses = await database.select(database.expenses).get();

    expect(expenses, isEmpty);
  });

  test('rejects a user from another business', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Business One',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-2',
            name: 'Business Two',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
          UsersCompanion.insert(
            id: 'user-2',
            businessId: 'business-2',
            name: 'Other User',
            username: 'otheruser',
            passwordHash: 'hashed-password',
            role: 'master_merchant',
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(
      () => expenseService.recordExpense(
        businessId: 'business-1',
        userId: 'user-2',
        expenseId: 'expense-1',
        category: 'Rent',
        amountMinor: 25000,
        expenseAt: now,
      ),
      throwsA(isA<StateError>()),
    );

    final expenses = await database.select(database.expenses).get();

    expect(expenses, isEmpty);
  });

  test('gets an expense by id', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Test Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
          UsersCompanion.insert(
            id: 'user-1',
            businessId: 'business-1',
            name: 'Test User',
            username: 'testuser',
            passwordHash: 'hashed-password',
            role: 'master_merchant',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.expenses).insert(
          ExpensesCompanion.insert(
            id: 'expense-1',
            businessId: 'business-1',
            userId: 'user-1',
            category: 'Utilities',
            amountMinor: 5000,
            description: const Value('Electricity bill'),
            expenseAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

    final expense = await expenseService.getExpenseById(
      businessId: 'business-1',
      expenseId: 'expense-1',
    );

    expect(expense, isNotNull);
    expect(expense!.id, 'expense-1');
    expect(expense.businessId, 'business-1');
    expect(expense.category, 'Utilities');
    expect(expense.amountMinor, 5000);
  });

  test('does not return an expense from another business', () async {
    final now = DateTime.now();

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-1',
            name: 'Business One',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.businesses).insert(
          BusinessesCompanion.insert(
            id: 'business-2',
            name: 'Business Two',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.users).insert(
          UsersCompanion.insert(
            id: 'user-2',
            businessId: 'business-2',
            name: 'Other User',
            username: 'otheruser',
            passwordHash: 'hashed-password',
            role: 'master_merchant',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await database.into(database.expenses).insert(
          ExpensesCompanion.insert(
            id: 'expense-2',
            businessId: 'business-2',
            userId: 'user-2',
            category: 'Utilities',
            amountMinor: 5000,
            expenseAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

    final expense = await expenseService.getExpenseById(
      businessId: 'business-1',
      expenseId: 'expense-2',
    );

    expect(expense, isNull);
  });
}