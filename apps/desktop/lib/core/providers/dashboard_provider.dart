import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/dashboard_service.dart';
import 'business_provider.dart';
import 'service_providers.dart';

final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);

  if (businessId == null || businessId.isEmpty) {
    throw StateError('No active business selected.');
  }

  final dashboardService = ref.watch(dashboardServiceProvider);

  return dashboardService.getSummary(
    businessId: businessId,
  );
});