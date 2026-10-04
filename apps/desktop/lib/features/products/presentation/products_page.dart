import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/business_provider.dart';
import '../../../core/providers/product_provider.dart';
import '../../../core/providers/service_providers.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showProductDialog({
    Product? product,
  }) async {
    final businessId = ref.read(activeBusinessIdProvider);

    if (businessId == null || businessId.isEmpty) {
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return ProductFormDialog(
          businessId: businessId,
          product: product,
        );
      },
    );

    if (saved == true) {
      ref.invalidate(productListProvider);
    }
  }

  Future<void> _showCategoryDialog() async {
    final businessId = ref.read(activeBusinessIdProvider);

    if (businessId == null || businessId.isEmpty) {
      return;
    }

    final controller = TextEditingController();

    try {
      final created = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Add Category'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Category name',
                hintText: 'e.g. Beverages',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = controller.text.trim();

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Category name cannot be empty.',
                        ),
                      ),
                    );
                    return;
                  }

                  try {
                    await ref
                        .read(categoryServiceProvider)
                        .createCategory(
                          businessId: businessId,
                          categoryId: const Uuid().v4(),
                          name: name,
                        );

                    if (context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  } catch (error) {
                    if (!context.mounted) {
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(error.toString()),
                      ),
                    );
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      );

      if (created == true) {
        ref.invalidate(activeCategoryListProvider);
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productListProvider);
    final categoriesAsync = ref.watch(activeCategoryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          OutlinedButton.icon(
            onPressed: _showCategoryDialog,
            icon: const Icon(Icons.category_outlined),
            label: const Text('Add Category'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => _showProductDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Product'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stackTrace) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Unable to load products.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(error.toString()),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          ref.invalidate(productListProvider);
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (products) {
                  final filteredProducts = products.where((product) {
                    if (_searchQuery.isEmpty) {
                      return true;
                    }

                    return product.name.toLowerCase().contains(
                              _searchQuery,
                            ) ||
                        (product.sku?.toLowerCase().contains(
                              _searchQuery,
                            ) ??
                            false);
                  }).toList();

                  if (filteredProducts.isEmpty) {
                    return _EmptyProductsState(
                      hasProducts: products.isNotEmpty,
                      onAddProduct: () => _showProductDialog(),
                    );
                  }

                  return _ProductsTable(
                    products: filteredProducts,
                    categoriesAsync: categoriesAsync,
                    onEdit: (product) {
                      _showProductDialog(product: product);
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
}

class _EmptyProductsState extends StatelessWidget {
  const _EmptyProductsState({
    required this.hasProducts,
    required this.onAddProduct,
  });

  final bool hasProducts;
  final VoidCallback onAddProduct;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasProducts
                ? Icons.search_off
                : Icons.inventory_2_outlined,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            hasProducts
                ? 'No products match your search.'
                : 'No products yet.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (!hasProducts) ...[
            const SizedBox(height: 8),
            const Text(
              'Add your first product to start managing stock.',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAddProduct,
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductsTable extends StatelessWidget {
  const _ProductsTable({
    required this.products,
    required this.categoriesAsync,
    required this.onEdit,
  });

  final List<Product> products;
  final AsyncValue<List<Category>> categoriesAsync;
  final ValueChanged<Product> onEdit;

  @override
  Widget build(BuildContext context) {
    final categories = categoriesAsync.value ?? [];

    final categoryNames = {
      for (final category in categories) category.id: category.name,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Product')),
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('SKU')),
            DataColumn(label: Text('Stock')),
            DataColumn(label: Text('Sale Price')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('')),
          ],
          rows: products.map((product) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    categoryNames[product.categoryId] ??
                        'Unknown',
                  ),
                ),
                DataCell(
                  Text(product.sku ?? '—'),
                ),
                DataCell(
                  Text(product.stockQuantity.toString()),
                ),
                DataCell(
                  Text(
                    _formatMoney(product.salePriceMinor),
                  ),
                ),
                DataCell(
                  _StatusBadge(
                    isActive: product.isActive,
                  ),
                ),
                DataCell(
                  IconButton(
                    tooltip: 'Edit product',
                    onPressed: () => onEdit(product),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatMoney(int minor) {
    final major = minor ~/ 100;
    final decimal = (minor % 100).toString().padLeft(2, '0');

    return 'Rs. $major.$decimal';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.isActive,
  });

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Text(
      isActive ? 'Active' : 'Inactive',
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: isActive
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class ProductFormDialog extends ConsumerStatefulWidget {
  const ProductFormDialog({
    super.key,
    required this.businessId,
    this.product,
  });

  final String businessId;
  final Product? product;

  @override
  ConsumerState<ProductFormDialog> createState() =>
      _ProductFormDialogState();
}

class _ProductFormDialogState
    extends ConsumerState<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _lowStockController;

  String? _selectedCategoryId;
  bool _isActive = true;
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();

    final product = widget.product;

    _nameController = TextEditingController(
      text: product?.name ?? '',
    );

    _skuController = TextEditingController(
      text: product?.sku ?? '',
    );

    _purchasePriceController = TextEditingController(
      text: product == null
          ? ''
          : _formatMajorAmount(product.purchasePriceMinor),
    );

    _salePriceController = TextEditingController(
      text: product == null
          ? ''
          : _formatMajorAmount(product.salePriceMinor),
    );

    _stockController = TextEditingController(
      text: product?.stockQuantity.toString() ?? '0',
    );

    _lowStockController = TextEditingController(
      text: product?.lowStockThreshold.toString() ?? '0',
    );

    _selectedCategoryId = product?.categoryId;
    _isActive = product?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryId == null) {
      _showError('Please select a category.');
      return;
    }

    final purchasePrice = _parseMoney(
      _purchasePriceController.text,
    );

    final salePrice = _parseMoney(
      _salePriceController.text,
    );

    final stock = int.tryParse(
      _stockController.text.trim(),
    );

    final lowStock = int.tryParse(
      _lowStockController.text.trim(),
    );

    if (purchasePrice == null ||
        salePrice == null ||
        stock == null ||
        lowStock == null) {
      _showError('Please enter valid numeric values.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final productService = ref.read(productServiceProvider);

      if (_isEditing) {
        await productService.updateProduct(
          businessId: widget.businessId,
          productId: widget.product!.id,
          categoryId: _selectedCategoryId!,
          name: _nameController.text,
          purchasePriceMinor: purchasePrice,
          salePriceMinor: salePrice,
          stockQuantity: stock,
          lowStockThreshold: lowStock,
          sku: _optionalText(_skuController.text),
          isActive: _isActive,
        );
      } else {
        await productService.createProduct(
          businessId: widget.businessId,
          productId: const Uuid().v4(),
          categoryId: _selectedCategoryId!,
          name: _nameController.text,
          purchasePriceMinor: purchasePrice,
          salePriceMinor: salePrice,
          stockQuantity: stock,
          lowStockThreshold: lowStock,
          sku: _optionalText(_skuController.text),
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String? _optionalText(String value) {
    final trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  int? _parseMoney(String value) {
    final normalized = value.trim().replaceAll(',', '');

    if (normalized.isEmpty) {
      return null;
    }

    final amount = double.tryParse(normalized);

    if (amount == null || amount < 0) {
      return null;
    }

    return (amount * 100).round();
  }

  String _formatMajorAmount(int minor) {
    return (minor / 100).toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(activeCategoryListProvider);

    return AlertDialog(
      title: Text(
        _isEditing ? 'Edit Product' : 'Add Product',
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Product Name *',
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Product name is required.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                categoriesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) => Text(
                    'Unable to load categories: $error',
                  ),
                  data: (categories) {
                    return DropdownButtonFormField<String>(
                      initialValue: categories.any(
                        (category) =>
                            category.id == _selectedCategoryId,
                      )
                          ? _selectedCategoryId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                      ),
                      items: categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category.id,
                          child: Text(category.name),
                        );
                      }).toList(),
                      onChanged: _saving
                          ? null
                          : (value) {
                              setState(() {
                                _selectedCategoryId = value;
                              });
                            },
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _skuController,
                  decoration: const InputDecoration(
                    labelText: 'SKU',
                    hintText: 'Optional',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _purchasePriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Purchase Price *',
                          prefixText: 'Rs. ',
                        ),
                        validator: _moneyValidator,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _salePriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Sale Price *',
                          prefixText: 'Rs. ',
                        ),
                        validator: _moneyValidator,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Opening Stock',
                        ),
                        validator: _integerValidator,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _lowStockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Low Stock Alert',
                        ),
                        validator: _integerValidator,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: _isActive,
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  _isEditing ? 'Save Changes' : 'Save Product',
                ),
        ),
      ],
    );
  }

  String? _moneyValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required.';
    }

    final parsed = _parseMoney(value);

    if (parsed == null) {
      return 'Enter a valid amount.';
    }

    return null;
  }

  String? _integerValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required.';
    }

    final parsed = int.tryParse(value.trim());

    if (parsed == null || parsed < 0) {
      return 'Enter 0 or greater.';
    }

    return null;
  }
}