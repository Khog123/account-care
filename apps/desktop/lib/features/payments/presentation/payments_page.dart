import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/business_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/providers/customer_provider.dart';
import '../../../core/providers/dashboard_provider.dart';

class PaymentsPage extends ConsumerStatefulWidget {
  const PaymentsPage({super.key});

  @override
  ConsumerState<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends ConsumerState<PaymentsPage> {
  Future<List<_PaymentRow>>? _paymentsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final businessId = ref.read(activeBusinessIdProvider);
    if (businessId == null || businessId.isEmpty) {
      setState(() => _paymentsFuture = Future.value([]));
      return;
    }

    final database = ref.read(databaseProvider);
    setState(() {
      _paymentsFuture = _loadPayments(database, businessId);
    });
  }

  Future<List<_PaymentRow>> _loadPayments(
    AppDatabase database,
    String businessId,
  ) async {
    final payments =
        await (database.select(database.payments)
              ..where((p) => p.businessId.equals(businessId))
              ..orderBy([
                (p) => OrderingTerm.desc(p.paidAt),
                (p) => OrderingTerm.desc(p.createdAt),
              ]))
            .get();

    final customers = await (database.select(
      database.customers,
    )..where((c) => c.businessId.equals(businessId))).get();

    final names = {
      for (final customer in customers) customer.id: customer.name,
    };

    return payments
        .map(
          (payment) => _PaymentRow(
            payment: payment,
            customerName: names[payment.customerId] ?? 'Unknown customer',
          ),
        )
        .toList();
  }

  String _money(int minor) {
    final value = minor / 100;
    return 'Rs. ${value.toStringAsFixed(2)}';
  }

  int? _parseAmountMinor(String input) {
    final text = input.trim();

    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(text)) {
      return null;
    }

    final parts = text.split('.');
    final rupees = int.tryParse(parts[0]);
    final paisa = parts.length == 1
        ? 0
        : int.tryParse(parts[1].padRight(2, '0'));

    if (rupees == null || paisa == null || rupees > 90000000000000) {
      return null;
    }

    final minor = rupees * 100 + paisa;
    if (minor > 9000000000000000) return null;

    return minor;
  }

  String _date(DateTime date) {
    final local = date.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    return '$d/$m/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showRecordPaymentDialog() async {
    final businessId = ref.read(activeBusinessIdProvider);
    final userId = ref.read(activeUserIdProvider);

    if (businessId == null || businessId.isEmpty) {
      _message('Select a business before recording a payment.');
      return;
    }
    if (userId == null || userId.isEmpty) {
      _message('No active user is available. Please sign in again.');
      return;
    }

    try {
      final database = ref.read(databaseProvider);
      final customers =
          await (database.select(database.customers)
                ..where(
                  (c) =>
                      c.businessId.equals(businessId) & c.isActive.equals(true),
                )
                ..orderBy([(c) => OrderingTerm.asc(c.name)]))
              .get();

      if (!mounted) return;

      if (customers.isEmpty) {
        _message('Add an active customer before recording a payment.');
        return;
      }

      final formKey = GlobalKey<FormState>();
      final amountController = TextEditingController();
      final referenceController = TextEditingController();

      String? selectedCustomerId;
      String method = 'Cash';
      int balanceMinor = 0;
      bool loadingBalance = false;
      bool balanceLoadFailed = false;
      bool savingDialog = false;
      int balanceRequestId = 0;

      try {
        final result = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                Future<void> updateBalance(String? customerId) async {
                  final requestId = ++balanceRequestId;
                  setDialogState(() {
                    selectedCustomerId = customerId;
                    loadingBalance = customerId != null;
                    balanceMinor = 0;
                    balanceLoadFailed = false;
                  });

                  if (customerId == null) return;

                  try {
                    final balance = await ref
                        .read(customerLedgerServiceProvider)
                        .getOutstandingBalance(
                          businessId: businessId,
                          customerId: customerId,
                        );

                    if (!context.mounted || requestId != balanceRequestId) {
                      return;
                    }

                    setDialogState(() {
                      balanceMinor = balance;
                      loadingBalance = false;
                      balanceLoadFailed = false;
                    });
                  } catch (_) {
                    if (!context.mounted || requestId != balanceRequestId) {
                      return;
                    }

                    setDialogState(() {
                      loadingBalance = false;
                      balanceLoadFailed = true;
                    });
                  }
                }

                return PopScope(
                  canPop: !savingDialog,
                  child: AlertDialog(
                    title: const Text('Record Customer Payment'),
                    content: SizedBox(
                      width: 440,
                      child: Form(
                        key: formKey,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: selectedCustomerId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Customer',
                                  border: OutlineInputBorder(),
                                ),
                                items: customers
                                    .map(
                                      (customer) => DropdownMenuItem<String>(
                                        value: customer.id,
                                        child: Text(
                                          customer.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: savingDialog
                                    ? null
                                    : (id) => updateBalance(id),
                                validator: (value) =>
                                    value == null ? 'Select a customer.' : null,
                              ),
                              const SizedBox(height: 16),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Current outstanding'),
                                      const SizedBox(height: 6),
                                      if (loadingBalance)
                                        const LinearProgressIndicator()
                                      else if (balanceLoadFailed)
                                        const Text(
                                          'Could not load the balance. '
                                          'Please select the customer again.',
                                        )
                                      else
                                        Text(
                                          _money(balanceMinor),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: amountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Amount (PKR)',
                                  hintText: 'e.g. 1500 or 1500.50',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  final amountMinor = _parseAmountMinor(
                                    value ?? '',
                                  );

                                  if (amountMinor == null || amountMinor <= 0) {
                                    return 'Enter a valid amount with up to '
                                        '2 decimal places.';
                                  }

                                  if (amountMinor > balanceMinor) {
                                    return 'Amount exceeds the outstanding '
                                        'balance.';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: method,
                                decoration: const InputDecoration(
                                  labelText: 'Payment method',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Cash',
                                    child: Text('Cash'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Bank Transfer',
                                    child: Text('Bank Transfer'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Card',
                                    child: Text('Card'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Other',
                                    child: Text('Other'),
                                  ),
                                ],
                                onChanged: savingDialog
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setDialogState(() => method = value);
                                        }
                                      },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: referenceController,
                                maxLength: 200,
                                decoration: const InputDecoration(
                                  labelText: 'Reference (optional)',
                                  hintText: 'Receipt or transaction number',
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
                        onPressed: savingDialog
                            ? null
                            : () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton.icon(
                        onPressed: savingDialog
                            ? null
                            : () async {
                                if (savingDialog ||
                                    loadingBalance ||
                                    balanceLoadFailed ||
                                    selectedCustomerId == null ||
                                    !formKey.currentState!.validate()) {
                                  return;
                                }

                                final amountMinor = _parseAmountMinor(
                                  amountController.text,
                                );

                                if (amountMinor == null ||
                                    amountMinor <= 0 ||
                                    amountMinor > balanceMinor) {
                                  return;
                                }

                                setDialogState(() => savingDialog = true);

                                try {
                                  await ref
                                      .read(paymentServiceProvider)
                                      .recordPayment(
                                        businessId: businessId,
                                        customerId: selectedCustomerId!,
                                        userId: userId,
                                        paymentId: const Uuid().v4(),
                                        amountMinor: amountMinor,
                                        paymentMethod: method,
                                        reference: referenceController.text,
                                        paidAt: DateTime.now(),
                                      );

                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext, true);
                                  }
                                } catch (error) {
                                  if (!dialogContext.mounted) return;

                                  setDialogState(() => savingDialog = false);

                                  ScaffoldMessenger.of(dialogContext)
                                      .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Could not record payment: $error',
                                          ),
                                        ),
                                      );
                                }
                              },
                        icon: savingDialog
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          savingDialog ? 'Saving...' : 'Record Payment',
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );

        if (result == true && mounted) {
          _refresh();

          ref.invalidate(dashboardProvider);
          ref.invalidate(customerListProvider(false));

          _message('Payment recorded successfully.');
        }
      } finally {
        amountController.dispose();
        referenceController.dispose();
      }
    } catch (error) {
      if (mounted) {
        _message('Could not prepare the payment form: $error');
      }
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final businessId = ref.watch(activeBusinessIdProvider);

    ref.listen(activeBusinessIdProvider, (previous, next) {
      if (previous != next) {
        _refresh();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        actions: [
          IconButton(
            tooltip: 'Refresh payment history',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _showRecordPaymentDialog,
            icon: const Icon(Icons.add),
            label: const Text('Record Payment'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: businessId == null || businessId.isEmpty
          ? const Center(child: Text('Select a business to view payments.'))
          : FutureBuilder<List<_PaymentRow>>(
              future: _paymentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Could not load payment history.'),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _refresh,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  );
                }

                final rows = snapshot.data ?? [];
                final totalMinor = rows.fold<int>(
                  0,
                  (sum, row) => sum + row.payment.amountMinor,
                );

                if (rows.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.payments_outlined, size: 48),
                        const SizedBox(height: 12),
                        const Text('No payments recorded yet.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _showRecordPaymentDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Record first payment'),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Wrap(
                            spacing: 36,
                            runSpacing: 12,
                            children: [
                              _SummaryItem(
                                label: 'Payments recorded',
                                value: rows.length.toString(),
                              ),
                              _SummaryItem(
                                label: 'Total received',
                                value: _money(totalMinor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Date & Time')),
                              DataColumn(label: Text('Customer')),
                              DataColumn(label: Text('Amount')),
                              DataColumn(label: Text('Method')),
                              DataColumn(label: Text('Reference')),
                            ],
                            rows: rows.map((row) {
                              final payment = row.payment;
                              return DataRow(
                                cells: [
                                  DataCell(Text(_date(payment.paidAt))),
                                  DataCell(Text(row.customerName)),
                                  DataCell(
                                    Text(
                                      _money(payment.amountMinor),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(payment.paymentMethod)),
                                  DataCell(
                                    Text(
                                      payment.reference?.isNotEmpty == true
                                          ? payment.reference!
                                          : '—',
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _PaymentRow {
  const _PaymentRow({required this.payment, required this.customerName});

  final Payment payment;
  final String customerName;
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
