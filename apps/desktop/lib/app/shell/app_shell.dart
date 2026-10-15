import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountCareTheme.workspace,
      body: Row(
        children: [
          const _AppSidebar(),
          Expanded(
            child: ColoredBox(color: AccountCareTheme.workspace, child: child),
          ),
        ],
      ),
    );
  }
}

class _AppSidebar extends StatelessWidget {
  const _AppSidebar();

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).uri.path;

    return Container(
      width: 204,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AccountCareTheme.navy, AccountCareTheme.navyDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x180B1F3A),
            blurRadius: 12,
            offset: Offset(3, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 20, 12, 19),
              child: Row(
                children: [
                  Container(
                    width: 27,
                    height: 27,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.bar_chart_rounded,
                      color: Color(0xFF35D0C5),
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Account Care',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.09)),
            const SizedBox(height: 12),
            _SidebarItem(
              icon: Icons.home_outlined,
              label: 'Dashboard',
              selected: currentLocation == '/',
              onTap: () => context.go('/'),
            ),
            _SidebarItem(
              icon: Icons.point_of_sale_outlined,
              label: 'New Sale',
              selected: currentLocation == '/sales',
              onTap: () => context.go('/sales'),
            ),
            _SidebarItem(
              icon: Icons.inventory_2_outlined,
              label: 'Products',
              selected: currentLocation == '/products',
              onTap: () => context.go('/products'),
            ),
            _SidebarItem(
              icon: Icons.people_outline,
              label: 'Customers',
              selected: currentLocation == '/customers',
              onTap: () => context.go('/customers'),
            ),
            _SidebarItem(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Udhaar',
              selected: currentLocation == '/udhaar',
              onTap: () => context.go('/udhaar'),
            ),
            _SidebarItem(
              icon: Icons.payments_outlined,
              label: 'Payments',
              selected: currentLocation == '/payments',
              onTap: () => context.go('/payments'),
            ),
            _SidebarItem(
              icon: Icons.bar_chart_outlined,
              label: 'Reports',
              selected: currentLocation == '/reports',
              onTap: () => context.go('/reports'),
            ),
            const Spacer(),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.09)),
            const SizedBox(height: 10),
            _SidebarItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              selected: currentLocation == '/settings',
              onTap: () => context.go('/settings'),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(17, 12, 12, 15),
              child: Text(
                'BUSINESS MANAGEMENT',
                style: TextStyle(
                  color: Color(0xFF8295AF),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      child: Material(
        color: selected ? AccountCareTheme.blue : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: Colors.white.withValues(alpha: 0.07),
          child: SizedBox(
            height: 37,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? Colors.white : const Color(0xFFD1DCEB),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFFE0E8F3),
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
