import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/business_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBusinessId = ref.watch(activeBusinessIdProvider);
    final businessesAsync = ref.watch(businessListProvider);

    final activeBusiness = businessesAsync.whenOrNull(
      data: (businesses) {
        for (final business in businesses) {
          if (business.id == activeBusinessId) {
            return business;
          }
        }
        return null;
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Business Settings',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Manage your business setup and application information.'),
          const SizedBox(height: 24),

          Card(
            child: ListTile(
              leading: const Icon(Icons.store_outlined),
              title: const Text('Current Business'),
              subtitle: businessesAsync.when(
                loading: () => const Text('Loading business...'),
                error: (_, _) =>
                    const Text('Unable to load business information.'),
                data: (_) {
                  if (activeBusinessId == null) {
                    return const Text('No active business selected.');
                  }

                  if (activeBusiness == null) {
                    return const Text(
                      'Active business information unavailable.',
                    );
                  }

                  return Text(
                    '${activeBusiness.name} • ${activeBusiness.currencyCode}',
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const Icon(Icons.business_outlined),
              title: const Text('Business Setup'),
              subtitle: const Text(
                'Select an existing business or create a new business.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/business-setup'),
            ),
          ),

          const SizedBox(height: 24),

          Text('Application', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),

          const Card(
            child: ListTile(
              leading: Icon(Icons.computer_outlined),
              title: Text('Operating Mode'),
              subtitle: Text(
                'Local desktop application with an offline-first database.',
              ),
            ),
          ),

          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('About Account Care'),
              subtitle: Text(
                'Retail sales, inventory, customer credit, payments, and reports.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
