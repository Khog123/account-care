import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'business_provider.dart';
import 'service_providers.dart';

final customerListProvider =
    FutureProvider<List<Customer>>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);

  if (businessId == null || businessId.isEmpty) {
    throw StateError(
      'No active business selected.',
    );
  }

  final customerService = ref.watch(customerServiceProvider);

  return customerService.getCustomers(
    businessId: businessId,
    activeOnly: true,
  );
});