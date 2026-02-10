import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfReportGenerator {
  static Future<void> generateSalesReport({
    required double todaySales,
    required double weekSales,
    required double monthSales,
    required int todayTransactions,
    required int weekTransactions,
    required int monthTransactions,
    required List<Map<String, dynamic>> topProducts,
    required List<Map<String, dynamic>> dailySales,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Sales Report',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Generated on ${DateFormat('MMMM dd, yyyy • hh:mm a').format(DateTime.now())}',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Divider(thickness: 2),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Sales Overview
          pw.Text(
            'Sales Overview',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                children: [
                  _buildTableCell('Period', isHeader: true),
                  _buildTableCell('Revenue', isHeader: true),
                  _buildTableCell('Transactions', isHeader: true),
                ],
              ),
              // Today
              pw.TableRow(children: [
                _buildTableCell('Today'),
                _buildTableCell('\$${todaySales.toStringAsFixed(2)}'),
                _buildTableCell(todayTransactions.toString()),
              ]),
              // This Week
              pw.TableRow(children: [
                _buildTableCell('This Week'),
                _buildTableCell('\$${weekSales.toStringAsFixed(2)}'),
                _buildTableCell(weekTransactions.toString()),
              ]),
              // This Month
              pw.TableRow(children: [
                _buildTableCell('This Month'),
                _buildTableCell('\$${monthSales.toStringAsFixed(2)}'),
                _buildTableCell(monthTransactions.toString()),
              ]),
            ],
          ),
          pw.SizedBox(height: 24),

          // Top Products
          pw.Text(
            'Top Products This Month',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          if (topProducts.isNotEmpty)
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                  children: [
                    _buildTableCell('Product', isHeader: true),
                    _buildTableCell('Units Sold', isHeader: true),
                    _buildTableCell('Revenue', isHeader: true),
                  ],
                ),
                // Products
                ...topProducts.take(10).map((product) {
                  final name = product['productName'] as String;
                  final quantity = (product['totalQuantity'] as num?)?.toInt() ?? 0;
                  final revenue = (product['totalRevenue'] as num?)?.toDouble() ?? 0.0;
                  return pw.TableRow(children: [
                    _buildTableCell(name),
                    _buildTableCell(quantity.toString()),
                    _buildTableCell('\$${revenue.toStringAsFixed(2)}'),
                  ]);
                }),
              ],
            )
          else
            pw.Text('No product sales this month'),
          pw.SizedBox(height: 24),

          // Daily Sales Trend
          pw.Text(
            'Daily Sales Trend (Last 7 Days)',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          if (dailySales.isNotEmpty)
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                  children: [
                    _buildTableCell('Date', isHeader: true),
                    _buildTableCell('Revenue', isHeader: true),
                    _buildTableCell('Transactions', isHeader: true),
                  ],
                ),
                ...dailySales.map((day) {
                  final date = DateTime.parse(day['date'] as String);
                  final total = (day['total'] as num?)?.toDouble() ?? 0.0;
                  final count = (day['count'] as num?)?.toInt() ?? 0;
                  return pw.TableRow(children: [
                    _buildTableCell(DateFormat('MMM dd, yyyy').format(date)),
                    _buildTableCell('\$${total.toStringAsFixed(2)}'),
                    _buildTableCell(count.toString()),
                  ]);
                }),
              ],
            )
          else
            pw.Text('No sales data for the past 7 days'),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  static Future<void> generateInventoryReport({
    required Map<String, dynamic> stats,
    required List<Map<String, dynamic>> categoryData,
  }) async {
    final pdf = pw.Document();

    final totalProducts = stats['totalProducts'] ?? 0;
    final totalValue = (stats['totalValue'] as num?)?.toDouble() ?? 0.0;
    final totalCost = (stats['totalCost'] as num?)?.toDouble() ?? 0.0;
    final potentialProfit = (stats['potentialProfit'] as num?)?.toDouble() ?? 0.0;
    final lowStockCount = stats['lowStockCount'] ?? 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Inventory Report',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Generated on ${DateFormat('MMMM dd, yyyy • hh:mm a').format(DateTime.now())}',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Divider(thickness: 2),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Inventory Overview
          pw.Text(
            'Inventory Overview',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                children: [
                  _buildTableCell('Metric', isHeader: true),
                  _buildTableCell('Value', isHeader: true),
                ],
              ),
              pw.TableRow(children: [
                _buildTableCell('Total Products'),
                _buildTableCell(totalProducts.toString()),
              ]),
              pw.TableRow(children: [
                _buildTableCell('Low Stock Items'),
                _buildTableCell(lowStockCount.toString()),
              ]),
              pw.TableRow(children: [
                _buildTableCell('Total Value'),
                _buildTableCell('\$${totalValue.toStringAsFixed(2)}'),
              ]),
              pw.TableRow(children: [
                _buildTableCell('Total Cost'),
                _buildTableCell('\$${totalCost.toStringAsFixed(2)}'),
              ]),
              pw.TableRow(children: [
                _buildTableCell('Potential Profit'),
                _buildTableCell('\$${potentialProfit.toStringAsFixed(2)}'),
              ]),
            ],
          ),
          pw.SizedBox(height: 24),

          // Category Breakdown
          pw.Text(
            'Products by Category',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          if (categoryData.isNotEmpty)
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                  children: [
                    _buildTableCell('Category', isHeader: true),
                    _buildTableCell('Products', isHeader: true),
                    _buildTableCell('Total Units', isHeader: true),
                    _buildTableCell('Total Value', isHeader: true),
                  ],
                ),
                ...categoryData.map((category) {
                  final name = category['category'] as String;
                  final count = (category['productCount'] as num?)?.toInt() ?? 0;
                  final quantity = (category['totalQuantity'] as num?)?.toInt() ?? 0;
                  final value = (category['totalValue'] as num?)?.toDouble() ?? 0.0;
                  return pw.TableRow(children: [
                    _buildTableCell(name),
                    _buildTableCell(count.toString()),
                    _buildTableCell(quantity.toString()),
                    _buildTableCell('\$${value.toStringAsFixed(2)}'),
                  ]);
                }),
              ],
            )
          else
            pw.Text('No category data available'),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  static Future<void> generateEmployeeReport({
    required List<Map<String, dynamic>> performance,
    required List<Map<String, dynamic>> activity,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Employee Performance Report',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Generated on ${DateFormat('MMMM dd, yyyy • hh:mm a').format(DateTime.now())}',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Divider(thickness: 2),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Employee Performance
          pw.Text(
            'Sales Performance',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          if (performance.isNotEmpty)
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                  children: [
                    _buildTableCell('Employee', isHeader: true),
                    _buildTableCell('Sales Recorded', isHeader: true),
                  ],
                ),
                ...performance.map((emp) {
                  final name = emp['userName'] as String;
                  final count = (emp['actionCount'] as num?)?.toInt() ?? 0;
                  return pw.TableRow(children: [
                    _buildTableCell(name),
                    _buildTableCell(count.toString()),
                  ]);
                }),
              ],
            )
          else
            pw.Text('No employee sales recorded'),
          pw.SizedBox(height: 24),

          // Recent Activity Summary
          pw.Text(
            'Activity Summary (Last 7 Days)',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          if (activity.isNotEmpty)
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                  children: [
                    _buildTableCell('Employee', isHeader: true),
                    _buildTableCell('Action Type', isHeader: true),
                    _buildTableCell('Count', isHeader: true),
                  ],
                ),
                ...activity.take(20).map((act) {
                  final name = act['userName'] as String;
                  final action = (act['action'] as String)
                      .replaceAll('_', ' ')
                      .split(' ')
                      .map((w) => w[0].toUpperCase() + w.substring(1))
                      .join(' ');
                  final count = (act['count'] as num?)?.toInt() ?? 0;
                  return pw.TableRow(children: [
                    _buildTableCell(name),
                    _buildTableCell(action),
                    _buildTableCell(count.toString()),
                  ]);
                }),
              ],
            )
          else
            pw.Text('No recent activity'),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  static Future<void> generateProfitReport({
    required Map<String, dynamic> profitAnalysis,
  }) async {
    final pdf = pw.Document();

    final revenue = (profitAnalysis['totalRevenue'] as num?)?.toDouble() ?? 0.0;
    final cost = (profitAnalysis['totalCost'] as num?)?.toDouble() ?? 0.0;
    final profit = (profitAnalysis['grossProfit'] as num?)?.toDouble() ?? 0.0;
    final margin = (profitAnalysis['profitMargin'] as num?)?.toDouble() ?? 0.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Text(
              'Profit Analysis Report',
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Generated on ${DateFormat('MMMM dd, yyyy • hh:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(
                fontSize: 12,
                color: PdfColors.grey700,
              ),
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),

            // Profit Overview
            pw.Text(
              'This Month\'s Performance',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                  children: [
                    _buildTableCell('Metric', isHeader: true),
                    _buildTableCell('Amount', isHeader: true),
                  ],
                ),
                pw.TableRow(children: [
                  _buildTableCell('Total Revenue'),
                  _buildTableCell('\$${revenue.toStringAsFixed(2)}'),
                ]),
                pw.TableRow(children: [
                  _buildTableCell('Total Cost'),
                  _buildTableCell('\$${cost.toStringAsFixed(2)}'),
                ]),
                pw.TableRow(children: [
                  _buildTableCell('Gross Profit'),
                  _buildTableCell('\$${profit.toStringAsFixed(2)}'),
                ]),
                pw.TableRow(children: [
                  _buildTableCell('Profit Margin'),
                  _buildTableCell('${margin.toStringAsFixed(1)}%'),
                ]),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: isHeader ? 12 : 11,
        ),
      ),
    );
  }
}