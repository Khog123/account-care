import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../core/database/app_database.dart';
import '../../../core/providers/business_provider.dart';
import '../../../core/providers/customer_provider.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/providers/database_provider.dart';

class UdhaarPage extends ConsumerStatefulWidget {
  const UdhaarPage({super.key});

  @override
  ConsumerState<UdhaarPage> createState() => _UdhaarPageState();
}

class _UdhaarPageState extends ConsumerState<UdhaarPage> {
  final _searchController = TextEditingController();

  String _searchQuery = '';
  Customer? _selectedCustomer;
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

      final saveLocation = await getSaveLocation(
        suggestedName:
            'account_care_${customer.name.replaceAll(RegExp(r'[^\w-]+'), '_')}_history_${DateTime.now().toIso8601String().substring(0, 10)}.xlsx',
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Udhaar'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(customerListProvider(false));
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search customers',
                hintText: 'Name or phone number',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: customersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load customers.'),
                      const SizedBox(height: 8),
                      Text(error.toString()),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () {
                          ref.invalidate(customerListProvider(false));
                        },
                        child: const Text('Retry'),
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

                  return FutureBuilder<List<_CustomerDebt>>(
                    key: ValueKey(
                      '${businessId}_${customers.length}_${customers.map((c) => c.id).join(",")}',
                    ),
                    future: _loadDebts(
                      customers: customers,
                      businessId: businessId,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Could not calculate customer balances:\n'
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      final allDebts = snapshot.data ?? [];
                      final query = _searchQuery.trim().toLowerCase();

                      final allDebtors = allDebts
                          .where((debt) => debt.balanceMinor > 0)
                          .toList();

                      final debts = allDebtors.where((debt) {
                        final customer = debt.customer;
                        return customer.name.toLowerCase().contains(query) ||
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
                            (debt) => debt.customer.id == _selectedCustomer?.id,
                          )
                          .map((debt) => debt.customer)
                          .firstOrNull;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Total Outstanding'),
                                        const SizedBox(height: 4),
                                        Text(
                                          _money(totalDebt),
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${allDebtors.length} customers'),
                                      const SizedBox(width: 12),

                                      FilledButton.icon(
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
                                            : const Icon(Icons.download),
                                        label: Text(
                                          _isExportingDebtors
                                              ? 'Exporting...'
                                              : 'Download All Debtors',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Left panel: customer list.
                                Expanded(
                                  flex: 2,
                                  child: debts.isEmpty
                                      ? const Card(
                                          child: Center(
                                            child: Text(
                                              'No outstanding customer debt found.',
                                            ),
                                          ),
                                        )
                                      : Card(
                                          clipBehavior: Clip.antiAlias,
                                          child: ListView.separated(
                                            itemCount: debts.length,
                                            separatorBuilder: (_, _) =>
                                                const Divider(height: 1),
                                            itemBuilder: (context, index) {
                                              final debt = debts[index];
                                              final selected =
                                                  _selectedCustomer?.id ==
                                                  debt.customer.id;

                                              return ListTile(
                                                selected: selected,
                                                leading: CircleAvatar(
                                                  child: Text(
                                                    debt.customer.name.isEmpty
                                                        ? '?'
                                                        : debt.customer.name[0]
                                                              .toUpperCase(),
                                                  ),
                                                ),
                                                title: Text(debt.customer.name),
                                                subtitle: Text(
                                                  debt.customer.phone ??
                                                      'No phone',
                                                ),

                                                trailing: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      tooltip: 'Export customer history',
                                                      onPressed:
                                                          _exportingCustomerIds
                                                              .contains(
                                                                debt
                                                                    .customer
                                                                    .id,
                                                              )
                                                          ? null
                                                          : () =>
                                                                _exportCustomerHistory(
                                                                  customer: debt
                                                                      .customer,
                                                                  businessId:
                                                                      businessId,
                                                                ),
                                                      icon:
                                                          _exportingCustomerIds
                                                              .contains(
                                                                debt
                                                                    .customer
                                                                    .id,
                                                              )
                                                          ? const SizedBox(
                                                              width: 18,
                                                              height: 18,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                  ),
                                                            )
                                                          : const Icon(
                                                              Icons
                                                                  .download_outlined,
                                                            ),
                                                    ),
                                                    Text(
                                                      _money(debt.balanceMinor),
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
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
                                ),
                                const SizedBox(width: 16),

                                // Right panel: selected customer's history.
                                Expanded(
                                  flex: 3,
                                  child: selectedCustomer == null
                                      ? const Card(
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.receipt_long_outlined,
                                                  size: 48,
                                                ),
                                                SizedBox(height: 12),
                                                Text(
                                                  'Select a customer',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Their sales and payment history '
                                                  'will appear here.',
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : SingleChildScrollView(
                                          child: _CustomerLedgerPanel(
                                            customer: _selectedCustomer!,
                                            businessId: businessId,
                                            money: _money,
                                          ),
                                        ),
                                ),
                              ],
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
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                Text(
                  'Customer: ${customer.name}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
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
                                              '${item.productName} × '
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
