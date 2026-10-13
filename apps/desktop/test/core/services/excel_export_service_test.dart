import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop/core/database/app_database.dart';
import 'package:desktop/core/services/excel_export_service.dart';
import 'package:desktop/core/services/reports_service.dart';

void main() {
  group('ExcelExportService', () {
    final service = ExcelExportService();

    test(
      'creates a workbook with sales and top-selling product sheets',
      () async {
        final bytes = await service.createSalesWorkbook(
          businessName: 'Test Shop',
          currencyCode: 'PKR',
          from: DateTime(2026, 10, 1),
          to: DateTime(2026, 10, 12, 23, 59, 59),
          salesReport: SalesReport(
            saleCount: 5,
            totalSalesMinor: 100000,
            totalPaidMinor: 80000,
            totalCreditMinor: 20000,
            totalProfitMinor: 30000,
          ),
          topSellingProducts: [
            TopSellingProduct(
              productId: 'product-1',
              productName: 'Test Product',
              quantitySold: 10,
              salesMinor: 50000,
            ),
          ],
        );

        expect(bytes, isNotEmpty);

        final workbook = Excel.decodeBytes(bytes);

        expect(workbook.tables.keys, contains('Sales Summary'));
        expect(workbook.tables.keys, contains('Top-Selling Products'));

        final summary = workbook.tables['Sales Summary']!;
        final summaryText = summary.rows
            .expand((row) => row)
            .whereType<Data?>()
            .map((cell) => cell?.value.toString() ?? '')
            .join(' ');

        expect(summaryText, contains('Test Shop'));
        expect(summaryText, contains('PKR'));
        expect(summaryText, contains('Completed Sales'));

        final products = workbook.tables['Top-Selling Products']!;
        final productText = products.rows
            .expand((row) => row)
            .whereType<Data?>()
            .map((cell) => cell?.value.toString() ?? '')
            .join(' ');

        expect(productText, contains('Test Product'));
      },
    );

    test('exports all debtors with exactly four required columns', () async {
      final bytes = await service.createDebtorsWorkbook(
        businessName: 'Test Shop',
        currencyCode: 'PKR',
        customers: [
          Customer(
            id: 'customer-1',
            businessId: 'business-1',
            name: 'Ali Khan',
            phone: '03001234567',
            address: 'Mingora, Swat',
            openingBalanceMinor: 5000,
            isActive: true,
            createdAt: DateTime(2026, 10, 1),
            updatedAt: DateTime(2026, 10, 1),
          ),
        ],
        balancesMinor: {'customer-1': 12500},
      );

      final workbook = Excel.decodeBytes(bytes);
      expect(workbook.tables, contains('Debtors'));

      final sheet = workbook.tables['Debtors']!;

      // The title and business details occupy the first four rows.
      // The column headers are on row index 4.
      final headerRow = sheet.rows.firstWhere(
        (row) => row.any((cell) => cell?.value.toString() == 'Customer Name'),
      );

      final headers = headerRow
          .map((cell) => cell?.value.toString() ?? '')
          .toList();

      expect(headers, [
        'Customer Name',
        'Phone',
        'Address',
        'Total Outstanding (PKR)',
      ]);

      final allText = sheet.rows
          .expand((row) => row)
          .map((cell) => cell?.value.toString() ?? '')
          .join(' ');

      expect(allText, contains('Ali Khan'));
      expect(allText, contains('03001234567'));
      expect(allText, contains('Mingora, Swat'));
      expect(allText, isNot(contains('Opening Balance')));

      // 12,500 minor units = PKR 125.00.
      final debtorRow = sheet.rows.firstWhere(
        (row) => row.any((cell) => cell?.value.toString() == 'Ali Khan'),
      );

      final amountCell = debtorRow[3]?.value;
      expect(amountCell, isA<IntCellValue>());
      expect((amountCell as IntCellValue).value, 125);
    });
    test(
      'exports customer history with sales, payments, allocations and ledger',
      () async {
        final date = DateTime(2026, 10, 12, 10, 30);

        final customer = Customer(
          id: 'customer-1',
          businessId: 'business-1',
          name: 'Ali Khan',
          phone: '03001234567',
          address: 'Mingora, Swat',
          openingBalanceMinor: 0,
          isActive: true,
          createdAt: date,
          updatedAt: date,
        );

        final sale = Sale(
          id: 'sale-1',
          businessId: 'business-1',
          customerId: 'customer-1',
          userId: 'user-1',
          invoiceNumber: 'INV-001',
          subtotalMinor: 10000,
          discountMinor: 0,
          totalMinor: 10000,
          paidMinor: 5000,
          dueMinor: 5000,
          status: 'completed',
          soldAt: date,
          createdAt: date,
        );

        final item = SaleItem(
          id: 'item-1',
          saleId: 'sale-1',
          productId: 'product-1',
          productName: 'Test Rice',
          quantity: 2,
          unitPriceMinor: 5000,
          purchasePriceMinor: 4000,
          discountMinor: 0,
          lineTotalMinor: 10000,
        );

        final payment = Payment(
          id: 'payment-1',
          businessId: 'business-1',
          customerId: 'customer-1',
          saleId: 'sale-1',
          userId: 'user-1',
          amountMinor: 5000,
          paymentMethod: 'cash',
          reference: 'RECEIPT-001',
          paidAt: date,
          createdAt: date,
        );

        final allocation = PaymentAllocation(
          id: 'allocation-1',
          businessId: 'business-1',
          paymentId: 'payment-1',
          saleId: 'sale-1',
          amountMinor: 5000,
          allocatedAt: date,
          createdAt: date,
        );

        final ledgerEntries = [
          LedgerEntry(
            id: 'ledger-1',
            businessId: 'business-1',
            customerId: 'customer-1',
            saleId: 'sale-1',
            entryType: 'sale_credit',
            amountMinor: 10000,
            description: 'Invoice INV-001',
            entryAt: date,
            createdAt: date,
          ),
          LedgerEntry(
            id: 'ledger-2',
            businessId: 'business-1',
            customerId: 'customer-1',
            paymentId: 'payment-1',
            entryType: 'payment',
            amountMinor: 5000,
            description: 'Cash payment',
            entryAt: date,
            createdAt: date,
          ),
        ];

        final bytes = await service.createCustomerHistoryWorkbook(
          customer: customer,
          businessName: 'Test Shop',
          currencyCode: 'PKR',
          balanceMinor: 5000,
          sales: [sale],
          saleItems: [item],
          payments: [payment],
          allocations: [allocation],
          ledgerEntries: ledgerEntries,
        );

        expect(bytes, isNotEmpty);

        final workbook = Excel.decodeBytes(bytes);

        expect(
          workbook.tables.keys,
          containsAll([
            'Customer Summary',
            'Sales',
            'Sale Items',
            'Payments',
            'Payment Allocations',
            'Ledger History',
          ]),
        );

        final summary = workbook.tables['Customer Summary']!;
        final summaryText = summary.rows
            .expand((row) => row)
            .map((cell) => cell?.value.toString() ?? '')
            .join(' ');

        expect(summaryText, contains('Ali Khan'));
        expect(summaryText, contains('INV-001'));
        expect(summaryText, contains('Test Rice'));
        expect(summaryText, contains('Current Outstanding (PKR)'));
        expect(summaryText, contains('Current Outstanding (PKR) 50'));

        final salesText = workbook.tables['Sales']!.rows
            .expand((row) => row)
            .map((cell) => cell?.value.toString() ?? '')
            .join(' ');

        expect(salesText, contains('INV-001'));
        expect(salesText, contains('completed'));

        final itemsText = workbook.tables['Sale Items']!.rows
            .expand((row) => row)
            .map((cell) => cell?.value.toString() ?? '')
            .join(' ');

        expect(itemsText, contains('Test Rice'));

        final paymentsText = workbook.tables['Payments']!.rows
            .expand((row) => row)
            .map((cell) => cell?.value.toString() ?? '')
            .join(' ');

        expect(paymentsText, contains('RECEIPT-001'));
        expect(paymentsText, contains('payment-1'));

        final allocationsText = workbook.tables['Payment Allocations']!.rows
            .expand((row) => row)
            .map((cell) => cell?.value.toString() ?? '')
            .join(' ');

        expect(allocationsText, contains('payment-1'));
        expect(allocationsText, contains('sale-1'));

        final ledgerText = workbook.tables['Ledger History']!.rows
            .expand((row) => row)
            .map((cell) => cell?.value.toString() ?? '')
            .join(' ');

        expect(ledgerText, contains('sale_credit'));
        expect(ledgerText, contains('payment'));
      },
    );
  });
}
