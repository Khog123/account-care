import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'business_provider.dart';

final startupProvider = FutureProvider<String>((ref) async {
  final businesses = await ref.watch(businessListProvider.future);

  if (businesses.isEmpty) {
    return '/business-setup';
  }

  final firstBusiness = businesses.first;

  ref
      .read(activeBusinessIdProvider.notifier)
      .setBusinessId(firstBusiness.id);

  return '/';
});