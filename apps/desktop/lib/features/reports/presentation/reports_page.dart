import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/reports_providers.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  String _money(int minor) {
    final major = minor ~/ 100;
    final decimal = (minor % 100).abs().toString().padLeft(2, '0');
    return 'PKR $major.$decimal';
  }

  String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _selectRange(
    BuildContext context,
    WidgetRef ref,
    DateTime currentFrom,
    DateTime currentTo,
  ) async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: currentFrom,
        end: currentTo.isAfter(DateTime.now()) ? DateTime.now() : currentTo,
      ),
      helpText: 'Select report date range',
    );

    if (selected == null) return;

    ref
        .read(reportsDateRangeProvider.notifier)
        .setRange(
          selected.start,
          DateTime(
            selected.end.year,
            selected.end.month,
            selected.end.day,
            23,
            59,
            59,
            999,
          ),
        );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportsDateRangeProvider);
    final salesAsync = ref.watch(salesReportProvider);
    final productsAsync = ref.watch(topSellingProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Refresh reports',
            onPressed: () {
              ref.invalidate(salesReportProvider);
              ref.invalidate(topSellingProductsProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      _selectRange(context, ref, range.from, range.to),
                  icon: const Icon(Icons.date_range),
                  label: Text('${_date(range.from)} – ${_date(range.to)}'),
                ),
                TextButton(
                  onPressed: () {
                    final now = DateTime.now();
                    ref
                        .read(reportsDateRangeProvider.notifier)
                        .setRange(
                          DateTime(now.year, now.month, 1),
                          DateTime(
                            now.year,
                            now.month,
                            now.day,
                            23,
                            59,
                            59,
                            999,
                          ),
                        );
                  },
                  child: const Text('This month'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: salesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 40),
                      const SizedBox(height: 12),
                      Text('Could not load sales report.\n$error'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(salesReportProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (report) => SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GridView.count(
                        crossAxisCount: MediaQuery.sizeOf(context).width >= 1100
                            ? 3
                            : 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.8,
                        children: [
                          _summaryCard(
                            title: 'Completed Sales',
                            value: report.saleCount.toString(),
                            icon: Icons.receipt_long,
                          ),
                          _summaryCard(
                            title: 'Sales Total',
                            value: _money(report.totalSalesMinor),
                            icon: Icons.point_of_sale,
                          ),
                          _summaryCard(
                            title: 'Paid Toward These Sales',
                            value: _money(report.totalPaidMinor),
                            icon: Icons.payments_outlined,
                          ),
                          _summaryCard(
                            title: 'Outstanding Credit',
                            value: _money(report.totalCreditMinor),
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                          _summaryCard(
                            title: 'Estimated Gross Profit',
                            value: _money(report.totalProfitMinor),
                            icon: Icons.trending_up,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Top-Selling Products',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      productsAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (error, stack) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Could not load products report: $error',
                            ),
                          ),
                        ),
                        data: (products) {
                          if (products.isEmpty) {
                            return const Card(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: Text(
                                    'No completed sales in this date range.',
                                  ),
                                ),
                              ),
                            );
                          }

                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Product')),
                                  DataColumn(
                                    label: Text('Quantity Sold'),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text('Sales Total'),
                                    numeric: true,
                                  ),
                                ],
                                rows: products.map((product) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(product.productName)),
                                      DataCell(
                                        Text(product.quantitySold.toString()),
                                      ),
                                      DataCell(
                                        Text(_money(product.salesMinor)),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Paid and outstanding amounts reflect the current '
                        'status of sales made during the selected period. '
                        'Gross profit is an estimate based on saved item costs '
                        'and discounts; it excludes operating expenses.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
