import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/business_provider.dart';
import '../../../core/providers/customer_provider.dart';
import '../../../core/providers/dashboard_provider.dart';
import '../../../core/providers/product_provider.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/providers/reports_providers.dart';
import '../../../core/services/sale_service.dart';

class SalesPage extends ConsumerStatefulWidget {
  const SalesPage({super.key});

  @override
  ConsumerState<SalesPage> createState() => _SalesPageState();
}

class _CartItem {
  const _CartItem({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  _CartItem copyWith({int? quantity}) {
    return _CartItem(product: product, quantity: quantity ?? this.quantity);
  }

  int get lineTotalMinor => product.salePriceMinor * quantity;
}

class _SalesPageState extends ConsumerState<SalesPage> {
  final _searchController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _paidController = TextEditingController(text: '0');
  final _customerSearchController = TextEditingController();

  String _paymentMethod = 'cash';
  final _paymentReferenceController = TextEditingController();

  final List<_CartItem> _cart = [];

  String? _selectedCustomerId;
  bool _isSaving = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _discountController.dispose();
    _paidController.dispose();
    _customerSearchController.dispose();
    _paymentReferenceController.dispose();
    super.dispose();
  }

  int get _subtotalMinor {
    return _cart.fold(0, (total, item) => total + item.lineTotalMinor);
  }

  int get _discountMinor {
    return _parseAmount(_discountController.text);
  }

  int get _totalMinor {
    final total = _subtotalMinor - _discountMinor;
    return total < 0 ? 0 : total;
  }

  int get _paidMinor {
    return _parseAmount(_paidController.text);
  }

  int get _dueMinor {
    final due = _totalMinor - _paidMinor;
    return due > 0 ? due : 0;
  }

  int get _changeMinor {
    final change = _paidMinor - _totalMinor;
    return change > 0 ? change : 0;
  }

  int _parseAmount(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return 0;
    }

    final parsed = double.tryParse(trimmed);

    if (parsed == null || parsed < 0) {
      return 0;
    }

    return (parsed * 100).round();
  }

  String _formatMoney(int amountMinor) {
    return 'Rs. ${(amountMinor / 100).toStringAsFixed(2)}';
  }

  String _generateSaleId() {
    return 'sale-${DateTime.now().microsecondsSinceEpoch}';
  }

  String _generateInvoiceNumber() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'INV-$timestamp';
  }

  List<Product> _filteredProducts(List<Product> products) {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return products;
    }

    return products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          (product.sku?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  _CartItem? _findCartItem(String productId) {
    for (final item in _cart) {
      if (item.product.id == productId) {
        return item;
      }
    }

    return null;
  }

  void _addProduct(Product product) {
    final existing = _findCartItem(product.id);

    if (existing == null) {
      setState(() {
        _cart.add(_CartItem(product: product, quantity: 1));
      });
      return;
    }

    if (existing.quantity >= product.stockQuantity) {
      _showMessage('Cannot add more ${product.name}. Stock limit reached.');
      return;
    }

    setState(() {
      final index = _cart.indexOf(existing);

      _cart[index] = existing.copyWith(quantity: existing.quantity + 1);
    });
  }

  void _changeQuantity(Product product, int change) {
    final existing = _findCartItem(product.id);
    if (existing == null) return;

    final newQuantity = existing.quantity + change;

    if (newQuantity < 1) {
      _showMessage('Quantity cannot be less than 1. Use × to remove it.');
      return;
    }

    if (newQuantity > product.stockQuantity) {
      _showMessage(
        'Only ${product.stockQuantity} units of '
        '${product.name} are available.',
      );
      return;
    }

    setState(() {
      final index = _cart.indexOf(existing);
      _cart[index] = existing.copyWith(quantity: newQuantity);
    });
  }

  void _removeProduct(Product product) {
    setState(() {
      _cart.removeWhere((item) => item.product.id == product.id);
    });
  }

  Future<void> _completeSale() async {
    final businessId = ref.read(activeBusinessIdProvider);
    final userId = ref.read(activeUserIdProvider);

    if (businessId == null || businessId.isEmpty) {
      _showMessage('No active business selected.');
      return;
    }

    if (userId == null || userId.isEmpty) {
      _showMessage('No active user selected.');
      return;
    }

    if (_cart.isEmpty) {
      _showMessage('Add at least one product to the sale.');
      return;
    }

    if (_discountMinor > _subtotalMinor) {
      _showMessage('Discount cannot exceed the subtotal.');
      return;
    }

    if (_dueMinor > 0 &&
        (_selectedCustomerId == null || _selectedCustomerId!.isEmpty)) {
      _showMessage(
        'Select a customer when the sale has an outstanding balance.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final saleService = ref.read(saleServiceProvider);

      final items = _cart.map((item) {
        return SaleItemRequest(
          productId: item.product.id,
          quantity: item.quantity,
        );
      }).toList();

      await saleService.completeSale(
        businessId: businessId,
        userId: userId,
        saleId: _generateSaleId(),
        invoiceNumber: _generateInvoiceNumber(),
        customerId: _selectedCustomerId,
        discountMinor: _discountMinor,
        paidMinor: _paidMinor > _totalMinor ? _totalMinor : _paidMinor,
        paymentMethod: _paymentMethod,
        paymentReference: _paymentReferenceController.text.trim().isEmpty
            ? null
            : _paymentReferenceController.text.trim(),
        status: 'completed',
        soldAt: DateTime.now(),
        items: items,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _cart.clear();
        _selectedCustomerId = null;
        _discountController.text = '0';
        _paidController.text = '0';
        _paymentMethod = 'cash';
        _paymentReferenceController.clear();
      });

      ref.invalidate(productListProvider);
      ref.invalidate(customerListProvider(false));
      ref.invalidate(dashboardProvider);
      ref.invalidate(salesReportProvider);
      ref.invalidate(topSellingProductsProvider);

      _showMessage('Sale completed successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Could not complete sale: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildProductPanel(List<Product> products) {
    final filteredProducts = _filteredProducts(products);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Products',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AccountCareTheme.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Search products',
                hintText: 'Search by name or SKU',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filteredProducts.isEmpty
                  ? const Center(child: Text('No products found.'))
                  : ListView.separated(
                      itemCount: filteredProducts.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];

                        final cartItem = _findCartItem(product.id);

                        final available =
                            product.stockQuantity - (cartItem?.quantity ?? 0);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          title: Text(
                            product.name,
                            style: const TextStyle(
                              color: AccountCareTheme.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${_formatMoney(product.salePriceMinor)}'
                            '  |  Stock: ${product.stockQuantity}',
                          ),
                          trailing: FilledButton(
                            onPressed: available > 0
                                ? () => _addProduct(product)
                                : null,
                            child: const Text('Add'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartPanel(List<Customer> customers) {
    return Card(
      color: AccountCareTheme.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AccountCareTheme.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Current Sale',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AccountCareTheme.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_cart.length} item types',
                  style: const TextStyle(
                    color: AccountCareTheme.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Compact cart list: this region scrolls independently.
            SizedBox(
              height: 175,
              child: _cart.isEmpty
                  ? const Center(child: Text('No products added yet.'))
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _cart.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, thickness: 0.5),
                      itemBuilder: (context, index) {
                        final item = _cart[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      item.product.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AccountCareTheme.text,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '${_formatMoney(item.product.salePriceMinor)} each',
                                      style: const TextStyle(
                                        color: AccountCareTheme.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 4),

                              // Type a quantity directly, such as 55.

                              // Decrease quantity by one.
                              IconButton(
                                tooltip: 'Decrease quantity',
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                  minWidth: 26,
                                  minHeight: 32,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () =>
                                    _changeQuantity(item.product, -1),
                                icon: const Icon(Icons.remove, size: 17),
                              ),

                              // Enter a quantity directly, then press Enter.
                              SizedBox(
                                width: 48,
                                height: 34,
                                child: TextFormField(
                                  key: ValueKey(
                                    '${item.product.id}-${item.quantity}',
                                  ),
                                  initialValue: '${item.quantity}',
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  style: const TextStyle(fontSize: 13),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                      vertical: 6,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  onFieldSubmitted: (value) {
                                    final quantity = int.tryParse(value);

                                    if (quantity == null || quantity < 1) {
                                      _showMessage(
                                        'Enter a quantity of at least 1.',
                                      );
                                      return;
                                    }

                                    if (quantity > item.product.stockQuantity) {
                                      _showMessage(
                                        'Only ${item.product.stockQuantity} '
                                        'units are in stock.',
                                      );
                                      return;
                                    }

                                    final cartIndex = _cart.indexWhere(
                                      (entry) =>
                                          entry.product.id == item.product.id,
                                    );
                                    if (cartIndex < 0) return;

                                    setState(() {
                                      _cart[cartIndex] = _cart[cartIndex]
                                          .copyWith(quantity: quantity);
                                    });
                                  },
                                ),
                              ),

                              // Increase quantity by one.
                              IconButton(
                                tooltip: 'Increase quantity',
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                  minWidth: 26,
                                  minHeight: 32,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () =>
                                    _changeQuantity(item.product, 1),
                                icon: const Icon(Icons.add, size: 17),
                              ),

                              // Remove the entire product from the cart.
                              IconButton(
                                tooltip: 'Remove product',
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                  minWidth: 26,
                                  minHeight: 32,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () => _removeProduct(item.product),
                                icon: const Icon(
                                  Icons.close,
                                  size: 17,
                                  color: AccountCareTheme.red,
                                ),
                              ),

                              const SizedBox(width: 8),
                              SizedBox(
                                width: 88,
                                child: Text(
                                  _formatMoney(item.lineTotalMinor),
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            const Divider(height: 12),

            // These controls scroll independently of the fixed totals.
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_dueMinor > 0) ...[
                      const Text(
                        'Customer',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _customerSearchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Search by name or phone',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _customerSearchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    setState(_customerSearchController.clear);
                                  },
                                  icon: const Icon(Icons.clear, size: 18),
                                ),
                        ),
                      ),
                      if (_selectedCustomerId != null)
                        ...customers
                            .where((c) => c.id == _selectedCustomerId)
                            .map(
                              (customer) => ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.person, size: 20),
                                title: Text(
                                  customer.name,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: customer.phone == null
                                    ? null
                                    : Text(customer.phone!),
                                trailing: IconButton(
                                  tooltip: 'Change customer',
                                  onPressed: () {
                                    setState(() {
                                      _selectedCustomerId = null;
                                      _customerSearchController.clear();
                                    });
                                  },
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                              ),
                            ),
                      Builder(
                        builder: (context) {
                          final query = _customerSearchController.text
                              .trim()
                              .toLowerCase();

                          if (query.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          final matches = customers
                              .where((customer) {
                                return customer.name.toLowerCase().contains(
                                      query,
                                    ) ||
                                    (customer.phone?.toLowerCase() ?? '')
                                        .contains(query);
                              })
                              .take(5)
                              .toList();

                          if (matches.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                'No matching customer found.',
                                style: TextStyle(fontSize: 12),
                              ),
                            );
                          }

                          return Column(
                            children: matches.map((customer) {
                              return ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.person_outline,
                                  size: 20,
                                ),
                                title: Text(
                                  customer.name,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: customer.phone == null
                                    ? null
                                    : Text(customer.phone!),
                                onTap: () {
                                  setState(() {
                                    _selectedCustomerId = customer.id;
                                    _customerSearchController.clear();
                                  });
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final customerId = await _showAddCustomerDialog();
                          if (customerId == null || !mounted) return;

                          setState(() {
                            _selectedCustomerId = customerId;
                            _customerSearchController.clear();
                          });
                        },
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Add New Customer'),
                      ),
                      const SizedBox(height: 8),
                    ],

                    TextField(
                      controller: _discountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          final value = newValue.text;
                          return value.isEmpty ||
                                  RegExp(r'^\d*\.?\d{0,2}$').hasMatch(value)
                              ? newValue
                              : oldValue;
                        }),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Discount (PKR)',
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: _paidController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          final value = newValue.text;
                          return value.isEmpty ||
                                  RegExp(r'^\d*\.?\d{0,2}$').hasMatch(value)
                              ? newValue
                              : oldValue;
                        }),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Paid (PKR)',
                      ),
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      isDense: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Payment Method',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(
                          value: 'bank_transfer',
                          child: Text('Bank Transfer'),
                        ),
                        DropdownMenuItem(
                          value: 'easypaisa',
                          child: Text('Easypaisa'),
                        ),
                        DropdownMenuItem(
                          value: 'jazzcash',
                          child: Text('JazzCash'),
                        ),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _paymentMethod = value;
                          if (value == 'cash') {
                            _paymentReferenceController.clear();
                          }
                        });
                      },
                    ),

                    if (_paymentMethod != 'cash') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _paymentReferenceController,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Payment Reference (optional)',
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // Totals and checkout remain visible while the cart scrolls.
            const Divider(height: 12),
            _summaryRow('Subtotal', _formatMoney(_subtotalMinor)),
            _summaryRow('Discount', _formatMoney(_discountMinor)),
            _summaryRow('Total', _formatMoney(_totalMinor), bold: true),
            _summaryRow('Paid', _formatMoney(_paidMinor)),
            _summaryRow(
              _changeMinor > 0 ? 'Change to return' : 'Due',
              _formatMoney(_changeMinor > 0 ? _changeMinor : _dueMinor),
              bold: true,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _completeSale,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.point_of_sale),
                label: Text(_isSaving ? 'Completing Sale...' : 'Complete Sale'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    final style = bold
        ? const TextStyle(
            color: AccountCareTheme.text,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          )
        : const TextStyle(color: AccountCareTheme.muted, fontSize: 13);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }

  Future<String?> _showAddCustomerDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          bool isSaving = false;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Add New Customer'),
                content: SizedBox(
                  width: 420,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          autofocus: true,
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
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: addressController,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
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
                              final customerId =
                                  'customer-${DateTime.now().microsecondsSinceEpoch}';

                              final customerService = ref.read(
                                customerServiceProvider,
                              );

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
                              );

                              ref.invalidate(customerListProvider(false));

                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop(customerId);
                              }
                            } catch (error) {
                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  isSaving = false;
                                });

                                ScaffoldMessenger.of(dialogContext)
                                    .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Could not add customer: $error',
                                        ),
                                      ),
                                    );
                              }
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add Customer'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameController.dispose();
        phoneController.dispose();
        addressController.dispose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productListProvider);
    final customersAsync = ref.watch(customerListProvider(false));

    return Scaffold(
      appBar: AppBar(title: const Text('New Sale')),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load products: $error'),
          ),
        ),
        data: (products) {
          return customersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load customers: $error'),
              ),
            ),
            data: (customers) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  // Keep the original desktop POS layout whenever
                  // the content area has enough room.
                  final desktopLayout = constraints.maxWidth >= 700;

                  if (desktopLayout) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildProductPanel(products),
                          ),
                          const SizedBox(width: 20),
                          Expanded(flex: 4, child: _buildCartPanel(customers)),
                        ],
                      ),
                    );
                  }

                  // Only use the fallback layout when the window
                  // is genuinely too small for the desktop POS.
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 500,
                          child: _buildProductPanel(products),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 760,
                          child: _buildCartPanel(customers),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
