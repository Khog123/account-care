import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/business_provider.dart';
import '../../../core/providers/reports_providers.dart';
import '../../../core/providers/service_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isBackingUp = false;
  bool _isExportingExcel = false;

  Future<void> _backupDatabase() async {
    if (_isBackingUp || _isExportingExcel) return;

    setState(() => _isBackingUp = true);

    try {
      final saveLocation = await getSaveLocation(
        suggestedName:
            'account_care_backup_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first}.sqlite',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'SQLite database', extensions: ['sqlite', 'db']),
        ],
        confirmButtonText: 'Save Backup',
      );

      if (saveLocation == null || !mounted) return;

      await ref
          .read(databaseBackupServiceProvider)
          .createBackup(saveLocation.path);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Database backup verified successfully:\n${saveLocation.path}',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Database backup failed: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isBackingUp = false);
      }
    }
  }

  Future<void> _exportSalesToExcel(String businessId) async {
    if (_isExportingExcel || _isBackingUp) return;

    setState(() => _isExportingExcel = true);

    try {
      final range = ref.read(reportsDateRangeProvider);
      final reportsService = ref.read(reportsServiceProvider);

      final salesReport = await reportsService.getSalesReport(
        businessId: businessId,
        from: range.from,
        to: range.to,
      );

      final topSellingProducts = await reportsService.getTopSellingProducts(
        businessId: businessId,
        from: range.from,
        to: range.to,
      );

      if (!mounted) return;

      final now = DateTime.now();
      final timestamp =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      final saveLocation = await getSaveLocation(
        suggestedName: 'account_care_sales_report_$timestamp.xlsx',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Excel Workbook', extensions: ['xlsx']),
        ],
        confirmButtonText: 'Save Excel Report',
      );

      if (saveLocation == null || !mounted) return;

      final businesses = ref.read(businessListProvider).value ?? [];
      String businessName = 'Account Care';
      String currencyCode = 'PKR';

      for (final business in businesses) {
        if (business.id == businessId) {
          businessName = business.name;
          currencyCode = business.currencyCode;
          break;
        }
      }

      final bytes = await ref
          .read(excelExportServiceProvider)
          .createSalesWorkbook(
            businessName: businessName,
            currencyCode: currencyCode,
            from: range.from,
            to: range.to,
            salesReport: salesReport,
            topSellingProducts: topSellingProducts,
          );

      await File(saveLocation.path).writeAsBytes(bytes, flush: true);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel sales report saved:\n${saveLocation.path}'),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel export failed: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExportingExcel = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBusinessId = ref.watch(activeBusinessIdProvider);
    final businessesAsync = ref.watch(businessListProvider);

    final activeBusiness = businessesAsync.whenOrNull(
      data: (businesses) {
        for (final business in businesses) {
          if (business.id == activeBusinessId) {
            return business;
          }
        }
        return null;
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Business Settings',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Manage your business setup and application information.'),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.store_outlined),
              title: const Text('Current Business'),
              subtitle: businessesAsync.when(
                loading: () => const Text('Loading business...'),
                error: (_, _) =>
                    const Text('Unable to load business information.'),
                data: (_) {
                  if (activeBusinessId == null) {
                    return const Text('No active business selected.');
                  }

                  if (activeBusiness == null) {
                    return const Text(
                      'Active business information unavailable.',
                    );
                  }

                  return Text(
                    '${activeBusiness.name} • ${activeBusiness.currencyCode}',
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.business_outlined),
              title: const Text('Business Setup'),
              subtitle: const Text(
                'Select an existing business or create a new business.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/business-setup'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Back Up Database'),
              subtitle: const Text(
                'Save and verify a backup of your local business data.',
              ),
              trailing: _isBackingUp
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _isBackingUp || _isExportingExcel ? null : _backupDatabase,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Export Sales to Excel'),
              subtitle: const Text(
                'Export the current reporting period and top-selling '
                'products to an Excel workbook.',
              ),
              trailing: _isExportingExcel
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap:
                  _isExportingExcel ||
                      _isBackingUp ||
                      activeBusinessId == null ||
                      activeBusinessId.isEmpty ||
                      activeBusiness == null
                  ? null
                  : () => _exportSalesToExcel(activeBusinessId),
            ),
          ),
          const SizedBox(height: 24),
          Text('Application', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.computer_outlined),
              title: Text('Operating Mode'),
              subtitle: Text(
                'Local desktop application with an offline-first database.',
              ),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('About Account Care'),
              subtitle: Text(
                'Retail sales, inventory, customer credit, payments, and reports.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
