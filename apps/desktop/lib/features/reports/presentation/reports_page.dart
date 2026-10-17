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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final start = currentFrom.isAfter(today) ? today : currentFrom;
    final end = currentTo.isAfter(today) ? today : currentTo;

    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: start.isAfter(end) ? end : start,
        end: end,
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
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 17, color: accent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Tooltip(
              message: value,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeading({
    required BuildContext context,
    required String title,
    required String subtitle,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700, color: colors.onSurface),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final range = ref.watch(reportsDateRangeProvider);
    final salesAsync = ref.watch(salesReportProvider);
    final productsAsync = ref.watch(topSellingProductsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 76,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 24,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Reports',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Understand your sales and business performance',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh reports',
            onPressed: () {
              ref.invalidate(salesReportProvider);
              ref.invalidate(topSellingProductsProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: colors.outlineVariant),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 700 ? 14.0 : 24.0;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              18,
              horizontalPadding,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          _selectRange(context, ref, range.from, range.to),
                      icon: const Icon(Icons.calendar_month_rounded, size: 17),
                      label: Text('${_date(range.from)} - ${_date(range.to)}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.primary,
                        side: BorderSide(color: colors.outlineVariant),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                    OutlinedButton(
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
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.onSurface,
                        side: BorderSide(color: colors.outlineVariant),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      child: const Text('This month'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _sectionHeading(
                  context: context,
                  title: 'Sales overview',
                  subtitle: 'Summary for the selected date range',
                ),
                const SizedBox(height: 12),
                salesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 38,
                            color: colors.error,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Could not load the sales report.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$error',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: () =>
                                ref.invalidate(salesReportProvider),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (report) {
                    final width =
                        constraints.maxWidth - (horizontalPadding * 2);

                    final columns = width >= 1250
                        ? 5
                        : width >= 850
                        ? 3
                        : width >= 480
                        ? 2
                        : 1;

                    final cardWidth = (width - (columns - 1) * 12) / columns;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          height: 102,
                          child: _summaryCard(
                            context: context,
                            title: 'Completed Sales',
                            value: report.saleCount.toString(),
                            icon: Icons.receipt_long_rounded,
                            accent: colors.primary,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          height: 102,
                          child: _summaryCard(
                            context: context,
                            title: 'Sales Total',
                            value: _money(report.totalSalesMinor),
                            icon: Icons.point_of_sale_rounded,
                            accent: colors.primary,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          height: 102,
                          child: _summaryCard(
                            context: context,
                            title: 'Paid Toward These Sales',
                            value: _money(report.totalPaidMinor),
                            icon: Icons.payments_outlined,
                            accent: colors.tertiary,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          height: 102,
                          child: _summaryCard(
                            context: context,
                            title: 'Outstanding Credit',
                            value: _money(report.totalCreditMinor),
                            icon: Icons.account_balance_wallet_outlined,
                            accent: colors.error,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          height: 102,
                          child: _summaryCard(
                            context: context,
                            title: 'Estimated Gross Profit',
                            value: _money(report.totalProfitMinor),
                            icon: Icons.trending_up_rounded,
                            accent: colors.tertiary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 26),
                _sectionHeading(
                  context: context,
                  title: 'Top-selling products',
                  subtitle: 'Products ranked by sales during this period',
                ),
                const SizedBox(height: 12),
                productsAsync.when(
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (error, stack) => Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Could not load products report: $error'),
                    ),
                  ),
                  data: (products) {
                    if (products.isEmpty) {
                      return Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 30,
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 32,
                                  color: colors.onSurfaceVariant,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'No completed sales in this date range.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colors.outlineVariant),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 44,
                          dataRowMinHeight: 48,
                          dataRowMaxHeight: 58,
                          horizontalMargin: 18,
                          columnSpacing: 36,
                          headingTextStyle: theme.textTheme.labelMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.onSurfaceVariant,
                              ),
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
                                DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minWidth: 150,
                                    ),
                                    child: Text(
                                      product.productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text(product.quantitySold.toString())),
                                DataCell(Text(_money(product.salesMinor))),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Paid and outstanding amounts reflect the current '
                          'status of sales made during the selected period. '
                          'Gross profit is an estimate based on saved item '
                          'costs and discounts; it excludes operating expenses.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.5,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
