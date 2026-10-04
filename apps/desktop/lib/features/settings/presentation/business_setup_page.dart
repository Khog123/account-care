import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/business_provider.dart';
import '../../../core/providers/dashboard_provider.dart';

class BusinessSetupPage extends ConsumerStatefulWidget {
  const BusinessSetupPage({super.key});

  @override
  ConsumerState<BusinessSetupPage> createState() =>
      _BusinessSetupPageState();
}

class _BusinessSetupPageState
    extends ConsumerState<BusinessSetupPage> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createBusiness() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a business name.'),
        ),
      );
      return;
    }

    final businessService = ref.read(businessServiceProvider);

    final businessId = 'business-${DateTime.now().microsecondsSinceEpoch}';

    await businessService.createBusiness(
      businessId: businessId,
      name: name,
    );

    ref
        .read(activeBusinessIdProvider.notifier)
        .setBusinessId(businessId);

    ref.invalidate(businessListProvider);
    ref.invalidate(dashboardProvider);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Business created successfully.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final businessesAsync = ref.watch(businessListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Setup'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: businessesAsync.when(
          loading: () {
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
          error: (error, stackTrace) {
            return Center(
              child: Text(
                'Unable to load businesses.\n$error',
                textAlign: TextAlign.center,
              ),
            );
          },
          data: (businesses) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Businesses',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select an existing business or create a new one.',
                ),
                const SizedBox(height: 24),
                if (businesses.isNotEmpty)
                  ...businesses.map(
                    (business) {
                      return Card(
                        child: ListTile(
                          title: Text(business.name),
                          subtitle: Text(business.currencyCode),
                          trailing: FilledButton(
                            onPressed: () {
                              ref
                                  .read(
                                    activeBusinessIdProvider.notifier,
                                  )
                                  .setBusinessId(business.id);

                              ref.invalidate(dashboardProvider);

                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${business.name} selected.',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Select'),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),
                const Text(
                  'Create New Business',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 400,
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Business name',
                      hintText: 'e.g. Khan General Store',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _createBusiness,
                  icon: const Icon(Icons.add_business),
                  label: const Text('Create Business'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}