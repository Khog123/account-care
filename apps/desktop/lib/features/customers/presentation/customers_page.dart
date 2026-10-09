import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/business_provider.dart';
import '../../../core/providers/customer_provider.dart';
import '../../../core/providers/service_providers.dart';

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

    if (query.isEmpty) {
      return customers;
    }

    return customers.where((customer) {
      final name = customer.name.toLowerCase();
      final phone = customer.phone?.toLowerCase() ?? '';
      final address = customer.address?.toLowerCase() ?? '';

      return name.contains(query) ||
          phone.contains(query) ||
          address.contains(query);
    }).toList();
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

                                if (text.isEmpty) {
                                  return null;
                                }

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
                        : () {
                            Navigator.of(dialogContext).pop(false);
                          },
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }

                            final businessId = ref.read(
                              activeBusinessIdProvider,
                            );

                            if (businessId == null || businessId.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No active business selected.'),
                                ),
                              );
                              return;
                            }

                            setDialogState(() {
                              isSaving = true;
                            });

                            try {
                              final customerService = ref.read(
                                customerServiceProvider,
                              );

                              if (customer == null) {
                                final customerId =
                                    'customer-${DateTime.now().microsecondsSinceEpoch}';

                                final openingBalance =
                                    double.tryParse(
                                      openingBalanceController.text.trim(),
                                    ) ??
                                    0;

                                await customerService.createCustomer(
                                  businessId: businessId,
                                  customerId: customerId,
                                  name: nameController.text,
                                  phone: phoneController.text.trim().isEmpty
                                      ? null
                                      : phoneController.text.trim(),
                                  address: addressController.text.trim().isEmpty
                                      ? null
                                      : addressController.text.trim(),
                                  openingBalanceMinor: (openingBalance * 100)
                                      .round(),
                                );
                              } else {
                                await customerService.updateCustomer(
                                  businessId: businessId,
                                  customerId: customer.id,
                                  name: nameController.text,
                                  phone: phoneController.text.trim().isEmpty
                                      ? null
                                      : phoneController.text.trim(),
                                  address: addressController.text.trim().isEmpty
                                      ? null
                                      : addressController.text.trim(),
                                  isActive: isActive,
                                );
                              }

                              ref.invalidate(
                                customerListProvider(_showInactive),
                              );

                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop(true);
                              }
                            } catch (error) {
                              if (!dialogContext.mounted) {
                                return;
                              }

                              setDialogState(() {
                                isSaving = false;
                              });

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
        ref.invalidate(customerListProvider(_showInactive));
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

    if (confirmed != true || !mounted) {
      return;
    }

    final businessId = ref.read(activeBusinessIdProvider);

    if (businessId == null || businessId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active business selected.')),
      );
      return;
    }

    try {
      final permanentlyDeleted = await ref
          .read(customerServiceProvider)
          .deleteCustomer(businessId: businessId, customerId: customer.id);

      if (!mounted) {
        return;
      }

      ref.invalidate(customerListProvider(false));
      ref.invalidate(customerListProvider(true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            permanentlyDeleted
                ? 'Customer permanently deleted.'
                : 'Customer has transaction history and was deactivated.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete customer: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider(_showInactive));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(customerListProvider(_showInactive));
            },
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: customersAsync.when(
          loading: () {
            return const Center(child: CircularProgressIndicator());
          },
          error: (error, stackTrace) {
            return _CustomersError(
              message: error.toString(),
              onRetry: () {
                ref.invalidate(customerListProvider(_showInactive));
              },
            );
          },
          data: (customers) {
            final filteredCustomers = _filterCustomers(customers);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Search customers',
                          hintText: 'Search by name, phone or address',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();

                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: () {
                        _showCustomerDialog();
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Customer'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Show inactive'),
                      selected: _showInactive,
                      onSelected: (value) {
                        setState(() {
                          _showInactive = value;
                        });
                      },
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${filteredCustomers.length} customer'
                      '${filteredCustomers.length == 1 ? '' : 's'}',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: filteredCustomers.isEmpty
                      ? _CustomersEmptyState(
                          hasSearch: _searchQuery.isNotEmpty,
                          onAddCustomer: () {
                            _showCustomerDialog();
                          },
                        )
                      : Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              _CustomerTableHeader(),
                              const Divider(height: 1),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: filteredCustomers.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final customer = filteredCustomers[index];

                                    return _CustomerTableRow(
                                      customer: customer,
                                      onEdit: () {
                                        _showCustomerDialog(customer: customer);
                                      },
                                      onDelete: () {
                                        _deleteCustomer(customer);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
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
}

class _CustomerTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Row(
        children: [
          Expanded(
            flex: 3,
            child: Text('Name', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 4,
            child: Text(
              'Address',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text('Phone', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 160,
            child: Text(
              'Actions',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerTableRow extends StatelessWidget {
  const _CustomerTableRow({
    required this.customer,
    required this.onEdit,
    required this.onDelete,
  });

  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  child: Text(
                    customer.name.isEmpty
                        ? '?'
                        : customer.name[0].toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          customer.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!customer.isActive) ...[
                        const SizedBox(width: 8),
                        const Chip(
                          label: Text('Inactive'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              customer.address?.trim().isNotEmpty == true
                  ? customer.address!.trim()
                  : '—',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              customer.phone?.trim().isNotEmpty == true
                  ? customer.phone!.trim()
                  : '—',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 160,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Edit customer',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete customer',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomersEmptyState extends StatelessWidget {
  const _CustomersEmptyState({
    required this.hasSearch,
    required this.onAddCustomer,
  });

  final bool hasSearch;
  final VoidCallback onAddCustomer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, size: 56),
          const SizedBox(height: 16),
          Text(
            hasSearch ? 'No customers found' : 'No customers yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? 'Try a different name, phone or address.'
                : 'Add your first customer to get started.',
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAddCustomer,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Customer'),
            ),
          ],
        ],
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
