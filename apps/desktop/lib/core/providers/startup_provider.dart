import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'business_provider.dart';
import 'service_providers.dart';

final startupProvider = FutureProvider<String>((ref) async {
  final businesses = await ref.watch(
    businessListProvider.future,
  );

  if (businesses.isEmpty) {
    return '/business-setup';
  }

  final firstBusiness = businesses.first;

  ref
      .read(activeBusinessIdProvider.notifier)
      .setBusinessId(firstBusiness.id);

  final userService = ref.read(userServiceProvider);

  final users = await userService.getUsers(
    businessId: firstBusiness.id,
    activeOnly: true,
  );

  if (users.isEmpty) {
    throw StateError(
      'No active user exists for business: ${firstBusiness.name}',
    );
  }

  ref
      .read(activeUserIdProvider.notifier)
      .setUserId(users.first.id);

  return '/';
});