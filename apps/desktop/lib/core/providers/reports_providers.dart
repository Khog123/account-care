import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/reports_service.dart';
import 'business_provider.dart';
import 'service_providers.dart';

class ReportsDateRange {
  const ReportsDateRange({required this.from, required this.to});

  final DateTime from;
  final DateTime to;
}

final reportsDateRangeProvider =
    NotifierProvider<ReportsDateRangeNotifier, ReportsDateRange>(
      ReportsDateRangeNotifier.new,
    );

class ReportsDateRangeNotifier extends Notifier<ReportsDateRange> {
  @override
  ReportsDateRange build() {
    final now = DateTime.now();

    return ReportsDateRange(
      from: DateTime(now.year, now.month, 1),
      to: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
    );
  }

  void setRange(DateTime from, DateTime to) {
    state = ReportsDateRange(from: from, to: to);
  }
}

final salesReportProvider = FutureProvider<SalesReport>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);

  if (businessId == null || businessId.isEmpty) {
    throw StateError('No active business selected.');
  }

  final range = ref.watch(reportsDateRangeProvider);
  final service = ref.watch(reportsServiceProvider);

  return service.getSalesReport(
    businessId: businessId,
    from: range.from,
    to: range.to,
  );
});

final topSellingProductsProvider = FutureProvider<List<TopSellingProduct>>((
  ref,
) async {
  final businessId = ref.watch(activeBusinessIdProvider);

  if (businessId == null || businessId.isEmpty) {
    throw StateError('No active business selected.');
  }

  final range = ref.watch(reportsDateRangeProvider);
  final service = ref.watch(reportsServiceProvider);

  return service.getTopSellingProducts(
    businessId: businessId,
    from: range.from,
    to: range.to,
  );
});
