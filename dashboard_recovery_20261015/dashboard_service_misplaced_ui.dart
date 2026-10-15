import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/providers/dashboard_provider.dart';
import '../../../core/services/dashboard_service.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.workspace,
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: () => ref.invalidate(dashboardProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _DashboardError(
          message: error.toString(),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (summary) => _DashboardContent(summary: summary),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 850;
        final cardColumns = constraints.maxWidth >= 1150
            ? 4
            : constraints.maxWidth >= 650
            ? 2
            : 1;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Business overview',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Your sales, stock and customer credit at a glance.',
                style: TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: cardColumns,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: cardColumns == 1
                    ? 4.2
                    : cardColumns == 2
                    ? 2.6
                    : 1.65,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _MetricCard(
                    title: "Today's Sales",
                    value: _money(summary.todaySalesMinor),
                    icon: Icons.point_of_sale_rounded,
                    color: AppTheme.blue,
                    comparison: summary.salesChangePercent,
                    comparisonLabel: 'vs same day last week',
                    invertComparison: false,
                  ),
                  _MetricCard(
                    title: 'Active Products',
                    value: '${summary.activeProductCount}',
                    icon: Icons.inventory_2_rounded,
                    color: AppTheme.purple,
                    footer: Row(
                      children: [
                        if (summary.newProductCount > 0)
                          _TinyIndicator(
                            icon: Icons.arrow_upward_rounded,
                            text: '${summary.newProductCount} new',
                            color: AppTheme.green,
                          ),
                        if (summary.newProductCount > 0 &&
                            summary.inactiveProductCount > 0)
                          const SizedBox(width: 8),
                        if (summary.inactiveProductCount > 0)
                          _TinyIndicator(
                            icon: Icons.remove_circle_outline,
                            text: '${summary.inactiveProductCount} inactive',
                            color: AppTheme.red,
                          ),
                        if (summary.newProductCount == 0 &&
                            summary.inactiveProductCount == 0)
                          const Text(
                            'Products available for sale',
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _MetricCard(
                    title: 'Outstanding Credit',
                    value: _money(summary.creditDueMinor),
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppTheme.orange,
                    comparison: summary.outstandingChangePercent,
                    comparisonLabel: 'vs last week',
                    invertComparison: true,
                  ),
                  _MetricCard(
                    title: 'Low Stock',
                    value: '${summary.lowStockProductCount}',
                    icon: Icons.inventory_rounded,
                    color: AppTheme.teal,
                    footer: const Text(
                      'Active products at/below threshold',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppTheme.muted, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionRow(
                'Sales vs Udhaar',
                'Daily totals for the last 7 days',
              ),
              const SizedBox(height: 10),
              _Panel(
                child: SizedBox(
                  height: 260,
                  child: _SalesChart(points: summary.dailyPoints),
                ),
              ),
              const SizedBox(height: 20),
              if (compact) ...[
                _sectionRow('Recent Sales', 'Latest completed invoices'),
                const SizedBox(height: 10),
                _RecentSalesPanel(sales: summary.recentSales),
                const SizedBox(height: 18),
                _sectionRow('Outstanding by Customer', 'Top 5 debtors'),
                const SizedBox(height: 10),
                _DebtorsPanel(debtors: summary.topDebtors),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionRow(
                            'Recent Sales',
                            'Latest completed invoices',
                          ),
                          const SizedBox(height: 10),
                          _RecentSalesPanel(sales: summary.recentSales),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionRow(
                            'Outstanding by Customer',
                            'Top 5 debtors',
                          ),
                          const SizedBox(height: 10),
                          _DebtorsPanel(debtors: summary.topDebtors),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              _sectionRow(
                'Top-Selling Products',
                'Based on sales in the last 7 days',
              ),
              const SizedBox(height: 10),
              _TopProductsPanel(products: summary.topProducts),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionRow(String title, String subtitle) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.comparison,
    this.comparisonLabel,
    this.invertComparison = false,
    this.footer,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double? comparison;
  final String? comparisonLabel;
  final bool invertComparison;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    Widget bottom = footer ?? const SizedBox.shrink();

    if (comparison != null && comparisonLabel != null) {
      final change = comparison!;
      final favorable = invertComparison ? change <= 0 : change >= 0;
      final indicatorColor = change == 0
          ? AppTheme.muted
          : favorable
          ? AppTheme.green
          : AppTheme.red;

      bottom = Row(
        children: [
          Icon(
            change > 0
                ? Icons.trending_up_rounded
                : change < 0
                ? Icons.trending_down_rounded
                : Icons.trending_flat_rounded,
            size: 15,
            color: indicatorColor,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${change.abs().toStringAsFixed(1)}% $comparisonLabel',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: indicatorColor,
              ),
            ),
          ),
        ],
      );
    } else if ((comparison == null) && comparisonLabel != null) {
      bottom = Text(
        'Comparison unavailable',
        style: const TextStyle(fontSize: 10, color: AppTheme.muted),
      );
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.text,
                ),
              ),
            ),
            const SizedBox(height: 7),
            bottom,
          ],
        ),
      ),
    );
  }
}

class _TinyIndicator extends StatelessWidget {
  const _TinyIndicator({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.points});

  final List<DashboardDailyPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(
        child: Text(
          'No sales data for this period yet.',
          style: TextStyle(color: AppTheme.muted),
        ),
      );
    }

    final highest = points.fold<int>(
      0,
      (value, point) => [
        value,
        point.salesMinor,
        point.creditMinor,
      ].reduce((a, b) => a > b ? a : b),
    );

    final interval = highest <= 1000000
        ? 1000000.0
        : (highest / 4).ceilToDouble();
    final maxY = ((highest / interval).ceil() * interval)
        .clamp(interval, double.infinity)
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _Legend(color: AppTheme.blue, label: 'Sales'),
            _Legend(color: AppTheme.orange, label: 'Udhaar / credit sales'),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 6,
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: AppTheme.border, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 55,
                    interval: interval,
                    getTitlesWidget: (value, meta) => Text(
                      _shortMoney(value.round()),
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 27,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }

                      final date = points[index].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${date.day}/${date.month}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.muted,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                _line(
                  points
                      .asMap()
                      .entries
                      .map(
                        (entry) => FlSpot(
                          entry.key.toDouble(),
                          entry.value.salesMinor.toDouble(),
                        ),
                      )
                      .toList(),
                  AppTheme.blue,
                ),
                _line(
                  points
                      .asMap()
                      .entries
                      .map(
                        (entry) => FlSpot(
                          entry.key.toDouble(),
                          entry.value.creditMinor.toDouble(),
                        ),
                      )
                      .toList(),
                  AppTheme.orange,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2.5,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.07),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppTheme.muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _RecentSalesPanel extends StatelessWidget {
  const _RecentSalesPanel({required this.sales});

  final List<DashboardRecentSale> sales;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          if (sales.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'No completed sales yet.',
                style: TextStyle(color: AppTheme.muted),
              ),
            )
          else
            for (final sale in sales)
              Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppTheme.blue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sale.invoiceNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppTheme.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${sale.customerName} · ${_dateTime(sale.soldAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _money(sale.totalMinor),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _StatusChip(
                          label: sale.dueMinor <= 0
                              ? 'Paid'
                              : sale.paidMinor > 0
                              ? 'Partial'
                              : 'Due',
                          color: sale.dueMinor <= 0
                              ? AppTheme.green
                              : sale.paidMinor > 0
                              ? AppTheme.orange
                              : AppTheme.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          const Divider(height: 18, color: AppTheme.border),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.go('/udhaar'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 15),
              label: const Text('View all'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DebtorsPanel extends StatelessWidget {
  const _DebtorsPanel({required this.debtors});

  final List<DashboardDebtor> debtors;

  @override
  Widget build(BuildContext context) {
    final total = debtors.fold<int>(
      0,
      (sum, debtor) => sum + debtor.outstandingMinor,
    );

    return _Panel(
      child: Column(
        children: [
          SizedBox(
            height: 155,
            child: debtors.isEmpty
                ? const Center(
                    child: Text(
                      'No outstanding customer credit.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.muted, fontSize: 12),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 32,
                            sections: [
                              for (var i = 0; i < debtors.length; i++)
                                PieChartSectionData(
                                  value: debtors[i].outstandingMinor.toDouble(),
                                  color: _debtorColor(i),
                                  radius: 25,
                                  showTitle: false,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Total shown',
                              style: TextStyle(
                                color: AppTheme.muted,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 5),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _money(total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  color: AppTheme.text,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Top 5 customers',
                              style: TextStyle(
                                color: AppTheme.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < debtors.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: _debtorColor(i),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      debtors[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _money(debtors[i].outstandingMinor),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      color: AppTheme.text,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 15, color: AppTheme.border),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.go('/udhaar'),
              child: const Text('View debtors'),
            ),
          ),
        ],
      ),
    );
  }

  Color _debtorColor(int index) {
    const colors = [
      AppTheme.blue,
      AppTheme.orange,
      AppTheme.purple,
      AppTheme.teal,
      AppTheme.green,
    ];
    return colors[index % colors.length];
  }
}

class _TopProductsPanel extends StatelessWidget {
  const _TopProductsPanel({required this.products});

  final List<DashboardTopProduct> products;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: products.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Product sales will appear here after completed sales.',
                style: TextStyle(color: AppTheme.muted),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < products.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppTheme.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.blue,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            products[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.text,
                            ),
                          ),
                        ),
                        Text(
                          '${products[i].quantitySold} sold',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.muted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _money(products[i].salesMinor),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.text,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 42,
              color: AppTheme.red,
            ),
            const SizedBox(height: 12),
            const Text(
              'Dashboard unavailable',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

String _money(int minor) {
  final major = minor ~/ 100;
  final decimal = (minor % 100).abs().toString().padLeft(2, '0');
  return 'Rs. $major.$decimal';
}

String _shortMoney(int minor) {
  final value = minor / 100;

  if (value >= 1000000) {
    return ' ${(value / 1000000).toStringAsFixed(1)}m';
  }

  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(0)}k';
  }

  return value.toStringAsFixed(0);
}

String _dateTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '${date.day}/${date.month} $hour:$minute $period';
}
