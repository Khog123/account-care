import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/business_provider.dart';
import '../../../core/providers/customer_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/service_providers.dart';

class UdhaarPage extends ConsumerStatefulWidget {
  const UdhaarPage({super.key});

  @override
  ConsumerState<UdhaarPage> createState() => _UdhaarPageState();
}

class _UdhaarPageState extends ConsumerState<UdhaarPage> {
  final _searchController = TextEditingController();

  String _searchQuery = '';
  Customer? _selectedCustomer;

  Future<List<_CustomerDebt>>? _debtsFuture;
  String? _debtsFutureBusinessId;
  String? _debtsFutureCustomerSignature;

  bool _isExportingDebtors = false;
  final Set<String> _exportingCustomerIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _money(int minor) {
    final amount = (minor.abs() / 100).toStringAsFixed(2);
    return '${minor < 0 ? '-' : ''}Rs. $amount';
  }

  void _resetDebtsFuture() {
    _debtsFuture = null;
    _debtsFutureBusinessId = null;
    _debtsFutureCustomerSignature = null;
  }

  Future<void> _exportAllDebtors({
    required List<Customer> customers,
    required Map<String, int> balancesMinor,
    required String businessId,
  }) async {
    if (_isExportingDebtors) return;

    setState(() => _isExportingDebtors = true);

    try {
      final businesses = await ref.read(businessListProvider.future);
      final business = businesses
          .where((item) => item.id == businessId)
          .firstOrNull;

      if (business == null) {
        throw StateError('Active business could not be found.');
      }

      final saveLocation = await getSaveLocation(
        suggestedName:
            'account_care_debtors_${DateTime.now().toIso8601String().substring(0, 10)}.xlsx',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'Excel workbook', extensions: ['xlsx']),
        ],
      );

      if (saveLocation == null) return;

      final bytes = await ref
          .read(excelExportServiceProvider)
          .createDebtorsWorkbook(
            businessName: business.name,
            currencyCode: business.currencyCode,
            customers: customers,
            balancesMinor: balancesMinor,
          );

      await File(saveLocation.path).writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debtors list exported successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export debtors: $error')),
      );
    } finally {
      if (mounted) setState(() => _isExportingDebtors = false);
    }
  }

  Future<void> _exportCustomerHistory({
    required Customer customer,
    required String businessId,
  }) async {
    if (_exportingCustomerIds.contains(customer.id)) return;

    setState(() => _exportingCustomerIds.add(customer.id));

    try {
      final businesses = await ref.read(businessListProvider.future);
      final business = businesses
          .where((item) => item.id == businessId)
          .firstOrNull;

      if (business == null) {
        throw StateError('Active business could not be found.');
      }

      final database = ref.read(databaseProvider);
      final ledgerService = ref.read(customerLedgerServiceProvider);

      final sales =
          await (database.select(database.sales)
                ..where(
                  (sale) =>
                      sale.businessId.equals(businessId) &
                      sale.customerId.equals(customer.id) &
                      sale.status.equals('completed'),
                )
                ..orderBy([(sale) => OrderingTerm.asc(sale.soldAt)]))
              .get();

      final saleIds = sales.map((sale) => sale.id).toSet();

      final saleItems = saleIds.isEmpty
          ? <SaleItem>[]
          : await (database.select(
              database.saleItems,
            )..where((item) => item.saleId.isIn(saleIds))).get();

      final payments =
          await (database.select(database.payments)
                ..where(
                  (payment) =>
                      payment.businessId.equals(businessId) &
                      payment.customerId.equals(customer.id),
                )
                ..orderBy([(payment) => OrderingTerm.asc(payment.paidAt)]))
              .get();

      final paymentIds = payments.map((payment) => payment.id).toSet();

      final allocations = paymentIds.isEmpty
          ? <PaymentAllocation>[]
          : await (database.select(database.paymentAllocations)..where(
                  (allocation) =>
                      allocation.businessId.equals(businessId) &
                      allocation.paymentId.isIn(paymentIds),
                ))
                .get();

      final ledgerEntries = await ledgerService.getLedgerEntries(
        businessId: businessId,
        customerId: customer.id,
      );

      final balanceMinor = await ledgerService.getOutstandingBalance(
        businessId: businessId,
        customerId: customer.id,
      );

      final safeCustomerName = customer.name.replaceAll(
        RegExp(r'[^\w-]+'),
        '_',
      );

      final saveLocation = await getSaveLocation(
        suggestedName:
            'account_care_${safeCustomerName}_history_${DateTime.now().toIso8601String().substring(0, 10)}.xlsx',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'Excel workbook', extensions: ['xlsx']),
        ],
      );

      if (saveLocation == null) return;

      final bytes = await ref
          .read(excelExportServiceProvider)
          .createCustomerHistoryWorkbook(
            customer: customer,
            businessName: business.name,
            currencyCode: business.currencyCode,
            balanceMinor: balanceMinor,
            sales: sales,
            saleItems: saleItems,
            payments: payments,
            allocations: allocations,
            ledgerEntries: ledgerEntries,
          );

      await File(saveLocation.path).writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('History exported for ${customer.name}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export customer history: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingCustomerIds.remove(customer.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider(false));
    final businessId = ref.watch(activeBusinessIdProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    ref.listen(activeBusinessIdProvider, (previous, next) {
      if (previous != next) {
        setState(_resetDebtsFuture);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final horizontalPadding = compact ? 14.0 : 22.0;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                18,
                horizontalPadding,
                14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Page heading, styled to match Payments.
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          color: colors.primary,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Udhaar',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Track customer dues and outstanding balances.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh customer balances',
                        onPressed: () {
                          setState(_resetDebtsFuture);
                          ref.invalidate(customerListProvider(false));
                        },
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: customersAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 40),
                            const SizedBox(height: 12),
                            const Text('Could not load customers.'),
                            const SizedBox(height: 8),
                            Text(error.toString(), textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () {
                                ref.invalidate(customerListProvider(false));
                              },
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                      data: (customers) {
                        if (businessId == null || businessId.isEmpty) {
                          return const Center(
                            child: Text('No active business selected.'),
                          );
                        }

                        final customerSignature = customers
                            .map((customer) => customer.id)
                            .join(',');

                        if (_debtsFuture == null ||
                            _debtsFutureBusinessId != businessId ||
                            _debtsFutureCustomerSignature !=
                                customerSignature) {
                          _debtsFutureBusinessId = businessId;
                          _debtsFutureCustomerSignature = customerSignature;
                          _debtsFuture = _loadDebts(
                            customers: customers,
                            businessId: businessId,
                          );
                        }

                        return FutureBuilder<List<_CustomerDebt>>(
                          future: _debtsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.error_outline, size: 36),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Could not calculate customer balances:\n'
                                      '${snapshot.error}',
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    FilledButton(
                                      onPressed: () {
                                        setState(_resetDebtsFuture);
                                      },
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final allDebts = snapshot.data ?? [];
                            final allDebtors = allDebts
                                .where((debt) => debt.balanceMinor > 0)
                                .toList();

                            final query = _searchQuery.trim().toLowerCase();

                            final debts = allDebtors.where((debt) {
                              final customer = debt.customer;
                              return customer.name.toLowerCase().contains(
                                    query,
                                  ) ||
                                  (customer.phone ?? '').toLowerCase().contains(
                                    query,
                                  );
                            }).toList();

                            final totalDebt = allDebtors.fold<int>(
                              0,
                              (sum, debt) => sum + debt.balanceMinor,
                            );

                            final selectedCustomer = allDebtors
                                .where(
                                  (debt) =>
                                      debt.customer.id == _selectedCustomer?.id,
                                )
                                .map((debt) => debt.customer)
                                .firstOrNull;

                            final contentWidth =
                                constraints.maxWidth - horizontalPadding * 2;
                            final summaryGap = 12.0;
                            final summaryWidth = compact
                                ? contentWidth
                                : (contentWidth - summaryGap * 2) / 3;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Summary cards and export action.
                                Wrap(
                                  spacing: summaryGap,
                                  runSpacing: 12,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    _UdhaarMetricCard(
                                      width: summaryWidth,
                                      icon:
                                          Icons.account_balance_wallet_outlined,
                                      label: 'Total Outstanding',
                                      value: _money(totalDebt),
                                      helper: 'Total unpaid customer balances',
                                      accent: colors.primary,
                                    ),
                                    _UdhaarMetricCard(
                                      width: summaryWidth,
                                      icon: Icons.people_alt_outlined,
                                      label: 'Total Customers',
                                      value: customers.length.toString(),
                                      helper:
                                          '${allDebtors.length} with outstanding dues',
                                      accent: const Color(0xFF16856B),
                                    ),
                                    SizedBox(
                                      width: compact ? contentWidth : null,
                                      child: FilledButton.icon(
                                        onPressed: _isExportingDebtors
                                            ? null
                                            : () => _exportAllDebtors(
                                                businessId: businessId,
                                                customers: allDebtors
                                                    .map(
                                                      (debt) => debt.customer,
                                                    )
                                                    .toList(),
                                                balancesMinor: {
                                                  for (final debt in allDebtors)
                                                    debt.customer.id:
                                                        debt.balanceMinor,
                                                },
                                              ),
                                        icon: _isExportingDebtors
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.download_outlined,
                                                size: 18,
                                              ),
                                        label: Text(
                                          _isExportingDebtors
                                              ? 'Exporting...'
                                              : 'Download All Debtors',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Search sits underneath the summary row.
                                TextField(
                                  controller: _searchController,
                                  onChanged: (value) {
                                    setState(() => _searchQuery = value);
                                  },
                                  decoration: InputDecoration(
                                    hintText:
                                        'Search debtor by name or phone number',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: _searchQuery.isEmpty
                                        ? null
                                        : IconButton(
                                            tooltip: 'Clear search',
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() => _searchQuery = '');
                                            },
                                            icon: const Icon(Icons.close),
                                          ),
                                    filled: true,
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Debtor list and selected customer ledger.
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, panelConstraints) {
                                      final vertical =
                                          panelConstraints.maxWidth < 900;

                                      return Flex(
                                        direction: vertical
                                            ? Axis.vertical
                                            : Axis.horizontal,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            flex: vertical ? 2 : 2,
                                            child: Card(
                                              margin: EdgeInsets.zero,
                                              clipBehavior: Clip.antiAlias,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                          16,
                                                          14,
                                                          16,
                                                          10,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            'Customers with dues',
                                                            style: theme
                                                                .textTheme
                                                                .titleMedium
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                          ),
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 9,
                                                                vertical: 5,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: colors
                                                                .primaryContainer,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  20,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            '${debts.length}',
                                                            style: TextStyle(
                                                              color: colors
                                                                  .onPrimaryContainer,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const Divider(height: 1),
                                                  Expanded(
                                                    child: debts.isEmpty
                                                        ? Center(
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    20,
                                                                  ),
                                                              child: Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  Icon(
                                                                    query.isEmpty
                                                                        ? Icons
                                                                              .check_circle_outline
                                                                        : Icons
                                                                              .search_off,
                                                                    size: 38,
                                                                    color: colors
                                                                        .onSurfaceVariant,
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 10,
                                                                  ),
                                                                  Text(
                                                                    query.isEmpty
                                                                        ? 'No outstanding dues'
                                                                        : 'No matching customers',
                                                                    style: theme
                                                                        .textTheme
                                                                        .titleMedium
                                                                        ?.copyWith(
                                                                          fontWeight:
                                                                              FontWeight.w700,
                                                                        ),
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 5,
                                                                  ),
                                                                  Text(
                                                                    query.isEmpty
                                                                        ? 'Customers with unpaid balances will appear here.'
                                                                        : 'Try a different name or phone number.',
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                    style: theme
                                                                        .textTheme
                                                                        .bodySmall
                                                                        ?.copyWith(
                                                                          color:
                                                                              colors.onSurfaceVariant,
                                                                        ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          )
                                                        : ListView.separated(
                                                            itemCount:
                                                                debts.length,
                                                            separatorBuilder:
                                                                (_, _) =>
                                                                    const Divider(
                                                                      height: 1,
                                                                      indent:
                                                                          16,
                                                                    ),
                                                            itemBuilder: (context, index) {
                                                              final debt =
                                                                  debts[index];
                                                              final selected =
                                                                  _selectedCustomer
                                                                      ?.id ==
                                                                  debt
                                                                      .customer
                                                                      .id;
                                                              final isExporting =
                                                                  _exportingCustomerIds
                                                                      .contains(
                                                                        debt
                                                                            .customer
                                                                            .id,
                                                                      );

                                                              return ListTile(
                                                                selected:
                                                                    selected,
                                                                selectedTileColor: colors
                                                                    .primary
                                                                    .withValues(
                                                                      alpha:
                                                                          0.08,
                                                                    ),
                                                                contentPadding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          14,
                                                                      vertical:
                                                                          5,
                                                                    ),
                                                                leading: CircleAvatar(
                                                                  backgroundColor:
                                                                      selected
                                                                      ? colors
                                                                            .primary
                                                                      : colors
                                                                            .primaryContainer,
                                                                  foregroundColor:
                                                                      selected
                                                                      ? colors
                                                                            .onPrimary
                                                                      : colors
                                                                            .onPrimaryContainer,
                                                                  child: Text(
                                                                    debt
                                                                            .customer
                                                                            .name
                                                                            .isEmpty
                                                                        ? '?'
                                                                        : debt
                                                                              .customer
                                                                              .name[0]
                                                                              .toUpperCase(),
                                                                  ),
                                                                ),
                                                                title: Text(
                                                                  debt
                                                                      .customer
                                                                      .name,
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                  ),
                                                                ),
                                                                subtitle: Text(
                                                                  debt.customer.phone
                                                                              ?.trim()
                                                                              .isNotEmpty ==
                                                                          true
                                                                      ? debt
                                                                            .customer
                                                                            .phone!
                                                                            .trim()
                                                                      : 'No phone number',
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                                trailing: Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    IconButton(
                                                                      tooltip: 'Export customer history',
                                                                      onPressed:
                                                                          isExporting
                                                                          ? null
                                                                          : () => _exportCustomerHistory(
                                                                              customer: debt.customer,
                                                                              businessId: businessId,
                                                                            ),
                                                                      icon:
                                                                          isExporting
                                                                          ? const SizedBox(
                                                                              width: 17,
                                                                              height: 17,
                                                                              child: CircularProgressIndicator(
                                                                                strokeWidth: 2,
                                                                              ),
                                                                            )
                                                                          : const Icon(
                                                                              Icons.download_outlined,
                                                                              size: 19,
                                                                            ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 4,
                                                                    ),
                                                                    Text(
                                                                      _money(
                                                                        debt.balanceMinor,
                                                                      ),
                                                                      style: const TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.w800,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                onTap: () {
                                                                  setState(() {
                                                                    _selectedCustomer =
                                                                        debt.customer;
                                                                  });
                                                                },
                                                              );
                                                            },
                                                          ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: vertical ? 0 : 14,
                                            height: vertical ? 12 : 0,
                                          ),
                                          Expanded(
                                            flex: vertical ? 3 : 3,
                                            child: selectedCustomer == null
                                                ? Card(
                                                    margin: EdgeInsets.zero,
                                                    child: Center(
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              24,
                                                            ),
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .receipt_long_outlined,
                                                              size: 46,
                                                              color: colors
                                                                  .onSurfaceVariant,
                                                            ),
                                                            const SizedBox(
                                                              height: 12,
                                                            ),
                                                            Text(
                                                              'Select a customer',
                                                              style: theme
                                                                  .textTheme
                                                                  .titleMedium
                                                                  ?.copyWith(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                  ),
                                                            ),
                                                            const SizedBox(
                                                              height: 5,
                                                            ),
                                                            Text(
                                                              'Their sales and payment history will appear here.',
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: theme
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    color: colors
                                                                        .onSurfaceVariant,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : SingleChildScrollView(
                                                    child: _CustomerLedgerPanel(
                                                      customer:
                                                          selectedCustomer,
                                                      businessId: businessId,
                                                      money: _money,
                                                    ),
                                                  ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<List<_CustomerDebt>> _loadDebts({
    required List<Customer> customers,
    required String businessId,
  }) async {
    final ledgerService = ref.read(customerLedgerServiceProvider);
    final results = <_CustomerDebt>[];

    for (final customer in customers) {
      final balance = await ledgerService.getOutstandingBalance(
        businessId: businessId,
        customerId: customer.id,
      );

      results.add(_CustomerDebt(customer: customer, balanceMinor: balance));
    }

    return results;
  }
}

class _UdhaarMetricCard extends StatelessWidget {
  const _UdhaarMetricCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
    required this.accent,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final String helper;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      helper,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerDebt {
  const _CustomerDebt({required this.customer, required this.balanceMinor});

  final Customer customer;
  final int balanceMinor;
}

class _CustomerLedgerPanel extends ConsumerWidget {
  const _CustomerLedgerPanel({
    required this.customer,
    required this.businessId,
    required this.money,
  });

  final Customer customer;
  final String businessId;
  final String Function(int) money;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerService = ref.watch(customerLedgerServiceProvider);
    final database = ref.watch(databaseProvider);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<List<Object>>(
          future: Future.wait<Object>([
            ledgerService.getOutstandingBalance(
              businessId: businessId,
              customerId: customer.id,
            ),
            ledgerService.getLedgerEntries(
              businessId: businessId,
              customerId: customer.id,
            ),
            (database.select(database.sales)
                  ..where(
                    (sale) =>
                        sale.businessId.equals(businessId) &
                        sale.customerId.equals(customer.id) &
                        sale.status.equals('completed'),
                  )
                  ..orderBy([(sale) => OrderingTerm.desc(sale.soldAt)]))
                .get(),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            }

            if (snapshot.hasError) {
              return Text('Could not load customer history: ${snapshot.error}');
            }

            final data = snapshot.data!;
            final outstandingBalance = data[0] as int;
            final entries = data[1] as List<LedgerEntry>;
            final sales = data[2] as List<Sale>;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      foregroundColor: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                      child: Text(
                        customer.name.isEmpty
                            ? '?'
                            : customer.name[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (customer.phone?.trim().isNotEmpty == true)
                            Text(
                              customer.phone!.trim(),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Opening Balance'),
                          const SizedBox(height: 4),
                          Text(money(customer.openingBalanceMinor)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current Outstanding'),
                          const SizedBox(height: 4),
                          Text(
                            money(outstandingBalance),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  'Sales History (${sales.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (sales.isEmpty)
                  const Text('No completed sales found for this customer.')
                else
                  ...sales.map(
                    (sale) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Invoice: ${sale.invoiceNumber}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Sale ID: ${sale.id}'),
                            Text('Date: ${sale.soldAt.toLocal()}'),
                            const Divider(),
                            const Text(
                              'Items purchased',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            FutureBuilder<List<SaleItem>>(
                              future:
                                  (database.select(database.saleItems)..where(
                                        (item) => item.saleId.equals(sale.id),
                                      ))
                                      .get(),
                              builder: (context, itemSnapshot) {
                                if (itemSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const LinearProgressIndicator();
                                }

                                if (itemSnapshot.hasError) {
                                  return Text(
                                    'Could not load items: '
                                    '${itemSnapshot.error}',
                                  );
                                }

                                final items = itemSnapshot.data ?? [];

                                if (items.isEmpty) {
                                  return const Text('No sale items found.');
                                }

                                return Column(
                                  children: items.map((item) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${item.productName} Ã— '
                                              '${item.quantity}',
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(money(item.lineTotalMinor)),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                            const Divider(),
                            _amountRow('Sale Total', sale.totalMinor),
                            _amountRow('Amount Paid', sale.paidMinor),
                            _amountRow(
                              'Remaining Due',
                              sale.dueMinor,
                              bold: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const Divider(height: 24),
                Text(
                  'Ledger & Payment History',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (entries.isEmpty)
                  const Text('No ledger entries.')
                else
                  ...entries.map(
                    (entry) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        entry.description?.trim().isNotEmpty == true
                            ? entry.description!
                            : entry.entryType,
                      ),
                      subtitle: Text('${entry.entryAt.toLocal()}'),
                      trailing: Text(
                        '${entry.entryType == 'payment' ? '-' : '+'}'
                        '${money(entry.amountMinor)}',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _amountRow(String label, int amountMinor, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            money(amountMinor),
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
