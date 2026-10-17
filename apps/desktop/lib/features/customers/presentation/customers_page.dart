import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/business_provider.dart';
import '../../../core/providers/customer_provider.dart';
import '../../../core/providers/dashboard_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/services/customer_ledger_service.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  final _searchController = TextEditingController();

  String _searchQuery = '';
  bool _showInactive = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Customer> _filterCustomers(List<Customer> customers) {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return customers;

    return customers.where((customer) {
      return customer.name.toLowerCase().contains(query) ||
          (customer.phone?.toLowerCase().contains(query) ?? false) ||
          (customer.address?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  String _currentBusinessId() {
    final id = ref.read(activeBusinessIdProvider);

    if (id == null || id.isEmpty) {
      throw StateError('No active business selected.');
    }

    return id;
  }

  void _refreshCustomers() {
    ref.invalidate(customerListProvider(false));
    ref.invalidate(customerListProvider(true));
    ref.invalidate(dashboardProvider);
  }

  Future<void> _showCustomerDialog({Customer? customer}) async {
    final nameController = TextEditingController(text: customer?.name ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final addressController = TextEditingController(
      text: customer?.address ?? '',
    );
    final openingBalanceController = TextEditingController(text: '0');

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    bool isActive = customer?.isActive ?? true;

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  customer == null ? 'Add Customer' : 'Edit Customer',
                ),
                content: SizedBox(
                  width: 450,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nameController,
                            autofocus: customer == null,
                            decoration: const InputDecoration(
                              labelText: 'Customer name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Customer name is required.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              hintText: 'Optional',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: addressController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Address',
                              hintText: 'Optional',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          if (customer == null) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: openingBalanceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Opening Balance (PKR)',
                                hintText: '0',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isEmpty) return null;

                                final amount = double.tryParse(text);

                                if (amount == null) {
                                  return 'Enter a valid amount.';
                                }
                                if (amount < 0) {
                                  return 'Opening balance cannot be negative.';
                                }
                                return null;
                              },
                            ),
                          ],
                          if (customer != null) ...[
                            const SizedBox(height: 16),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Active customer'),
                              subtitle: Text(
                                isActive
                                    ? 'Customer is active.'
                                    : 'Customer is inactive.',
                              ),
                              value: isActive,
                              onChanged: isSaving
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        isActive = value;
                                      });
                                    },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;

                            final businessId = ref.read(
                              activeBusinessIdProvider,
                            );

                            if (businessId == null || businessId.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('No active business selected.'),
                                ),
                              );
                              return;
                            }

                            setDialogState(() => isSaving = true);

                            try {
                              final service = ref.read(customerServiceProvider);

                              if (customer == null) {
                                final openingBalance =
                                    double.tryParse(
                                      openingBalanceController.text.trim(),
                                    ) ??
                                    0;

                                await service.createCustomer(
                                  businessId: businessId,
                                  customerId:
                                      'customer-${DateTime.now().microsecondsSinceEpoch}',
                                  name: nameController.text.trim(),
                                  phone: _nullableText(phoneController.text),
                                  address: _nullableText(
                                    addressController.text,
                                  ),
                                  openingBalanceMinor: (openingBalance * 100)
                                      .round(),
                                );
                              } else {
                                await service.updateCustomer(
                                  businessId: businessId,
                                  customerId: customer.id,
                                  name: nameController.text.trim(),
                                  phone: _nullableText(phoneController.text),
                                  address: _nullableText(
                                    addressController.text,
                                  ),
                                  isActive: isActive,
                                );
                              }

                              _refreshCustomers();

                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop(true);
                              }
                            } catch (error) {
                              if (!dialogContext.mounted) return;

                              setDialogState(() => isSaving = false);

                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not save customer: $error',
                                  ),
                                ),
                              );
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            customer == null ? 'Add Customer' : 'Save Changes',
                          ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (saved == true && mounted) {
        _refreshCustomers();
      }
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameController.dispose();
        phoneController.dispose();
        addressController.dispose();
        openingBalanceController.dispose();
      });
    }
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete customer?'),
        content: Text(
          'Delete "${customer.name}"?\n\n'
          'If this customer has sales, payments, or ledger history, '
          'the customer will be deactivated instead to preserve records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final deleted = await ref
          .read(customerServiceProvider)
          .deleteCustomer(
            businessId: _currentBusinessId(),
            customerId: customer.id,
          );

      if (!mounted) return;

      _refreshCustomers();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleted
                ? 'Customer permanently deleted.'
                : 'Customer has transaction history and was deactivated.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete customer: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(customerListProvider(false));
    final inactiveAsync = ref.watch(customerListProvider(true));
    final selectedAsync = _showInactive ? inactiveAsync : activeAsync;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(28, 22, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 800;

                final heading = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customers',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage customer details and account status',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                );

                final addButton = FilledButton.icon(
                  onPressed: () => _showCustomerDialog(),
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Add Customer'),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [heading, const SizedBox(height: 12), addButton],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: heading),
                    addButton,
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Expanded(
              child: selectedAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _CustomersError(
                  message: error.toString(),
                  onRetry: _refreshCustomers,
                ),
                data: (customers) {
                  final filteredCustomers = _filterCustomers(customers);

                  final activeCount = activeAsync.asData?.value.length ?? 0;
                  final inactiveCount = inactiveAsync.asData?.value.length ?? 0;
                  final totalCount = activeCount + inactiveCount;

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 700;
                      final columns = narrow ? 1 : 2;
                      final cardWidth =
                          (constraints.maxWidth - (12 * (columns - 1))) /
                          columns;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: cardWidth,
                                child: _CustomerSummaryCard(
                                  title: 'Total Customers',
                                  value: totalCount.toString(),
                                  subtitle: 'Active and inactive records',
                                  icon: Icons.people_outline,
                                  accent: const Color(0xFF4169E1),
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _CustomerSummaryCard(
                                  title: 'Inactive Customers',
                                  value: inactiveCount.toString(),
                                  subtitle: 'Deactivated customer records',
                                  icon: Icons.person_off_outlined,
                                  accent: const Color(0xFFB54708),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _buildCustomerTable(filteredCustomers),
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

  Widget _buildCustomerTable(List<Customer> customers) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 750;

                final search = SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search name, phone or address...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              icon: const Icon(Icons.close, size: 18),
                            ),
                      contentPadding: EdgeInsets.zero,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                );

                final filters = Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        setState(() => _showInactive = false);
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: !_showInactive
                            ? theme.colorScheme.primaryContainer
                            : null,
                      ),
                      child: const Text('Active'),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        setState(() => _showInactive = true);
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _showInactive
                            ? theme.colorScheme.primaryContainer
                            : null,
                      ),
                      child: const Text('Inactive'),
                    ),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      search,
                      const SizedBox(height: 10),
                      Align(alignment: Alignment.centerLeft, child: filters),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 12),
                    filters,
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: customers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No customers found'
                              : _showInactive
                              ? 'No inactive customers'
                              : 'No customers yet',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Try a different name, phone or address.'
                              : _showInactive
                              ? 'Inactive customers will appear here.'
                              : 'Add your first customer to get started.',
                        ),
                        if (!_showInactive && _searchQuery.isEmpty) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _showCustomerDialog(),
                            icon: const Icon(Icons.person_add_outlined),
                            label: const Text('Add Customer'),
                          ),
                        ],
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        horizontalMargin: 16,
                        columnSpacing: 20,
                        headingRowHeight: 46,
                        dataRowMinHeight: 58,
                        dataRowMaxHeight: 68,
                        columns: const [
                          DataColumn(label: Text('Customer')),
                          DataColumn(label: Text('Address')),
                          DataColumn(label: Text('Phone')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: [
                          for (final customer in customers)
                            DataRow(
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 170,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          child: Text(
                                            customer.name.isEmpty
                                                ? '?'
                                                : customer.name[0]
                                                      .toUpperCase(),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            customer.name,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                DataCell(
                                  SizedBox(
                                    width: 160,
                                    child: Text(
                                      customer.address?.trim().isNotEmpty ==
                                              true
                                          ? customer.address!.trim()
                                          : '-',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),

                                DataCell(
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      customer.phone?.trim().isNotEmpty == true
                                          ? customer.phone!.trim()
                                          : 'â€”',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  _CustomerDebtStatus(
                                    businessId: _currentBusinessId(),
                                    customerId: customer.id,
                                    database: ref.watch(databaseProvider),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit customer',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          _showCustomerDialog(
                                            customer: customer,
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 19,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete customer',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          _deleteCustomer(customer);
                                        },
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 19,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              '${customers.length} customer${customers.length == 1 ? '' : 's'}'
              '${_searchQuery.isNotEmpty ? ' matching search' : ''}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerDebtStatus extends StatelessWidget {
  const _CustomerDebtStatus({
    required this.businessId,
    required this.customerId,
    required this.database,
  });

  final String businessId;
  final String customerId;
  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: CustomerLedgerService(
        database,
      ).getOutstandingBalance(businessId: businessId, customerId: customerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const _StatusPill(
            label: 'Unavailable',
            color: Color(0xFF667085),
          );
        }

        final outstanding = snapshot.data! > 0;

        return _StatusPill(
          label: outstanding ? 'Outstanding' : 'Cleared',
          color: outstanding
              ? const Color(0xFFB42318)
              : const Color(0xFF027A48),
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CustomerSummaryCard extends StatelessWidget {
  const _CustomerSummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 21),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: accent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomersError extends StatelessWidget {
  const _CustomersError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Customers unavailable',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String? _nullableText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
