import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const _AppSidebar(),
          Expanded(
            child: child,
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
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: 220,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Account Care',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 12),

              _SidebarItem(
                icon: Icons.dashboard_outlined,
                label: 'Dashboard',
                selected: true,
                onTap: () => context.go('/'),
              ),
              _SidebarItem(
                icon: Icons.point_of_sale_outlined,
                label: 'New Sale',
                onTap: () => context.go('/sales'),
              ),
              _SidebarItem(
                icon: Icons.inventory_2_outlined,
                label: 'Products',
                onTap: () => context.go('/products'),
              ),
              _SidebarItem(
                icon: Icons.people_outline,
                label: 'Customers',
                onTap: () => context.go('/customers'),
              ),
              _SidebarItem(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Udhaar',
                onTap: () => context.go('/udhaar'),
              ),
              _SidebarItem(
                icon: Icons.payments_outlined,
                label: 'Payments',
                onTap: () => context.go('/payments'),
              ),
              _SidebarItem(
                icon: Icons.bar_chart_outlined,
                label: 'Reports',
                onTap: () => context.go('/reports'),
              ),

              const Spacer(),

              _SidebarItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () => context.go('/settings'),
              ),

              const SizedBox(height: 12),
            ],
          ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 2,
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(icon),
          title: Text(label),
          selected: selected,
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}