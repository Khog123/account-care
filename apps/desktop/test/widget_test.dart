import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:desktop/app/app.dart';

void main() {
  testWidgets('Account Care dashboard loads', (tester) async {
    await tester.binding.setSurfaceSize(
      const Size(1280, 720),
    );

    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(const AccountCareApp());
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