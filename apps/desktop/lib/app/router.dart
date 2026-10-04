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
import '../features/settings/presentation/business_setup_page.dart';
import 'shell/app_shell.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (
        BuildContext context,
        GoRouterState state,
        Widget child,
      ) {
        return AppShell(
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            return const DashboardPage();
          },
        ),
        GoRoute(
          path: '/sales',
          builder: (context, state) {
            return const SalesPage();
          },
        ),
        GoRoute(
          path: '/products',
          builder: (context, state) {
            return const ProductsPage();
          },
        ),
        GoRoute(
          path: '/customers',
          builder: (context, state) {
            return const CustomersPage();
          },
        ),
        GoRoute(
          path: '/udhaar',
          builder: (context, state) {
            return const UdhaarPage();
          },
        ),
        GoRoute(
          path: '/payments',
          builder: (context, state) {
            return const PaymentsPage();
          },
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) {
            return const ReportsPage();
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) {
            return const SettingsPage();
          },
        ),
        GoRoute(
          path: '/business-setup',
          builder: (context, state) {
            return const BusinessSetupPage();
          },
        ),
      ],
    ),
  ],
);