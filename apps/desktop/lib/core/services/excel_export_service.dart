import 'package:excel/excel.dart';

import '../database/app_database.dart';
import 'reports_service.dart';

class ExcelExportService {
  Future<List<int>> createSalesWorkbook({
    required String businessName,
    required String currencyCode,
    required DateTime from,
    required DateTime to,
    required SalesReport salesReport,
    required List<TopSellingProduct> topSellingProducts,
  }) async {
    final excel = Excel.createExcel();

    final summary = excel['Sales Summary'];
    summary.appendRow([TextCellValue('Account Care - Sales Summary')]);
    summary.appendRow([TextCellValue('Business'), TextCellValue(businessName)]);
    summary.appendRow([TextCellValue('Currency'), TextCellValue(currencyCode)]);
    summary.appendRow([
      TextCellValue('From'),
      TextCellValue(_formatDate(from)),
    ]);
    summary.appendRow([TextCellValue('To'), TextCellValue(_formatDate(to))]);
    summary.appendRow([]);
    summary.appendRow([
      TextCellValue('Metric'),
      TextCellValue('Amount / Count'),
    ]);
    summary.appendRow([
      TextCellValue('Completed Sales'),
      IntCellValue(salesReport.saleCount),
    ]);
    summary.appendRow([
      TextCellValue('Total Sales ($currencyCode)'),
      DoubleCellValue(salesReport.totalSalesMinor / 100),
    ]);
    summary.appendRow([
      TextCellValue('Payments Received ($currencyCode)'),
      DoubleCellValue(salesReport.totalPaidMinor / 100),
    ]);
    summary.appendRow([
      TextCellValue('Outstanding Credit ($currencyCode)'),
      DoubleCellValue(salesReport.totalCreditMinor / 100),
    ]);
    summary.appendRow([
      TextCellValue('Estimated Profit ($currencyCode)'),
      DoubleCellValue(salesReport.totalProfitMinor / 100),
    ]);

    final products = excel['Top-Selling Products'];
    products.appendRow([
      TextCellValue('Product'),
      TextCellValue('Quantity Sold'),
      TextCellValue('Sales ($currencyCode)'),
    ]);

    for (final product in topSellingProducts) {
      products.appendRow([
        TextCellValue(product.productName),
        IntCellValue(product.quantitySold),
        DoubleCellValue(product.salesMinor / 100),
      ]);
    }

    // The default sheet is replaced by our two report sheets.
    excel.delete('Sheet1');

    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Could not generate the Excel workbook.');
    }

    return bytes;
  }

  Future<List<int>> createDebtorsWorkbook({
    required String businessName,
    required String currencyCode,
    required List<Customer> customers,
    required Map<String, int> balancesMinor,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Debtors'];

    sheet.appendRow([TextCellValue('Account Care - Complete Debtors List')]);
    sheet.appendRow([TextCellValue('Business'), TextCellValue(businessName)]);
    sheet.appendRow([TextCellValue('Currency'), TextCellValue(currencyCode)]);
    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue('Customer Name'),
      TextCellValue('Phone'),
      TextCellValue('Address'),
      TextCellValue('Total Outstanding ($currencyCode)'),
    ]);

    final debtors =
        customers
            .where((customer) => (balancesMinor[customer.id] ?? 0) > 0)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    for (final customer in debtors) {
      sheet.appendRow([
        TextCellValue(customer.name),
        TextCellValue(customer.phone ?? ''),
        TextCellValue(customer.address ?? ''),
        DoubleCellValue(balancesMinor[customer.id]! / 100),
      ]);
    }

    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue('Total Debtors'),
      IntCellValue(debtors.length),
    ]);
    sheet.appendRow([
      TextCellValue('Total Outstanding ($currencyCode)'),
      DoubleCellValue(
        debtors.fold<int>(
              0,
              (total, customer) => total + balancesMinor[customer.id]!,
            ) /
            100,
      ),
    ]);

    excel.delete('Sheet1');

    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Could not generate the debtors workbook.');
    }

    return bytes;
  }

  Future<List<int>> createCustomerHistoryWorkbook({
    required Customer customer,
    required String businessName,
    required String currencyCode,
    required int balanceMinor,
    required List<Sale> sales,
    required List<SaleItem> saleItems,
    required List<Payment> payments,
    required List<PaymentAllocation> allocations,
    required List<LedgerEntry> ledgerEntries,
  }) async {
    final excel = Excel.createExcel();

    String dateTime(DateTime value) =>
        value.toLocal().toIso8601String().replaceFirst('T', ' ');

    final summary = excel['Customer Summary'];
    summary.appendRow([TextCellValue('Account Care - Customer History')]);
    summary.appendRow([TextCellValue('Business'), TextCellValue(businessName)]);
    summary.appendRow([TextCellValue('Currency'), TextCellValue(currencyCode)]);
    summary.appendRow([
      TextCellValue('Customer'),
      TextCellValue(customer.name),
    ]);
    summary.appendRow([
      TextCellValue('Phone'),
      TextCellValue(customer.phone ?? ''),
    ]);
    summary.appendRow([
      TextCellValue('Address'),
      TextCellValue(customer.address ?? ''),
    ]);
    summary.appendRow([
      TextCellValue('Customer Created'),
      TextCellValue(dateTime(customer.createdAt)),
    ]);
    summary.appendRow([
      TextCellValue('Opening Balance ($currencyCode)'),
      DoubleCellValue(customer.openingBalanceMinor / 100),
    ]);
    summary.appendRow([
      TextCellValue('Current Outstanding ($currencyCode)'),
      DoubleCellValue(balanceMinor / 100),
    ]);
    summary.appendRow([]);
    summary.appendRow([
      TextCellValue('Completed Sales'),
      IntCellValue(sales.length),
    ]);
    summary.appendRow([
      TextCellValue('Payments Recorded'),
      IntCellValue(payments.length),
    ]);

    summary.appendRow([]);
    summary.appendRow([TextCellValue('SALES HISTORY')]);
    summary.appendRow([
      TextCellValue('Date and Time'),
      TextCellValue('Invoice'),
      TextCellValue('Items Purchased'),
      TextCellValue('Sale Total ($currencyCode)'),
      TextCellValue('Paid ($currencyCode)'),
      TextCellValue('Due ($currencyCode)'),
    ]);

    for (final sale in sales) {
      final itemsForSale = saleItems
          .where((item) => item.saleId == sale.id)
          .toList();

      final itemDescriptions = itemsForSale
          .map((item) {
            return '${item.productName} x ${item.quantity} '
                '(@ $currencyCode ${(item.unitPriceMinor / 100).toStringAsFixed(2)})';
          })
          .join('; ');

      summary.appendRow([
        TextCellValue(dateTime(sale.soldAt)),
        TextCellValue(sale.invoiceNumber),
        TextCellValue(
          itemDescriptions.isEmpty ? 'No item details' : itemDescriptions,
        ),
        DoubleCellValue(sale.totalMinor / 100),
        DoubleCellValue(sale.paidMinor / 100),
        DoubleCellValue(sale.dueMinor / 100),
      ]);
    }

    summary.appendRow([]);
    summary.appendRow([TextCellValue('PAYMENT HISTORY')]);
    summary.appendRow([
      TextCellValue('Date and Time'),
      TextCellValue('Payment Method'),
      TextCellValue('Reference'),
      TextCellValue('Amount ($currencyCode)'),
    ]);

    for (final payment in payments) {
      summary.appendRow([
        TextCellValue(dateTime(payment.paidAt)),
        TextCellValue(payment.paymentMethod),
        TextCellValue(payment.reference ?? ''),
        DoubleCellValue(payment.amountMinor / 100),
      ]);
    }

    final salesSheet = excel['Sales'];
    salesSheet.appendRow([
      TextCellValue('Invoice'),
      TextCellValue('Sale ID'),
      TextCellValue('Date and Time'),
      TextCellValue('Subtotal ($currencyCode)'),
      TextCellValue('Discount ($currencyCode)'),
      TextCellValue('Total ($currencyCode)'),
      TextCellValue('Paid ($currencyCode)'),
      TextCellValue('Due ($currencyCode)'),
      TextCellValue('Status'),
    ]);

    for (final sale in sales) {
      salesSheet.appendRow([
        TextCellValue(sale.invoiceNumber),
        TextCellValue(sale.id),
        TextCellValue(dateTime(sale.soldAt)),
        DoubleCellValue(sale.subtotalMinor / 100),
        DoubleCellValue(sale.discountMinor / 100),
        DoubleCellValue(sale.totalMinor / 100),
        DoubleCellValue(sale.paidMinor / 100),
        DoubleCellValue(sale.dueMinor / 100),
        TextCellValue(sale.status),
      ]);
    }

    final itemsSheet = excel['Sale Items'];
    itemsSheet.appendRow([
      TextCellValue('Invoice'),
      TextCellValue('Sale ID'),
      TextCellValue('Product'),
      TextCellValue('Quantity'),
      TextCellValue('Unit Price ($currencyCode)'),
      TextCellValue('Item Discount ($currencyCode)'),
      TextCellValue('Line Total ($currencyCode)'),
    ]);

    final invoicesBySaleId = {
      for (final sale in sales) sale.id: sale.invoiceNumber,
    };

    for (final item in saleItems) {
      itemsSheet.appendRow([
        TextCellValue(invoicesBySaleId[item.saleId] ?? ''),
        TextCellValue(item.saleId),
        TextCellValue(item.productName),
        IntCellValue(item.quantity),
        DoubleCellValue(item.unitPriceMinor / 100),
        DoubleCellValue(item.discountMinor / 100),
        DoubleCellValue(item.lineTotalMinor / 100),
      ]);
    }

    final paymentsSheet = excel['Payments'];
    paymentsSheet.appendRow([
      TextCellValue('Payment ID'),
      TextCellValue('Date and Time'),
      TextCellValue('Amount ($currencyCode)'),
      TextCellValue('Method'),
      TextCellValue('Reference'),
      TextCellValue('Sale ID'),
    ]);

    for (final payment in payments) {
      paymentsSheet.appendRow([
        TextCellValue(payment.id),
        TextCellValue(dateTime(payment.paidAt)),
        DoubleCellValue(payment.amountMinor / 100),
        TextCellValue(payment.paymentMethod),
        TextCellValue(payment.reference ?? ''),
        TextCellValue(payment.saleId ?? ''),
      ]);
    }

    final allocationsSheet = excel['Payment Allocations'];
    allocationsSheet.appendRow([
      TextCellValue('Payment ID'),
      TextCellValue('Invoice'),
      TextCellValue('Sale ID'),
      TextCellValue('Allocated Amount ($currencyCode)'),
      TextCellValue('Allocation Date'),
    ]);

    for (final allocation in allocations) {
      allocationsSheet.appendRow([
        TextCellValue(allocation.paymentId),
        TextCellValue(invoicesBySaleId[allocation.saleId] ?? ''),
        TextCellValue(allocation.saleId),
        DoubleCellValue(allocation.amountMinor / 100),
        TextCellValue(dateTime(allocation.allocatedAt)),
      ]);
    }

    final ledgerSheet = excel['Ledger History'];
    ledgerSheet.appendRow([
      TextCellValue('Date and Time'),
      TextCellValue('Entry Type'),
      TextCellValue('Amount ($currencyCode)'),
      TextCellValue('Description'),
      TextCellValue('Invoice / Sale ID'),
      TextCellValue('Payment ID'),
    ]);

    for (final entry in ledgerEntries) {
      ledgerSheet.appendRow([
        TextCellValue(dateTime(entry.entryAt)),
        TextCellValue(entry.entryType),
        DoubleCellValue(entry.amountMinor / 100),
        TextCellValue(entry.description ?? ''),
        TextCellValue(
          entry.saleId == null
              ? ''
              : invoicesBySaleId[entry.saleId] ?? entry.saleId!,
        ),
        TextCellValue(entry.paymentId ?? ''),
      ]);
    }

    excel.delete('Sheet1');

    // Widen columns so dates, invoices, and monetary values are readable.
    summary.setColumnWidth(0, 32);
    summary.setColumnWidth(1, 38);

    for (final sheet in [
      salesSheet,
      itemsSheet,
      paymentsSheet,
      allocationsSheet,
      ledgerSheet,
    ]) {
      for (var column = 0; column < 9; column++) {
        sheet.setColumnWidth(column, 22);
      }
    }

    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Could not generate the customer history workbook.');
    }

    return bytes;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
