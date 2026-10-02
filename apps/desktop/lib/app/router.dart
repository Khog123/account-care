import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/customers/presentation/customers_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/payments/presentation/payments_page.dart';
import '../features/products/presentation/products_page.dart';
import '../features/reports/presentation/reports_page.dart';
import '../features/sales/presentation/sales_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/udhaar/presentation/udhaar_page.dart';
import 'shell/app_shell.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const AppShell(
          child: DashboardPage(),
        );
      },
    ),
    GoRoute(
      path: '/sales',
      builder: (BuildContext context, GoRouterState state) {
        return const AppShell(
          child: SalesPage(),
        );
      },
    ),
    GoRoute(
      path: '/products',
      builder: (BuildContext context, GoRouterState state) {
        return const AppShell(
          child: ProductsPage(),
        );
      },
    ),
    GoRoute(
      path: '/customers',
      builder: (BuildContext context, GoRouterState state) {
        return const AppShell(
          child: CustomersPage(),
        );
      },
    ),
    GoRoute(
      path: '/udhaar',
      builder: (BuildContext context, GoRouterState state) {
        return const AppShell(
          child: UdhaarPage(),
        );
      },
    ),
    GoRoute(
      path: '/payments',
      builder: (BuildContext context, GoRouterState state) {
        return const AppShell(
          child: PaymentsPage(),
        );
      },
    ),
    GoRoute(
      path: '/reports',
      builder: (BuildContext context, GoRouterState state) {
        return const AppShell(
          child: ReportsPage(),
        );
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (BuildContext context, GoRouterState state) {
        return const AppShell(
          child: SettingsPage(),
        );
      },
    ),
  ],
);