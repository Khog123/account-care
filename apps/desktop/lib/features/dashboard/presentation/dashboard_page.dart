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
      backgroundColor: AccountCareTheme.workspace,
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
                  color: AccountCareTheme.text,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Your sales, stock and customer credit at a glance.',
                style: TextStyle(color: AccountCareTheme.muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: cardColumns,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: cardColumns == 1
                    ? 4.8
                    : cardColumns == 2
                    ? 2.9
                    : 1.9,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _MetricCard(
                    title: "Today's Sales",
                    value: _money(summary.todaySalesMinor),
                    icon: Icons.point_of_sale_rounded,
                    color: AccountCareTheme.blue,
                    comparison: summary.salesChangePercent,
                    comparisonLabel: 'vs same day last week',
                    invertComparison: false,
                  ),
                  _MetricCard(
                    title: 'Active Products',
                    value: '${summary.activeProductCount}',
                    icon: Icons.inventory_2_rounded,
                    color: AccountCareTheme.purple,
                    footer: Row(
                      children: [
                        if (summary.newProductCount > 0)
                          _TinyIndicator(
                            icon: Icons.arrow_upward_rounded,
                            text: '${summary.newProductCount} new',
                            color: AccountCareTheme.green,
                          ),
                        if (summary.newProductCount > 0 &&
                            summary.inactiveProductCount > 0)
                          const SizedBox(width: 8),
                        if (summary.inactiveProductCount > 0)
                          _TinyIndicator(
                            icon: Icons.remove_circle_outline,
                            text: '${summary.inactiveProductCount} inactive',
                            color: AccountCareTheme.red,
                          ),
                        if (summary.newProductCount == 0 &&
                            summary.inactiveProductCount == 0)
                          const Text(
                            'Products available for sale',
                            style: TextStyle(
                              color: AccountCareTheme.muted,
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
                    color: AccountCareTheme.orange,
                    comparison: summary.outstandingChangePercent,
                    comparisonLabel: 'vs last week',
                    invertComparison: true,
                  ),
                  _MetricCard(
                    title: 'Low Stock',
                    value: '${summary.lowStockProductCount}',
                    icon: Icons.inventory_rounded,
                    color: AccountCareTheme.teal,
                    footer: const Text(
                      'Active products at/below threshold',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AccountCareTheme.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const SizedBox(height: 20),
              if (compact) ...[
                _sectionRow(
                  'Sales vs Udhaar',
                  'Daily totals for the last 7 days',
                ),
                const SizedBox(height: 10),
                _Panel(
                  child: SizedBox(
                    height: 280,
                    child: _SalesChart(points: summary.dailyPoints),
                  ),
                ),
                const SizedBox(height: 18),
                _sectionRow(
                  'Top-Selling Products',
                  'Based on sales in the last 7 days',
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 280,
                  child: _TopProductsPanel(products: summary.topProducts),
                ),
                const SizedBox(height: 20),
                _sectionRow('Recent Sales', 'Latest completed invoices'),
                const SizedBox(height: 10),
                SizedBox(
                  height: 430,
                  child: _RecentSalesPanel(sales: summary.recentSales),
                ),
                const SizedBox(height: 18),
                _sectionRow('Outstanding by Customer', 'Top 5 debtors'),
                const SizedBox(height: 10),
                SizedBox(
                  height: 430,
                  child: _DebtorsPanel(debtors: summary.topDebtors),
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionRow(
                            'Sales vs Udhaar',
                            'Daily totals for the last 7 days',
                          ),
                          const SizedBox(height: 10),
                          _Panel(
                            child: SizedBox(
                              height: 280,
                              child: _SalesChart(points: summary.dailyPoints),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionRow(
                            'Top-Selling Products',
                            'Based on sales in the last 7 days',
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 280,
                            child: _TopProductsPanel(
                              products: summary.topProducts,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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
                          SizedBox(
                            height: 340,
                            child: _RecentSalesPanel(
                              sales: summary.recentSales,
                            ),
                          ),
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
                          SizedBox(
                            height: 340,
                            child: _DebtorsPanel(debtors: summary.topDebtors),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
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
                  color: AccountCareTheme.text,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AccountCareTheme.muted,
                ),
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
          ? AccountCareTheme.muted
          : favorable
          ? AccountCareTheme.green
          : AccountCareTheme.red;

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
    } else if (comparison == null && comparisonLabel != null) {
      bottom = const Text(
        'New activity — no prior baseline',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 10, color: AccountCareTheme.muted),
      );
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AccountCareTheme.border),
      ),
      clipBehavior: Clip.antiAlias,

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      color: AccountCareTheme.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AccountCareTheme.text,
                ),
              ),
            ),
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
        side: const BorderSide(color: AccountCareTheme.border),
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
          style: TextStyle(color: AccountCareTheme.muted),
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

    final rawInterval = (highest / 4).ceil();
    final roundedInterval = ((rawInterval + 999999) ~/ 1000000) * 1000000;
    final interval = roundedInterval < 1000000
        ? 1000000.0
        : roundedInterval.toDouble();
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
            _Legend(color: AccountCareTheme.blue, label: 'Sales'),
            _Legend(
              color: AccountCareTheme.orange,
              label: 'Udhaar / credit sales',
            ),
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
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AccountCareTheme.border,
                  strokeWidth: 1,
                ),
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
                        color: AccountCareTheme.muted,
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
                            color: AccountCareTheme.muted,
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
                  AccountCareTheme.blue,
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
                  AccountCareTheme.orange,
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
          style: const TextStyle(color: AccountCareTheme.muted, fontSize: 11),
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
    const headerColor = Color(0xFFF0F2F5);
    const columnStyle = TextStyle(
      color: AccountCareTheme.muted,
      fontSize: 10,
      fontWeight: FontWeight.w700,
    );

    Widget cell({
      required int flex,
      required String text,
      TextStyle? style,
      int maxLines = 2,
      TextAlign align = TextAlign.left,
    }) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: align,
            style: style,
          ),
        ),
      );
    }

    return _Panel(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                cell(flex: 14, text: 'Invoice', style: columnStyle),
                cell(flex: 17, text: 'Customer', style: columnStyle),
                cell(flex: 18, text: 'Date', style: columnStyle),
                cell(
                  flex: 15,
                  text: 'Amount',
                  style: columnStyle,
                  align: TextAlign.right,
                ),
                cell(
                  flex: 10,
                  text: 'Status',
                  style: columnStyle,
                  align: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: sales.isEmpty
                ? const Center(
                    child: Text(
                      'No completed sales yet.',
                      style: TextStyle(color: AccountCareTheme.muted),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: sales.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      color: AccountCareTheme.border,
                    ),
                    itemBuilder: (context, index) {
                      final sale = sales[index];
                      final status = sale.dueMinor <= 0
                          ? 'Paid'
                          : sale.paidMinor > 0
                          ? 'Partial'
                          : 'Due';
                      final statusColor = sale.dueMinor <= 0
                          ? AccountCareTheme.green
                          : sale.paidMinor > 0
                          ? AccountCareTheme.orange
                          : AccountCareTheme.red;

                      return Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 2,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            cell(
                              flex: 14,
                              text: sale.invoiceNumber,
                              maxLines: 2,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AccountCareTheme.text,
                              ),
                            ),
                            cell(
                              flex: 17,
                              text: sale.customerName,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AccountCareTheme.text,
                              ),
                            ),
                            cell(
                              flex: 18,
                              text: _dateTime(sale.soldAt),
                              style: const TextStyle(
                                fontSize: 9,
                                color: AccountCareTheme.muted,
                              ),
                            ),
                            cell(
                              flex: 15,
                              text: _money(sale.totalMinor),
                              maxLines: 1,
                              align: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AccountCareTheme.text,
                              ),
                            ),
                            Expanded(
                              flex: 10,
                              child: Center(
                                child: _StatusChip(
                                  label: status,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 12, color: AccountCareTheme.border),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.go('/payments'),
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
            height: 125,
            child: debtors.isEmpty
                ? const Center(
                    child: Text(
                      'No outstanding customer credit.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AccountCareTheme.muted,
                        fontSize: 12,
                      ),
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
                                color: AccountCareTheme.muted,
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
                                  color: AccountCareTheme.text,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Top 5 customers',
                              style: TextStyle(
                                color: AccountCareTheme.muted,
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
                        color: AccountCareTheme.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _money(debtors[i].outstandingMinor),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      color: AccountCareTheme.text,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 15, color: AccountCareTheme.border),
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
      AccountCareTheme.blue,
      AccountCareTheme.orange,
      AccountCareTheme.purple,
      AccountCareTheme.teal,
      AccountCareTheme.green,
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
                style: TextStyle(color: AccountCareTheme.muted),
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
                            color: AccountCareTheme.blue.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AccountCareTheme.blue,
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
                              color: AccountCareTheme.text,
                            ),
                          ),
                        ),
                        Text(
                          '${products[i].quantitySold} sold',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AccountCareTheme.muted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _money(products[i].salesMinor),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AccountCareTheme.text,
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
              color: AccountCareTheme.red,
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
