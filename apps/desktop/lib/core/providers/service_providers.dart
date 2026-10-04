import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/dashboard_service.dart';
import 'database_provider.dart';

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  final database = ref.watch(databaseProvider);

  return DashboardService(database);
});