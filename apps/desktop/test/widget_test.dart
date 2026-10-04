import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:desktop/app/app.dart';
import 'package:desktop/core/database/app_database.dart';
import 'package:desktop/core/providers/business_provider.dart';
import 'package:desktop/core/providers/database_provider.dart';

void main() {
  testWidgets('Account Care dashboard loads', (tester) async {
    await tester.binding.setSurfaceSize(
      const Size(1280, 720),
    );

    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final database = AppDatabase.test();

    addTearDown(database.close);

    final now = DateTime.now();

    await database.into(database.businesses).insert(
      BusinessesCompanion.insert(
        id: 'test-business',
        name: 'Test Business',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          activeBusinessIdProvider.overrideWith(
            TestActiveBusinessIdNotifier.new,
          ),
        ],
        child: const AccountCareApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsNWidgets(2));
    expect(find.text("Today's Sales"), findsOneWidget);
    expect(find.text("Today's Profit"), findsOneWidget);
    expect(find.text('Credit Due'), findsOneWidget);
    expect(find.text('Low Stock'), findsOneWidget);
    expect(find.text('Account Care'), findsOneWidget);
    expect(find.text('New Sale'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('Udhaar'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}

class TestActiveBusinessIdNotifier extends ActiveBusinessIdNotifier {
  @override
  String? build() {
    return 'test-business';
  }
}