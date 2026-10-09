import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'business_provider.dart';
import 'service_providers.dart';

final customerListProvider = FutureProvider.family<List<Customer>, bool>((
  ref,
  showInactive,
) async {
  final businessId = ref.watch(activeBusinessIdProvider);

  if (businessId == null || businessId.isEmpty) {
    throw StateError('No active business selected.');
  }

  final customerService = ref.watch(customerServiceProvider);

  final customers = await customerService.getCustomers(businessId: businessId);

  return customers.where((customer) {
    if (showInactive) {
      return !customer.isActive;
    }

    return customer.isActive;
  }).toList();
});
