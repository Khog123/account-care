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
    activeOnly: false,
  );

  if (users.isEmpty) {
    throw StateError(
      'No users exist for business: ${firstBusiness.name}',
    );
  }

  final activeUsers = users.where((user) => user.isActive).toList();

  if (activeUsers.isEmpty) {
    throw StateError(
      'Users exist but none are active for business: '
      '${firstBusiness.name}',
    );
  }

  ref
      .read(activeUserIdProvider.notifier)
      .setUserId(activeUsers.first.id);

  return '/';
});