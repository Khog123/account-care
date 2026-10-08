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
  final TextEditingController _searchController = TextEditingController();

  bool _showArchived = false;
  String? _processingProductId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  Future<void> _showAddProductDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ProductFormDialog(
        businessId: _currentBusinessId(),
      ),
    );

    if (saved == true && mounted) {
      ref.invalidate(productListProvider);
      ref.invalidate(archivedProductListProvider);
    }
  }

  Future<void> _showEditProductDialog(Product product) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ProductFormDialog(
        businessId: _currentBusinessId(),
        product: product,
      ),
    );

    if (saved == true && mounted) {
      ref.invalidate(productListProvider);
      ref.invalidate(archivedProductListProvider);
    }
  }

    Future<void> _showAdjustStockDialog(Product product) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StockAdjustmentDialog(
        businessId: _currentBusinessId(),
        product: product,
      ),
    );

    if (saved == true && mounted) {
      ref.invalidate(productListProvider);
      ref.invalidate(archivedProductListProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock updated for "${product.name}".'),
        ),
      );
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final businessId = _currentBusinessId();
    final controller = TextEditingController();

    try {
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Add Category'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Category name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                final trimmed = value.trim();
                if (trimmed.isNotEmpty) {
                  Navigator.of(dialogContext).pop(trimmed);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final trimmed = controller.text.trim();
                  if (trimmed.isNotEmpty) {
                    Navigator.of(dialogContext).pop(trimmed);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      );

      if (name == null || name.trim().isEmpty || !mounted) {
        return;
      }

      final categoryService = ref.read(categoryServiceProvider);

      await categoryService.createCategory(
        businessId: businessId,
        categoryId: const Uuid().v4(),
        name: name.trim(),
      );

      ref.invalidate(activeCategoryListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "${name.trim()}" added successfully.'),
          ),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _archiveProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: Text(
            '"${product.name}" will be removed from the active product list. '
            'Its sales and historical records will remain safe.',
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
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _processingProductId = product.id;
    });

    try {
      final productService = ref.read(productServiceProvider);

      await productService.deactivateProduct(
        businessId: _currentBusinessId(),
        productId: product.id,
      );

      ref.invalidate(productListProvider);
      ref.invalidate(archivedProductListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${product.name}" was deleted.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not delete product: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingProductId = null;
        });
      }
    }
  }

  Future<void> _restoreProduct(Product product) async {
    setState(() {
      _processingProductId = product.id;
    });

    try {
      final productService = ref.read(productServiceProvider);

      await productService.restoreProduct(
        businessId: _currentBusinessId(),
        productId: product.id,
      );

      ref.invalidate(productListProvider);
      ref.invalidate(archivedProductListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${product.name}" was restored.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not restore product: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingProductId = null;
        });
      }
    }
  }

  String _currentBusinessId() {
    final businessId = ref.read(activeBusinessIdProvider);

    if (businessId == null || businessId.isEmpty) {
      throw StateError('No active business selected.');
    }

    return businessId;
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = _showArchived
        ? ref.watch(archivedProductListProvider)
        : ref.watch(productListProvider);

    final query = _searchController.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _showArchived ? null : _showAddProductDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      icon: Icon(Icons.inventory_2_outlined),
                      label: Text('Active'),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      icon: Icon(Icons.archive_outlined),
                      label: Text('Archived'),
                    ),
                  ],
                  selected: {_showArchived},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _showArchived = selection.first;
                      _searchController.clear();
                    });
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: _showArchived
                          ? 'Search archived products...'
                          : 'Search products...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: _searchController.clear,
                              icon: const Icon(Icons.clear),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _showArchived ? null : _showAddCategoryDialog,
                  icon: const Icon(Icons.category_outlined),
                  label: const Text('Add Category'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stackTrace) => _ProductsErrorState(
                  error: error,
                  onRetry: () {
                    if (_showArchived) {
                      ref.invalidate(archivedProductListProvider);
                    } else {
                      ref.invalidate(productListProvider);
                    }
                  },
                ),
                data: (products) {
                  final filteredProducts = products.where((product) {
                    if (query.isEmpty) {
                      return true;
                    }

                    return product.name.toLowerCase().contains(query) ||
                        (product.sku?.toLowerCase().contains(query) ?? false);
                  }).toList();

                  if (filteredProducts.isEmpty) {
                    return _EmptyProductsState(
                      archived: _showArchived,
                      hasSearch: query.isNotEmpty,
                      onAddProduct:
                          _showArchived ? null : _showAddProductDialog,
                    );
                  }

                    return _ProductsTable(
                    products: filteredProducts,
                    processingProductId: _processingProductId,
                    onEdit: _showArchived ? null : _showEditProductDialog,
                    onAdjustStock:
                    _showArchived ? null : _showAdjustStockDialog,
                    onDelete: _showArchived ? null : _archiveProduct,
                    onRestore: _showArchived ? _restoreProduct : null,
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

class _ProductsTable extends StatelessWidget {
    const _ProductsTable({
    required this.products,
    required this.processingProductId,
    required this.onEdit,
    required this.onAdjustStock,
    required this.onDelete,
    required this.onRestore,
  });

  final List<Product> products;
  final String? processingProductId;
  final ValueChanged<Product>? onEdit;  
  final ValueChanged<Product>? onAdjustStock;
  final ValueChanged<Product>? onDelete;
  final ValueChanged<Product>? onRestore;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 52,
            dataRowMinHeight: 64,
            dataRowMaxHeight: 72,
            columns: const [
              DataColumn(label: Text('Product')),
              DataColumn(label: Text('SKU')),
              DataColumn(label: Text('Purchase Price')),
              DataColumn(label: Text('Sale Price')),
              DataColumn(label: Text('Stock')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: products.map((product) {
              final processing = processingProductId == product.id;

              return DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 220,
                      child: Text(
                        product.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(product.sku?.trim().isNotEmpty == true
                        ? product.sku!
                        : '-'),
                  ),
                  DataCell(
                    Text(_formatMoney(product.purchasePriceMinor)),
                  ),
                  DataCell(
                    Text(_formatMoney(product.salePriceMinor)),
                  ),
                  DataCell(
                    Text(
                      product.stockQuantity == 0
                          ? '0 (Out of Stock)'
                          : product.stockQuantity.toString(),
                    ),
                  ),
                  DataCell(
                    _StatusBadge(
                      text: product.stockQuantity == 0
                          ? 'Out of Stock'
                          : product.stockQuantity <=
                                  product.lowStockThreshold
                              ? 'Low Stock'
                              : 'In Stock',
                    ),
                  ),
                  DataCell(
                    processing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (onEdit != null)
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () => onEdit!(product),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              if (onAdjustStock != null)
                                IconButton(
                                  tooltip: 'Adjust Stock',
                                  onPressed: () =>
                                      onAdjustStock!(product),
                                  icon: const Icon(
                                    Icons.inventory_rounded,
                                  ),
                                ),
                              if (onDelete != null)
                                IconButton(
                                  tooltip: 'Delete',
                                  onPressed: () => onDelete!(product),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                  ),
                                ),
                              if (onRestore != null)
                                IconButton(
                                  tooltip: 'Restore',
                                  onPressed: () => onRestore!(product),
                                  icon: const Icon(
                                    Icons.restore_outlined,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium,
      ),
    );
  }
}

class _EmptyProductsState extends StatelessWidget {
  const _EmptyProductsState({
    required this.archived,
    required this.hasSearch,
    required this.onAddProduct,
  });

  final bool archived;
  final bool hasSearch;
  final VoidCallback? onAddProduct;

  @override
  Widget build(BuildContext context) {
    String title;
    String message;

    if (hasSearch) {
      title = 'No products found';
      message = 'Try a different product name or SKU.';
    } else if (archived) {
      title = 'No archived products';
      message = 'Products that you delete will appear here.';
    } else {
      title = 'No products yet';
      message = 'Add your first product to start managing inventory.';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            archived
                ? Icons.archive_outlined
                : Icons.inventory_2_outlined,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(message),
          if (onAddProduct != null && !hasSearch) ...[
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

class _ProductsErrorState extends StatelessWidget {
  const _ProductsErrorState({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 56,
          ),
          const SizedBox(height: 16),
          const Text('Could not load products.'),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
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

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _lowStockController;

  String? _categoryId;
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
          : _formatMinorInput(product.purchasePriceMinor),
    );
    _salePriceController = TextEditingController(
      text: product == null
          ? ''
          : _formatMinorInput(product.salePriceMinor),
    );
      _stockController = TextEditingController(
        text: '0',
      );
    _lowStockController = TextEditingController(
      text: product?.lowStockThreshold.toString() ?? '0',
    );
    _categoryId = product?.categoryId;
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

    final categoryId = _categoryId;

    if (categoryId == null || categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category.'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final productService = ref.read(productServiceProvider);
      final inventoryService = ref.read(inventoryServiceProvider);

      final purchasePriceMinor = _parseMoneyToMinor(
        _purchasePriceController.text,
      );
      final salePriceMinor = _parseMoneyToMinor(
        _salePriceController.text,
      );
      final lowStockThreshold = int.parse(
        _lowStockController.text.trim(),
      );

      if (_isEditing) {
        await productService.updateProduct(
          businessId: widget.businessId,
          productId: widget.product!.id,
          categoryId: categoryId,
          name: _nameController.text.trim(),
          sku: _nullableText(_skuController.text),
          purchasePriceMinor: purchasePriceMinor,
          salePriceMinor: salePriceMinor,
          lowStockThreshold: lowStockThreshold,
          isActive: true,
        );
      } else {
        final productId = const Uuid().v4();

        await productService.createProduct(
          businessId: widget.businessId,
          productId: productId,
          categoryId: categoryId,
          name: _nameController.text.trim(),
          sku: _nullableText(_skuController.text),
          purchasePriceMinor: purchasePriceMinor,
          salePriceMinor: salePriceMinor,
          lowStockThreshold: lowStockThreshold,
        );

        final openingStock = int.parse(
          _stockController.text.trim(),
        );

        if (openingStock > 0) {
          await inventoryService.addStock(
            businessId: widget.businessId,
            productId: productId,
            quantity: openingStock,
            movementType: 'initial_stock',
            movementAt: DateTime.now(),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save product: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(activeCategoryListProvider);

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Product name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Product name is required.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: categoriesAsync.when(
                        loading: () => const InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          child: SizedBox(
                            height: 24,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        error: (error, stackTrace) => InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            'Could not load categories: $error',
                          ),
                        ),
                        data: (categories) {
                          return DropdownButtonFormField<String>(
                            initialValue: categories.any(
                              (category) => category.id == _categoryId,
                            )
                                ? _categoryId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                            items: categories
                                .map(
                                  (category) => DropdownMenuItem<String>(
                                    value: category.id,
                                    child: Text(category.name),
                                  ),
                                )
                                .toList(),
                            onChanged: _saving
                                ? null
                                : (value) {
                                    setState(() {
                                      _categoryId = value;
                                    });
                                  },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Select a category.';
                              }

                              return null;
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 180,
                      child: TextFormField(
                        controller: _skuController,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'SKU',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _purchasePriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Purchase price (PKR)',
                          prefixText: 'Rs. ',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateMoney,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _salePriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Sale price (PKR)',
                          prefixText: 'Rs. ',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateMoney,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                                       if (!_isEditing)
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Opening stock',
                            border: OutlineInputBorder(),
                            helperText:
                                'Recorded as initial inventory.',
                          ),
                          validator: _validateWholeNumber,
                        ),
                      ),
                    if (!_isEditing) const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lowStockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Low stock alert at',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateWholeNumber,
                      ),
                    ),
                  ],
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Current stock',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        widget.product!.stockQuantity.toString(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Use Adjust Stock to change inventory quantity.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'A product stays active even when its stock reaches zero.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : Text(_isEditing ? 'Save Changes' : 'Add Product'),
        ),
      ],
    );
  }
}

class StockAdjustmentDialog extends ConsumerStatefulWidget {
  const StockAdjustmentDialog({
    super.key,
    required this.businessId,
    required this.product,
  });

  final String businessId;
  final Product product;

  @override
  ConsumerState<StockAdjustmentDialog> createState() =>
      _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState
    extends ConsumerState<StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _quantityController;
  late final TextEditingController _referenceController;
  late final TextEditingController _notesController;

  bool _addStock = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _quantityController = TextEditingController();
    _referenceController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final inventoryService = ref.read(inventoryServiceProvider);

      final quantity = int.parse(
        _quantityController.text.trim(),
      );

      if (_addStock) {
        await inventoryService.addStock(
          businessId: widget.businessId,
          productId: widget.product.id,
          quantity: quantity,
          movementType: 'stock_adjustment_add',
          movementAt: DateTime.now(),
          reference: _nullableText(_referenceController.text),
          notes: _nullableText(_notesController.text),
        );
      } else {
        await inventoryService.removeStock(
          businessId: widget.businessId,
          productId: widget.product.id,
          quantity: quantity,
          movementType: 'stock_adjustment_remove',
          movementAt: DateTime.now(),
          reference: _nullableText(_referenceController.text),
          notes: _nullableText(_notesController.text),
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not adjust stock: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Adjust Stock'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current stock: ${widget.product.stockQuantity}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      icon: Icon(Icons.add),
                      label: Text('Add Stock'),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      icon: Icon(Icons.remove),
                      label: Text('Remove Stock'),
                    ),
                  ],
                  selected: {_addStock},
                  onSelectionChanged: _saving
                      ? null
                      : (selection) {
                          setState(() {
                            _addStock = selection.first;
                          });
                        },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validatePositiveWholeNumber,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _referenceController,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Reference (optional)',
                    hintText: 'e.g. Purchase invoice #123',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _notesController,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
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
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : Text(_addStock ? 'Add Stock' : 'Remove Stock'),
        ),
      ],
    );
  }
}

String? _nullableText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _validateMoney(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required.';
  }

  final amount = double.tryParse(value.trim());

  if (amount == null) {
    return 'Enter a valid amount.';
  }

  if (amount < 0) {
    return 'Cannot be negative.';
  }

  return null;
}

String? _validateWholeNumber(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required.';
  }

  final number = int.tryParse(value.trim());

  if (number == null) {
    return 'Enter a whole number.';
  }

  if (number < 0) {
    return 'Cannot be negative.';
  }

  return null;
}

String? _validatePositiveWholeNumber(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required.';
  }

  final number = int.tryParse(value.trim());

  if (number == null) {
    return 'Enter a whole number.';
  }

  if (number <= 0) {
    return 'Enter a quantity greater than zero.';
  }

  return null;
}

int _parseMoneyToMinor(String value) {
  final amount = double.parse(value.trim());
  return (amount * 100).round();
}

String _formatMinorInput(int amountMinor) {
  final major = amountMinor ~/ 100;
  final decimal = (amountMinor % 100).abs().toString().padLeft(2, '0');
  return '$major.$decimal';
}

String _formatMoney(int amountMinor) {
  final major = amountMinor ~/ 100;
  final decimal = (amountMinor % 100).abs().toString().padLeft(2, '0');
  return 'Rs. $major.$decimal';
}

