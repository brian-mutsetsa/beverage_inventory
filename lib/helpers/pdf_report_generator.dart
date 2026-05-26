import 'dart:math' as math;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  Comprehensive Business Report Generator
//  Covers: Sales Â· Products Â· Categories Â·
//          Inventory Â· Orders Â· Employees Â·
//          Profit Â· AI Insights
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class PdfReportGenerator {
  // â”€â”€ Brand colours â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const _black = PdfColors.black;
  static const _white = PdfColors.white;
  static const _grey50 = PdfColor.fromInt(0xFFFAFAFA);
  static const _grey100 = PdfColor.fromInt(0xFFF5F5F5);
  static const _grey200 = PdfColor.fromInt(0xFFEEEEEE);
  static const _grey300 = PdfColor.fromInt(0xFFE0E0E0);
  static const _grey500 = PdfColor.fromInt(0xFF9E9E9E);
  static const _grey700 = PdfColor.fromInt(0xFF616161);
  static const _blue = PdfColor.fromInt(0xFF1565C0);
  static const _blueLight = PdfColor.fromInt(0xFFE3F2FD);
  static const _green = PdfColor.fromInt(0xFF2E7D32);
  static const _greenLight = PdfColor.fromInt(0xFFE8F5E9);
  static const _orange = PdfColor.fromInt(0xFFE65100);
  static const _orangeLight = PdfColor.fromInt(0xFFFFF3E0);
  static const _red = PdfColor.fromInt(0xFFB71C1C);
  static const _redLight = PdfColor.fromInt(0xFFFFEBEE);
  static const _purple = PdfColor.fromInt(0xFF4A148C);
  static const _purpleLight = PdfColor.fromInt(0xFFF3E5F5);
  static const _teal = PdfColor.fromInt(0xFF004D40);
  static const _tealLight = PdfColor.fromInt(0xFFE0F2F1);
  static const _amber = PdfColor.fromInt(0xFFFF6F00);
  static const _amberLight = PdfColor.fromInt(0xFFFFF8E1);

  static final _fmt = NumberFormat('#,##0.00');
  static final _fmtInt = NumberFormat('#,##0');

  // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
  //  MASTER: Comprehensive Business Report
  // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
  static Future<void> generateComprehensiveReport({
    required String companyName,
    // Sales
    required double todaySales,
    required double weekSales,
    required double monthSales,
    required int todayTransactions,
    required int weekTransactions,
    required int monthTransactions,
    required List<Map<String, dynamic>> topProducts,
    required List<Map<String, dynamic>> dailySales,
    // Inventory
    required Map<String, dynamic> inventoryStats,
    required List<Map<String, dynamic>> categoryData,
    required List<Map<String, dynamic>> topSellers,
    required List<Map<String, dynamic>> slowMovers,
    required List<Map<String, dynamic>> stockHealth,
    // Employees
    required List<Map<String, dynamic>> employeePerformance,
    required List<Map<String, dynamic>> recentActivity,
    // Profit
    required Map<String, dynamic> profitAnalysis,
    // Orders
    required List<Map<String, dynamic>> ordersSummary,
    // AI insights (pre-generated strings)
    required List<String> aiInsights,
    required List<String> aiRecommendations,
    required List<Map<String, dynamic>> reorderAlerts,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final period = DateFormat('MMMM yyyy').format(now);
    final generated = DateFormat('dd MMM yyyy | hh:mm a').format(now);

    // â”€â”€ Pre-compute totals â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final totalRevenue = (profitAnalysis['totalRevenue'] as num?)?.toDouble() ?? monthSales;
    final totalCost = (profitAnalysis['totalCost'] as num?)?.toDouble() ?? 0.0;
    final grossProfit = (profitAnalysis['grossProfit'] as num?)?.toDouble() ?? (totalRevenue - totalCost);
    final profitMargin = (profitAnalysis['profitMargin'] as num?)?.toDouble() ??
        (totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0.0);
    final totalProducts = (inventoryStats['totalProducts'] as num?)?.toInt() ?? 0;
    final lowStockCount = (inventoryStats['lowStockCount'] as num?)?.toInt() ?? 0;
    final inventoryValue = (inventoryStats['totalValue'] as num?)?.toDouble() ?? 0.0;

    // â”€â”€ Order stats â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final totalOrders = ordersSummary.length;
    final pendingOrders = ordersSummary.where((o) => (o['status'] as String?) == 'pending').length;
    final completedOrders = ordersSummary.where((o) => (o['status'] as String?) == 'completed' || (o['status'] as String?) == 'delivered').length;
    final orderRevenue = ordersSummary.fold<double>(0, (sum, o) => sum + ((o['totalAmount'] as num?)?.toDouble() ?? 0));

    // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
    //  PAGE 1  -  COVER
    // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Stack(
          children: [
            // Background
            pw.Container(
              width: double.infinity,
              height: double.infinity,
              color: _black,
            ),
            // Accent stripe
            pw.Positioned(
              top: 0,
              left: 0,
              child: pw.Container(width: 8, height: 841, color: _blue),
            ),
            // Content
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(60, 80, 60, 60),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    companyName.toUpperCase(),
                    style: pw.TextStyle(
                      color: _blue,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                  pw.SizedBox(height: 32),
                  pw.Text(
                    'Business\nPerformance\nReport',
                    style: pw.TextStyle(
                      color: _white,
                      fontSize: 52,
                      fontWeight: pw.FontWeight.bold,
                      lineSpacing: 4,
                    ),
                  ),
                  pw.SizedBox(height: 24),
                  pw.Container(width: 80, height: 4, color: _blue),
                  pw.SizedBox(height: 32),
                  pw.Text(
                    period,
                    style: const pw.TextStyle(color: _grey300, fontSize: 20),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Generated: $generated',
                    style: const pw.TextStyle(color: _grey500, fontSize: 12),
                  ),
                  pw.Spacer(),
                  pw.Container(height: 1, color: _grey700),
                  pw.SizedBox(height: 20),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _coverKPI('Revenue', '\$${_fmt.format(monthSales)}', _white),
                      _coverKPI('Transactions', _fmtInt.format(monthTransactions), _white),
                      _coverKPI('Profit Margin', '${profitMargin.toStringAsFixed(1)}%', _white),
                      _coverKPI('Products', totalProducts.toString(), _white),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'CONFIDENTIAL  -  For internal business use only',
                    style: const pw.TextStyle(color: _grey700, fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
    //  PAGE 2  -  EXECUTIVE SUMMARY
    // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => _pageHeader('Executive Summary', period, ctx.pageNumber),
        footer: (ctx) => _pageFooter(companyName, generated),
        build: (ctx) => [
          _sectionTitle('Key Performance Indicators'),
          pw.SizedBox(height: 12),
          // KPI grid: 4 metrics per row
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(),
              1: const pw.FlexColumnWidth(),
              2: const pw.FlexColumnWidth(),
              3: const pw.FlexColumnWidth(),
            },
            children: [
              pw.TableRow(children: [
                _kpiCard('Today\'s Revenue', '\$${_fmt.format(todaySales)}', '$todayTransactions txns', _blue, _blueLight),
                pw.SizedBox(width: 8),
                _kpiCard('This Week', '\$${_fmt.format(weekSales)}', '$weekTransactions txns', _green, _greenLight),
                pw.SizedBox(width: 8),
                _kpiCard('This Month', '\$${_fmt.format(monthSales)}', '$monthTransactions txns', _purple, _purpleLight),
                pw.SizedBox(width: 8),
                _kpiCard('Gross Profit', '\$${_fmt.format(grossProfit)}', '${profitMargin.toStringAsFixed(1)}% margin', _teal, _tealLight),
              ]),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(),
              1: const pw.FlexColumnWidth(),
              2: const pw.FlexColumnWidth(),
              3: const pw.FlexColumnWidth(),
            },
            children: [
              pw.TableRow(children: [
                _kpiCard('Total Products', totalProducts.toString(), 'in catalogue', _orange, _orangeLight),
                pw.SizedBox(width: 8),
                _kpiCard('Low Stock', lowStockCount.toString(), 'need reorder', _red, _redLight),
                pw.SizedBox(width: 8),
                _kpiCard('Total Orders', totalOrders.toString(), '$pendingOrders pending', _amber, _amberLight),
                pw.SizedBox(width: 8),
                _kpiCard('Inventory Value', '\$${_fmt.format(inventoryValue)}', 'at selling price', _grey700, _grey100),
              ]),
            ],
          ),
          pw.SizedBox(height: 28),

          // Performance summary paragraph
          _sectionTitle('Period Summary'),
          pw.SizedBox(height: 10),
          _summaryBox(_buildSummaryText(
            monthSales: monthSales,
            monthTransactions: monthTransactions,
            grossProfit: grossProfit,
            profitMargin: profitMargin,
            topProducts: topProducts,
            lowStockCount: lowStockCount,
            totalOrders: totalOrders,
            completedOrders: completedOrders,
          )),
          pw.SizedBox(height: 28),

          // Quick status table
          _sectionTitle('At-a-Glance Status'),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: _grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.5),
            },
            children: [
              _tableHeaderRow(['Area', 'Status', 'Action Required']),
              _tableDataRow([
                'Monthly Revenue',
                '\$${_fmt.format(monthSales)}',
                monthSales > weekSales * 3 ? 'On Track' : 'Monitor',
              ], 0),
              _tableDataRow([
                'Profit Margin',
                '${profitMargin.toStringAsFixed(1)}%',
                profitMargin >= 20 ? 'Healthy' : profitMargin >= 10 ? 'Fair' : 'Review Pricing',
              ], 1),
              _tableDataRow([
                'Stock Health',
                '$lowStockCount items low',
                lowStockCount == 0 ? 'Good' : 'Reorder Now',
              ], 2),
              _tableDataRow([
                'Order Fulfilment',
                '$completedOrders / $totalOrders completed',
                pendingOrders > 5 ? 'Clear Backlog' : 'Good',
              ], 3),
            ],
          ),
        ],
      ),
    );

    // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
    //  PAGE 3  -  SALES ANALYSIS
    // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => _pageHeader('Sales Analysis', period, ctx.pageNumber),
        footer: (ctx) => _pageFooter(companyName, generated),
        build: (ctx) => [
          _sectionTitle('Daily Sales  -  Last 7 Days'),
          pw.SizedBox(height: 12),
          _buildBarChart(
            data: dailySales.map((d) {
              final date = DateTime.tryParse(d['date'] as String? ?? '');
              return _ChartBar(
                label: date != null ? DateFormat('EEE\ndd/MM').format(date) : ' - ',
                value: (d['total'] as num?)?.toDouble() ?? 0.0,
                subLabel: '${(d['count'] as num?)?.toInt() ?? 0} txns',
              );
            }).toList(),
            color: _blue,
            valuePrefix: '\$',
            height: 160,
          ),
          pw.SizedBox(height: 28),

          _sectionTitle('Sales Period Comparison'),
          pw.SizedBox(height: 12),
          _buildHorizontalBarChart(
            bars: [
              _HBar('Today', todaySales, _blue),
              _HBar('This Week', weekSales, _green),
              _HBar('This Month', monthSales, _purple),
            ],
            valuePrefix: '\$',
          ),
          pw.SizedBox(height: 28),

          _sectionTitle('Daily Sales Detail'),
          pw.SizedBox(height: 10),
          if (dailySales.isEmpty)
            _emptyState('No sales data for the past 7 days')
          else
            pw.Table(
              border: pw.TableBorder.all(color: _grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                _tableHeaderRow(['Date', 'Revenue', 'Transactions', 'Avg per Txn']),
                ...dailySales.asMap().entries.map((e) {
                  final d = e.value;
                  final date = DateTime.tryParse(d['date'] as String? ?? '');
                  final total = (d['total'] as num?)?.toDouble() ?? 0.0;
                  final count = (d['count'] as num?)?.toInt() ?? 1;
                  final avg = count > 0 ? total / count : 0.0;
                  return _tableDataRow([
                    date != null ? DateFormat('EEE, dd MMM yyyy').format(date) : ' - ',
                    '\$${_fmt.format(total)}',
                    count.toString(),
                    '\$${_fmt.format(avg)}',
                  ], e.key);
                }),
                // Total row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _grey100),
                  children: [
                    _tc('TOTAL', bold: true),
                    _tc('\$${_fmt.format(dailySales.fold<double>(0, (s, d) => s + ((d['total'] as num?)?.toDouble() ?? 0)))}', bold: true),
                    _tc(dailySales.fold<int>(0, (s, d) => s + ((d['count'] as num?)?.toInt() ?? 0)).toString(), bold: true),
                    _tc(''),
                  ],
                ),
              ],
            ),
        ],
      ),
    );

    // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
    //  PAGE 4  -  PRODUCT PERFORMANCE
    // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => _pageHeader('Product Performance', period, ctx.pageNumber),
        footer: (ctx) => _pageFooter(companyName, generated),
        build: (ctx) => [
          _sectionTitle('Top Products by Revenue  -  This Month'),
          pw.SizedBox(height: 12),
          if (topProducts.isEmpty)
            _emptyState('No product sales recorded this month')
          else ...[
            _buildBarChart(
              data: topProducts.take(8).map((p) => _ChartBar(
                label: _truncate(p['productName'] as String? ?? ' - ', 12),
                value: (p['totalRevenue'] as num?)?.toDouble() ?? 0.0,
                subLabel: '${(p['totalQuantity'] as num?)?.toInt() ?? 0} units',
              )).toList(),
              color: _green,
              valuePrefix: '\$',
              height: 150,
            ),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(color: _grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(24),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                _tableHeaderRow(['#', 'Product', 'Units Sold', 'Revenue', 'Avg Price']),
                ...topProducts.take(15).toList().asMap().entries.map((e) {
                  final i = e.key;
                  final p = e.value;
                  final qty = (p['totalQuantity'] as num?)?.toInt() ?? 0;
                  final rev = (p['totalRevenue'] as num?)?.toDouble() ?? 0.0;
                  final avg = qty > 0 ? rev / qty : 0.0;
                  return _tableDataRow([
                    (i + 1).toString(),
                    p['productName'] as String? ?? ' - ',
                    _fmtInt.format(qty),
                    '\$${_fmt.format(rev)}',
                    '\$${_fmt.format(avg)}',
                  ], i);
                }),
              ],
            ),
          ],
          pw.SizedBox(height: 28),

          _sectionTitle('Top Sellers  -  30 Day Velocity'),
          pw.SizedBox(height: 12),
          if (topSellers.isEmpty)
            _emptyState('No seller data available')
          else
            pw.Table(
              border: pw.TableBorder.all(color: _grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(24),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                _tableHeaderRow(['#', 'Product', 'Category', 'Units/30d', 'Revenue']),
                ...topSellers.asMap().entries.map((e) {
                  final i = e.key;
                  final p = e.value;
                  final sold = (p['totalSold'] as num?)?.toInt() ?? 0;
                  final rev = (p['totalRevenue'] as num?)?.toDouble() ?? 0.0;
                  return _tableDataRow([
                    (i + 1).toString(),
                    p['name'] as String? ?? ' - ',
                    p['category'] as String? ?? ' - ',
                    _fmtInt.format(sold),
                    '\$${_fmt.format(rev)}',
                  ], i);
                }),
              ],
            ),
          pw.SizedBox(height: 28),

          _sectionTitle('Slow Movers  -  Needs Attention'),
          pw.SizedBox(height: 10),
          _infoBox(
            'These products sold fewer than expected in the last 30 days. '
            'Consider promotions, pricing adjustments, or reducing reorder quantities.',
            _amberLight, _amber,
          ),
          pw.SizedBox(height: 10),
          if (slowMovers.isEmpty)
            _successBox('All products are moving well  -  no slow movers detected!')
          else
            pw.Table(
              border: pw.TableBorder.all(color: _grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                _tableHeaderRow(['Product', 'Category', 'Current Stock', 'Sold (30d)']),
                ...slowMovers.asMap().entries.map((e) {
                  final i = e.key;
                  final p = e.value;
                  return _tableDataRow([
                    p['name'] as String? ?? ' - ',
                    p['category'] as String? ?? ' - ',
                    (p['quantity'] as num?)?.toInt().toString() ?? '0',
                    (p['totalSold'] as num?)?.toInt().toString() ?? '0',
                  ], i);
                }),
              ],
            ),
        ],
      ),
    );

    // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
    //  PAGE 5  -  CATEGORY ANALYSIS
    // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => _pageHeader('Category Analysis', period, ctx.pageNumber),
        footer: (ctx) => _pageFooter(companyName, generated),
        build: (ctx) {
          // Compute category revenue from topProducts
          final Map<String, double> catRevMap = {};
          final Map<String, int> catUnitMap = {};
          for (final p in topProducts) {
            // We'll use categoryData for stock breakdowns
          }
          final totalCatValue = categoryData.fold<double>(0, (s, c) => s + ((c['totalValue'] as num?)?.toDouble() ?? 0));

          return [
            _sectionTitle('Inventory Value by Category'),
            pw.SizedBox(height: 12),
            if (categoryData.isEmpty)
              _emptyState('No category data available')
            else ...[
              _buildBarChart(
                data: categoryData.map((c) => _ChartBar(
                  label: _truncate(c['category'] as String? ?? ' - ', 10),
                  value: (c['totalValue'] as num?)?.toDouble() ?? 0.0,
                  subLabel: '${(c['productCount'] as num?)?.toInt() ?? 0} products',
                )).toList(),
                color: _purple,
                valuePrefix: '\$',
                height: 140,
              ),
              pw.SizedBox(height: 20),

              // Category table
              pw.Table(
                border: pw.TableBorder.all(color: _grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.5),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  _tableHeaderRow(['Category', 'Products', 'Units in Stock', 'Stock Value', '% of Total']),
                  ...categoryData.asMap().entries.map((e) {
                    final i = e.key;
                    final c = e.value;
                    final val = (c['totalValue'] as num?)?.toDouble() ?? 0.0;
                    final pct = totalCatValue > 0 ? (val / totalCatValue * 100) : 0.0;
                    return _tableDataRow([
                      c['category'] as String? ?? ' - ',
                      (c['productCount'] as num?)?.toInt().toString() ?? '0',
                      (c['totalQuantity'] as num?)?.toInt().toString() ?? '0',
                      '\$${_fmt.format(val)}',
                      '${pct.toStringAsFixed(1)}%',
                    ], i);
                  }),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: _grey100),
                    children: [
                      _tc('TOTAL', bold: true),
                      _tc(categoryData.fold<int>(0, (s, c) => s + ((c['productCount'] as num?)?.toInt() ?? 0)).toString(), bold: true),
                      _tc(categoryData.fold<int>(0, (s, c) => s + ((c['totalQuantity'] as num?)?.toInt() ?? 0)).toString(), bold: true),
                      _tc('\$${_fmt.format(totalCatValue)}', bold: true),
                      _tc('100%', bold: true),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // Doughnut-style percentage bars
              _sectionTitle('Category Share (Visual)'),
              pw.SizedBox(height: 12),
              _buildCategoryShareChart(categoryData, totalCatValue),
            ],
          ];
        },
      ),
    );

    // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
    //  PAGE 6  -  INVENTORY STATUS
    // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => _pageHeader('Inventory Status', period, ctx.pageNumber),
        footer: (ctx) => _pageFooter(companyName, generated),
        build: (ctx) => [
          _sectionTitle('Inventory Overview'),
          pw.SizedBox(height: 12),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(),
              1: const pw.FlexColumnWidth(),
              2: const pw.FlexColumnWidth(),
              3: const pw.FlexColumnWidth(),
            },
            children: [
              pw.TableRow(children: [
                _kpiCard('Total Products', totalProducts.toString(), 'in catalogue', _blue, _blueLight),
                pw.SizedBox(width: 8),
                _kpiCard('Inventory Value', '\$${_fmt.format(inventoryValue)}', 'at retail price', _green, _greenLight),
                pw.SizedBox(width: 8),
                _kpiCard('Cost of Stock', '\$${_fmt.format((inventoryStats['totalCost'] as num?)?.toDouble() ?? 0)}', 'at cost price', _orange, _orangeLight),
                pw.SizedBox(width: 8),
                _kpiCard('Low Stock Items', lowStockCount.toString(), 'below threshold', _red, _redLight),
              ]),
            ],
          ),
          pw.SizedBox(height: 28),

          _sectionTitle('Stock Health Breakdown'),
          pw.SizedBox(height: 12),
          if (stockHealth.isEmpty)
            _emptyState('No stock data available')
          else ...[
            _buildStockHealthChart(stockHealth),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: _grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(3),
              },
              children: [
                _tableHeaderRow(['Status', 'Count', 'Action']),
                ...stockHealth.asMap().entries.map((e) {
                  final i = e.key;
                  final s = e.value;
                  final status = s['status'] as String? ?? ' - ';
                  final count = (s['count'] as num?)?.toInt() ?? 0;
                  final action = _stockAction(status);
                  return _tableDataRow([status, count.toString(), action], i);
                }),
              ],
            ),
          ],
          pw.SizedBox(height: 28),

          if (reorderAlerts.isNotEmpty) ...[
            _sectionTitle('Reorder Alerts'),
            pw.SizedBox(height: 10),
            _infoBox(
              '${reorderAlerts.length} product(s) need immediate reordering based on current sales velocity.',
              _redLight, _red,
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: _grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                _tableHeaderRow(['Product', 'Days Until Stockout', 'Recommended Order']),
                ...reorderAlerts.asMap().entries.map((e) {
                  final i = e.key;
                  final a = e.value;
                  final days = (a['daysRemaining'] as num?)?.toInt() ?? 0;
                  final rec = (a['recommendedOrder'] as num?)?.toInt() ?? 0;
                  return _tableDataRow([
                    a['productName'] as String? ?? ' - ',
                    days == 0 ? 'OUT OF STOCK' : '$days days',
                    '$rec units',
                  ], i);
                }),
              ],
            ),
            pw.SizedBox(height: 28),
          ],

          _sectionTitle('Potential Profit from Current Inventory'),
          pw.SizedBox(height: 10),
          _summaryBox(
            'If all current inventory were sold at retail price, the business would generate '
            '\$${_fmt.format(inventoryValue)} in revenue with a potential gross profit of '
            '\$${_fmt.format((inventoryStats['potentialProfit'] as num?)?.toDouble() ?? 0)}. '
            'This excludes operational costs and is based on current selling prices.',
          ),
        ],
      ),
    );

    // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
    //  PAGE 7  -  ORDER SUMMARY
    // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => _pageHeader('Order Summary', period, ctx.pageNumber),
        footer: (ctx) => _pageFooter(companyName, generated),
        build: (ctx) {
          final processing = ordersSummary.where((o) => (o['status'] as String?) == 'processing').length;
          final cancelled = ordersSummary.where((o) => (o['status'] as String?) == 'cancelled').length;

          return [
            _sectionTitle('Order Overview'),
            pw.SizedBox(height: 12),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(),
                1: const pw.FlexColumnWidth(),
                2: const pw.FlexColumnWidth(),
                3: const pw.FlexColumnWidth(),
              },
              children: [
                pw.TableRow(children: [
                  _kpiCard('Total Orders', totalOrders.toString(), 'all time', _blue, _blueLight),
                  pw.SizedBox(width: 8),
                  _kpiCard('Pending', pendingOrders.toString(), 'awaiting action', _amber, _amberLight),
                  pw.SizedBox(width: 8),
                  _kpiCard('Completed', completedOrders.toString(), 'delivered', _green, _greenLight),
                  pw.SizedBox(width: 8),
                  _kpiCard('Order Revenue', '\$${_fmt.format(orderRevenue)}', 'total value', _purple, _purpleLight),
                ]),
              ],
            ),
            pw.SizedBox(height: 20),

            // Status bar chart
            if (totalOrders > 0) ...[
              _buildHorizontalBarChart(
                bars: [
                  _HBar('Pending', pendingOrders.toDouble(), _amber),
                  _HBar('Processing', processing.toDouble(), _blue),
                  _HBar('Completed', completedOrders.toDouble(), _green),
                  _HBar('Cancelled', cancelled.toDouble(), _red),
                ],
                valuePrefix: '',
                isCount: true,
              ),
              pw.SizedBox(height: 20),
            ],

            _sectionTitle('Recent Orders'),
            pw.SizedBox(height: 10),
            if (ordersSummary.isEmpty)
              _emptyState('No orders found')
            else
              pw.Table(
                border: pw.TableBorder.all(color: _grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.5),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  _tableHeaderRow(['Customer', 'Date', 'Amount', 'Status']),
                  ...ordersSummary.take(20).toList().asMap().entries.map((e) {
                    final i = e.key;
                    final o = e.value;
                    final date = DateTime.tryParse(o['createdAt'] as String? ?? '');
                    final status = (o['status'] as String? ?? ' - ').toUpperCase();
                    return _tableDataRow([
                      o['customerName'] as String? ?? ' - ',
                      date != null ? DateFormat('dd MMM yyyy').format(date) : ' - ',
                      '\$${_fmt.format((o['totalAmount'] as num?)?.toDouble() ?? 0)}',
                      status,
                    ], i);
                  }),
                ],
              ),
          ];
        },
      ),
    );

    // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
    //  PAGE 8  -  EMPLOYEE PERFORMANCE
    // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => _pageHeader('Employee Performance', period, ctx.pageNumber),
        footer: (ctx) => _pageFooter(companyName, generated),
        build: (ctx) => [
          _sectionTitle('Sales by Employee'),
          pw.SizedBox(height: 12),
          if (employeePerformance.isEmpty)
            _emptyState('No employee sales recorded')
          else ...[
            _buildBarChart(
              data: employeePerformance.map((e) => _ChartBar(
                label: _truncate((e['userName'] as String? ?? ' - ').split(' ').first, 10),
                value: (e['actionCount'] as num?)?.toDouble() ?? 0.0,
                subLabel: 'sales',
              )).toList(),
              color: _teal,
              valuePrefix: '',
              height: 130,
              isCount: true,
            ),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: _grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(24),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                _tableHeaderRow(['#', 'Employee', 'Sales Count', 'Performance']),
                ...employeePerformance.asMap().entries.map((e) {
                  final i = e.key;
                  final emp = e.value;
                  final count = (emp['actionCount'] as num?)?.toInt() ?? 0;
                  final maxCount = (employeePerformance.first['actionCount'] as num?)?.toInt() ?? 1;
                  final pct = maxCount > 0 ? (count / maxCount * 100).toInt() : 0;
                  final rank = i == 0 ? 'Top Performer' : i == 1 ? 'Strong' : count > 0 ? 'Active' : 'Inactive';
                  return _tableDataRow([
                    (i + 1).toString(),
                    emp['userName'] as String? ?? ' - ',
                    count.toString(),
                    '$rank ($pct%)',
                  ], i);
                }),
              ],
            ),
          ],
          pw.SizedBox(height: 28),

          _sectionTitle('Activity Breakdown (Last 7 Days)'),
          pw.SizedBox(height: 12),
          if (recentActivity.isEmpty)
            _emptyState('No activity recorded in the last 7 days')
          else
            pw.Table(
              border: pw.TableBorder.all(color: _grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FlexColumnWidth(1),
              },
              children: [
                _tableHeaderRow(['Employee', 'Action', 'Count']),
                ...recentActivity.take(25).toList().asMap().entries.map((e) {
                  final i = e.key;
                  final act = e.value;
                  final actionLabel = (act['action'] as String? ?? ' - ')
                      .replaceAll('_', ' ')
                      .split(' ')
                      .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
                      .join(' ');
                  return _tableDataRow([
                    act['userName'] as String? ?? ' - ',
                    actionLabel,
                    (act['count'] as num?)?.toInt().toString() ?? '0',
                  ], i);
                }),
              ],
            ),
        ],
      ),
    );

    // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
    //  PAGE 9  -  PROFIT & LOSS
    // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => _pageHeader('Profit & Loss', period, ctx.pageNumber),
        footer: (ctx) => _pageFooter(companyName, generated),
        build: (ctx) {
          final costPct = totalRevenue > 0 ? (totalCost / totalRevenue * 100) : 0.0;
          final profitPct = totalRevenue > 0 ? (grossProfit / totalRevenue * 100) : 0.0;
          final todayAvg = todayTransactions > 0 ? todaySales / todayTransactions : 0.0;
          final weekAvg = weekTransactions > 0 ? weekSales / weekTransactions : 0.0;
          final monthAvg = monthTransactions > 0 ? monthSales / monthTransactions : 0.0;

          return [
            _sectionTitle('Profit & Loss  -  $period'),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: _grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                _tableHeaderRow(['Line Item', 'Amount', 'vs Revenue']),
                _tableDataRow(['Total Revenue', '\$${_fmt.format(totalRevenue)}', '100%'], 0),
                _tableDataRow(['Cost of Goods Sold', '\$${_fmt.format(totalCost)}', '${costPct.toStringAsFixed(1)}%'], 1),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _greenLight),
                  children: [
                    _tc('Gross Profit', bold: true),
                    _tc('\$${_fmt.format(grossProfit)}', bold: true),
                    _tc('${profitPct.toStringAsFixed(1)}%', bold: true),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Visual P&L bar
            _sectionTitle('Revenue Composition'),
            pw.SizedBox(height: 12),
            _buildPLBar(costPct: costPct, profitPct: profitPct),
            pw.SizedBox(height: 24),

            _sectionTitle('Transaction Averages'),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: _grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                _tableHeaderRow(['Period', 'Revenue', 'Transactions', 'Avg per Txn']),
                _tableDataRow(['Today', '\$${_fmt.format(todaySales)}', todayTransactions.toString(), '\$${_fmt.format(todayAvg)}'], 0),
                _tableDataRow(['This Week', '\$${_fmt.format(weekSales)}', weekTransactions.toString(), '\$${_fmt.format(weekAvg)}'], 1),
                _tableDataRow(['This Month', '\$${_fmt.format(monthSales)}', monthTransactions.toString(), '\$${_fmt.format(monthAvg)}'], 2),
              ],
            ),
            pw.SizedBox(height: 28),

            _sectionTitle('Profitability Assessment'),
            pw.SizedBox(height: 10),
            _buildProfitAssessment(profitMargin),
          ];
        },
      ),
    );

    // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
    //  PAGE 10  -  AI INSIGHTS & RECOMMENDATIONS
    // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => _pageHeader('AI Insights & Recommendations', period, ctx.pageNumber),
        footer: (ctx) => _pageFooter(companyName, generated),
        build: (ctx) {
          // Auto-generate insights from data if none provided
          final insights = aiInsights.isNotEmpty ? aiInsights : _generateInsights(
            monthSales: monthSales,
            weekSales: weekSales,
            todaySales: todaySales,
            grossProfit: grossProfit,
            profitMargin: profitMargin,
            topProducts: topProducts,
            slowMovers: slowMovers,
            lowStockCount: lowStockCount,
            totalOrders: totalOrders,
            pendingOrders: pendingOrders,
            employeePerformance: employeePerformance,
          );
          final recommendations = aiRecommendations.isNotEmpty ? aiRecommendations : _generateRecommendations(
            profitMargin: profitMargin,
            slowMovers: slowMovers,
            lowStockCount: lowStockCount,
            topProducts: topProducts,
            pendingOrders: pendingOrders,
            totalOrders: totalOrders,
          );

          return [
            _infoBox(
              'AI insights are generated automatically based on your data patterns. '
              'They are intended to guide business decisions, not replace managerial judgment.',
              _blueLight, _blue,
            ),
            pw.SizedBox(height: 20),

            _sectionTitle('Business Insights'),
            pw.SizedBox(height: 12),
            ...insights.asMap().entries.map((e) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: _insightRow(e.key + 1, e.value, isPositive: !e.value.toLowerCase().contains('low') && !e.value.toLowerCase().contains('slow') && !e.value.toLowerCase().contains('no ') && !e.value.toLowerCase().contains('drop')),
            )),
            pw.SizedBox(height: 24),

            _sectionTitle('Recommendations'),
            pw.SizedBox(height: 12),
            ...recommendations.asMap().entries.map((e) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: _recommendationRow(e.key + 1, e.value),
            )),
            pw.SizedBox(height: 28),

            if (reorderAlerts.isNotEmpty) ...[
              _sectionTitle('Urgent: Stock Alerts'),
              pw.SizedBox(height: 10),
              ...reorderAlerts.take(5).map((a) {
                final days = (a['daysRemaining'] as num?)?.toInt() ?? 0;
                final rec = (a['recommendedOrder'] as num?)?.toInt() ?? 0;
                final name = a['productName'] as String? ?? ' - ';
                final urgency = days == 0 ? 'OUT OF STOCK  -  Order immediately' : 'Order $rec units within $days days';
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: _insightRow(0, '$name: $urgency', isPositive: false, isAlert: true),
                );
              }),
              pw.SizedBox(height: 20),
            ],

            // Closing statement
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: _grey100,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: _grey300, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Report Conclusion',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    _buildConclusion(monthSales: monthSales, profitMargin: profitMargin, totalOrders: totalOrders, companyName: companyName, period: period),
                    style: const pw.TextStyle(fontSize: 10, color: _grey700, lineSpacing: 2),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  // ----- EMPLOYEE SIMPLE REPORT (3 pages) -----------------------------------
  static Future<void> generateEmployeeSimpleReport({
    required String employeeName,
    required String companyName,
    required double todaySales,
    required double weekSales,
    required double monthSales,
    required int todayTransactions,
    required int weekTransactions,
    required int monthTransactions,
    required List<Map<String, dynamic>> topProducts,
    required List<Map<String, dynamic>> dailySales,
    required Map<String, dynamic> inventoryStats,
    required List<Map<String, dynamic>> stockHealth,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final period = DateFormat('MMMM yyyy').format(now);
    final generated = DateFormat('dd MMM yyyy | hh:mm a').format(now);

    // PAGE 1: COVER
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.Stack(children: [
        pw.Container(width: double.infinity, height: double.infinity, color: _white),
        pw.Positioned(top: 0, left: 0, child: pw.Container(width: 8, height: 841, color: _blue)),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(60, 80, 60, 60),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(companyName.toUpperCase(), style: pw.TextStyle(color: _blue, fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 3)),
            pw.SizedBox(height: 40),
            pw.Text('Daily\nSales\nSummary', style: pw.TextStyle(color: _black, fontSize: 48, fontWeight: pw.FontWeight.bold, lineSpacing: 4)),
            pw.SizedBox(height: 20),
            pw.Container(width: 80, height: 4, color: _blue),
            pw.SizedBox(height: 24),
            pw.Text(period, style: const pw.TextStyle(color: _grey700, fontSize: 18)),
            pw.SizedBox(height: 6),
            pw.Text('Prepared for: $employeeName', style: pw.TextStyle(color: _grey500, fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Generated: $generated', style: const pw.TextStyle(color: _grey500, fontSize: 11)),
            pw.Spacer(),
            pw.Container(height: 1, color: _grey300),
            pw.SizedBox(height: 16),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              _coverKPI('Today', '\$${_fmt.format(todaySales)}', _black),
              _coverKPI('Today Txns', todayTransactions.toString(), _black),
              _coverKPI('This Week', '\$${_fmt.format(weekSales)}', _black),
              _coverKPI('This Month', '\$${_fmt.format(monthSales)}', _black),
            ]),
          ]),
        ),
      ]),
    ));

    // PAGE 2: SALES DETAIL
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 36),
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _pageHeader('Sales Summary', period, 2),
        pw.SizedBox(height: 16),
        pw.Row(children: [
          pw.Expanded(child: _kpiCard('Today', '\$${_fmt.format(todaySales)}', '$todayTransactions transactions', _blue, _blueLight)),
          pw.SizedBox(width: 10),
          pw.Expanded(child: _kpiCard('This Week', '\$${_fmt.format(weekSales)}', '$weekTransactions transactions', _green, _greenLight)),
          pw.SizedBox(width: 10),
          pw.Expanded(child: _kpiCard('This Month', '\$${_fmt.format(monthSales)}', '$monthTransactions transactions', _purple, _purpleLight)),
        ]),
        pw.SizedBox(height: 16),
        _sectionTitle('Sales - Last 7 Days'),
        pw.SizedBox(height: 8),
        () {
          final bars = dailySales.map((d) {
            final date = DateTime.tryParse(d['date'] as String? ?? '');
            return _ChartBar(label: date != null ? DateFormat('EEE\ndd/MM').format(date) : '-', value: (d['total'] as num?)?.toDouble() ?? 0);
          }).toList();
          return bars.isEmpty ? _emptyState('No sales data') : _buildBarChart(data: bars, color: _blue, valuePrefix: r'$', height: 100);
        }(),
        pw.SizedBox(height: 16),
        _sectionTitle('Top Products This Month'),
        pw.SizedBox(height: 8),
        topProducts.isEmpty
          ? _emptyState('No product data')
          : pw.Table(
              border: pw.TableBorder.all(color: _grey300, width: 0.5),
              columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(2), 2: pw.FlexColumnWidth(2)},
              children: [
                pw.TableRow(decoration: const pw.BoxDecoration(color: _black), children: [
                  _tc('Product', bold: true, color: _white),
                  _tc('Units Sold', bold: true, color: _white),
                  _tc('Revenue', bold: true, color: _white),
                ]),
                ...topProducts.take(8).map((p) => pw.TableRow(children: [
                  _tc(p['productName'] as String? ?? '-'),
                  _tc((p['totalQuantity'] as num?)?.toInt().toString() ?? '0'),
                  _tc(r'$' + _fmt.format((p['totalRevenue'] as num?)?.toDouble() ?? 0)),
                ])),
              ],
            ),
      ]),
    ));

    // PAGE 3: INVENTORY STATUS
    final totalProducts = (inventoryStats['totalProducts'] as num?)?.toInt() ?? 0;
    final lowStockCount = (inventoryStats['lowStockCount'] as num?)?.toInt() ?? 0;
    final invValue = (inventoryStats['totalValue'] as num?)?.toDouble() ?? 0.0;

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 36),
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _pageHeader('Inventory Status', period, 3),
        pw.SizedBox(height: 16),
        pw.Row(children: [
          pw.Expanded(child: _kpiCard('Products', totalProducts.toString(), 'in catalogue', _teal, _tealLight)),
          pw.SizedBox(width: 10),
          pw.Expanded(child: _kpiCard('Low Stock', lowStockCount.toString(), 'need attention', lowStockCount > 0 ? _orange : _green, lowStockCount > 0 ? _orangeLight : _greenLight)),
          pw.SizedBox(width: 10),
          pw.Expanded(child: _kpiCard('Inv. Value', r'$' + _fmt.format(invValue), 'at selling price', _blue, _blueLight)),
        ]),
        pw.SizedBox(height: 16),
        _sectionTitle('Stock Health Overview'),
        pw.SizedBox(height: 8),
        stockHealth.isEmpty ? _emptyState('No stock data') : _buildStockHealthChart(stockHealth),
        pw.SizedBox(height: 6),
        _buildStockHealthLegend(),
        pw.SizedBox(height: 16),
        if (lowStockCount > 0)
          _infoBox('Please notify your manager about low or out-of-stock items so they can be reordered promptly.', _orangeLight, _orange),
      ]),
    ));

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }


  // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
  //  LEGACY per-tab exports (kept for compatibility)
  // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
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
    await generateComprehensiveReport(
      companyName: 'Aura Beverages',
      todaySales: todaySales, weekSales: weekSales, monthSales: monthSales,
      todayTransactions: todayTransactions, weekTransactions: weekTransactions, monthTransactions: monthTransactions,
      topProducts: topProducts, dailySales: dailySales,
      inventoryStats: {}, categoryData: [], topSellers: [], slowMovers: [], stockHealth: [],
      employeePerformance: [], recentActivity: [],
      profitAnalysis: {'totalRevenue': monthSales, 'totalCost': 0, 'grossProfit': monthSales, 'profitMargin': 100},
      ordersSummary: [], aiInsights: [], aiRecommendations: [], reorderAlerts: [],
    );
  }

  static Future<void> generateInventoryReport({
    required Map<String, dynamic> stats,
    required List<Map<String, dynamic>> categoryData,
  }) async {
    await generateComprehensiveReport(
      companyName: 'Aura Beverages',
      todaySales: 0, weekSales: 0, monthSales: 0,
      todayTransactions: 0, weekTransactions: 0, monthTransactions: 0,
      topProducts: [], dailySales: [],
      inventoryStats: stats, categoryData: categoryData, topSellers: [], slowMovers: [], stockHealth: [],
      employeePerformance: [], recentActivity: [],
      profitAnalysis: {}, ordersSummary: [], aiInsights: [], aiRecommendations: [], reorderAlerts: [],
    );
  }

  static Future<void> generateEmployeeReport({
    required List<Map<String, dynamic>> performance,
    required List<Map<String, dynamic>> activity,
  }) async {
    await generateComprehensiveReport(
      companyName: 'Aura Beverages',
      todaySales: 0, weekSales: 0, monthSales: 0,
      todayTransactions: 0, weekTransactions: 0, monthTransactions: 0,
      topProducts: [], dailySales: [],
      inventoryStats: {}, categoryData: [], topSellers: [], slowMovers: [], stockHealth: [],
      employeePerformance: performance, recentActivity: activity,
      profitAnalysis: {}, ordersSummary: [], aiInsights: [], aiRecommendations: [], reorderAlerts: [],
    );
  }

  static Future<void> generateProfitReport({
    required Map<String, dynamic> profitAnalysis,
  }) async {
    await generateComprehensiveReport(
      companyName: 'Aura Beverages',
      todaySales: 0, weekSales: 0, monthSales: 0,
      todayTransactions: 0, weekTransactions: 0, monthTransactions: 0,
      topProducts: [], dailySales: [],
      inventoryStats: {}, categoryData: [], topSellers: [], slowMovers: [], stockHealth: [],
      employeePerformance: [], recentActivity: [],
      profitAnalysis: profitAnalysis, ordersSummary: [], aiInsights: [], aiRecommendations: [], reorderAlerts: [],
    );
  }

  // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
  //  CHART BUILDERS
  // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|

  static pw.Widget _buildBarChart({
    required List<_ChartBar> data,
    required PdfColor color,
    required String valuePrefix,
    double height = 150,
    bool isCount = false,
  }) {
    if (data.isEmpty) return _emptyState('No data');
    final maxVal = data.map((b) => b.value).reduce(math.max);
    if (maxVal == 0) return _emptyState('No values to chart');

    return pw.Container(
      height: height + 60,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.CustomPaint(
              size: const PdfPoint(double.infinity, double.infinity),
              painter: (canvas, size) {
                final barCount = data.length;
                final totalWidth = size.x;
                final barAreaWidth = totalWidth / barCount;
                final barWidth = barAreaWidth * 0.55;
                final gap = (barAreaWidth - barWidth) / 2;
                final chartHeight = size.y - 2;

                // Draw gridlines — g=0 at bottom (y=0), g=4 at top (y=chartHeight)
                for (int g = 0; g <= 4; g++) {
                  final y = chartHeight * (g / 4);
                  canvas
                    ..setStrokeColor(_grey300)
                    ..setLineWidth(0.5)
                    ..moveTo(0, y)
                    ..lineTo(totalWidth, y)
                    ..strokePath();
                }

                for (int i = 0; i < barCount; i++) {
                  final bar = data[i];
                  final barHeight = chartHeight * (bar.value / maxVal);
                  final x = i * barAreaWidth + gap;

                  // Shadow (offset right/up slightly)
                  canvas
                    ..setFillColor(PdfColor(0, 0, 0, 0.05))
                    ..drawRect(x + 2, 2, barWidth, barHeight - 2)
                    ..fillPath();

                  // Bar — grows from y=0 (bottom) upward
                  canvas
                    ..setFillColor(color)
                    ..drawRect(x, 0, barWidth, barHeight)
                    ..fillPath();

                  // Highlight at top of bar
                  canvas
                    ..setFillColor(PdfColor(1, 1, 1, 0.25))
                    ..drawRect(x, barHeight - 3, barWidth, 3)
                    ..fillPath();
                }
              },
            ),
          ),
          // X-axis labels
          pw.Row(
            children: data.map((bar) => pw.Expanded(
              child: pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      bar.label,
                      style: const pw.TextStyle(fontSize: 7, color: _grey700),
                      textAlign: pw.TextAlign.center,
                    ),
                    if (bar.subLabel.isNotEmpty)
                      pw.Text(
                        bar.subLabel,
                        style: const pw.TextStyle(fontSize: 6, color: _grey500),
                        textAlign: pw.TextAlign.center,
                      ),
                  ],
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildHorizontalBarChart({
    required List<_HBar> bars,
    required String valuePrefix,
    bool isCount = false,
  }) {
    final maxVal = bars.map((b) => b.value).reduce(math.max);
    if (maxVal == 0) return pw.SizedBox();

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _grey300, width: 0.5),
      ),
      child: pw.Column(
        children: bars.map((bar) {
          final pct = maxVal > 0 ? bar.value / maxVal : 0.0;
          final label = isCount ? bar.value.toInt().toString() : '$valuePrefix${_fmt.format(bar.value)}';
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 80,
                  child: pw.Text(bar.label, style: const pw.TextStyle(fontSize: 10, color: _grey700)),
                ),
                pw.Expanded(
                  child: pw.SizedBox(
                    height: 18,
                    child: pw.Row(
                      children: [
                        if (pct > 0)
                          pw.Expanded(
                            flex: (pct * 1000).round().clamp(1, 1000),
                            child: pw.Container(
                              decoration: pw.BoxDecoration(
                                color: bar.color,
                                borderRadius: pw.BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        if (pct < 1.0)
                          pw.Expanded(
                            flex: ((1 - pct) * 1000).round().clamp(1, 1000),
                            child: pw.Container(color: _grey100),
                          ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static pw.Widget _buildCategoryShareChart(List<Map<String, dynamic>> cats, double total) {
    if (total == 0 || cats.isEmpty) return pw.SizedBox();
    final colors = [_blue, _green, _purple, _orange, _teal, _amber, _red, _grey700];

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _grey300, width: 0.5),
      ),
      child: pw.Column(
        children: cats.asMap().entries.map((e) {
          final c = e.value;
          final val = (c['totalValue'] as num?)?.toDouble() ?? 0.0;
          final pct = total > 0 ? val / total : 0.0;
          final color = colors[e.key % colors.length];
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 12,
                  height: 12,
                  decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(2)),
                ),
                pw.SizedBox(width: 8),
                pw.SizedBox(
                  width: 90,
                  child: pw.Text(
                    c['category'] as String? ?? ' - ',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.Expanded(
                  child: pw.SizedBox(
                    height: 14,
                    child: pw.Row(
                      children: [
                        if (pct > 0)
                          pw.Expanded(
                            flex: (pct * 1000).round().clamp(1, 1000),
                            child: pw.Container(
                              decoration: pw.BoxDecoration(
                                color: color,
                                borderRadius: pw.BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        if (pct < 1.0)
                          pw.Expanded(
                            flex: ((1 - pct) * 1000).round().clamp(1, 1000),
                            child: pw.Container(color: _grey100),
                          ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Text('${(pct * 100).toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static pw.Widget _buildStockHealthLegend() {
    final items = [
      ('Out of Stock', _red),
      ('Low Stock', _orange),
      ('Fair', _amber),
      ('Healthy', _green),
    ];
    return pw.Row(
      children: items.map((item) => pw.Padding(
        padding: const pw.EdgeInsets.only(right: 14),
        child: pw.Row(children: [
          pw.Container(
            width: 9,
            height: 9,
            decoration: pw.BoxDecoration(color: item.$2, shape: pw.BoxShape.circle),
          ),
          pw.SizedBox(width: 4),
          pw.Text(item.$1, style: pw.TextStyle(fontSize: 8, color: _grey500)),
        ]),
      )).toList(),
    );
  }

  static pw.Widget _buildStockHealthChart(List<Map<String, dynamic>> stockHealth) {
    final statusColors = {
      'Out of Stock': _red,
      'Low Stock': _orange,
      'Fair': _amber,
      'Healthy': _green,
    };
    final total = stockHealth.fold<int>(0, (s, h) => s + ((h['count'] as num?)?.toInt() ?? 0));

    return pw.Container(
      height: 28,
      decoration: pw.BoxDecoration(borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Row(
        children: stockHealth.asMap().entries.map((e) {
          final h = e.value;
          final status = h['status'] as String? ?? ' - ';
          final count = (h['count'] as num?)?.toInt() ?? 0;
          final pct = total > 0 ? count / total : 0.0;
          final color = statusColors[status] ?? _grey500;
          final isFirst = e.key == 0;
          final isLast = e.key == stockHealth.length - 1;
          return pw.Expanded(
            flex: (pct * 100).round().clamp(1, 100),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                color: color,
                borderRadius: pw.BorderRadius.only(
                  topLeft: isFirst ? const pw.Radius.circular(6) : pw.Radius.zero,
                  bottomLeft: isFirst ? const pw.Radius.circular(6) : pw.Radius.zero,
                  topRight: isLast ? const pw.Radius.circular(6) : pw.Radius.zero,
                  bottomRight: isLast ? const pw.Radius.circular(6) : pw.Radius.zero,
                ),
              ),
              alignment: pw.Alignment.center,
              child: count > 0
                  ? pw.Text('$count', style: const pw.TextStyle(fontSize: 8, color: _white))
                  : pw.SizedBox(),
            ),
          );
        }).toList(),
      ),
    );
  }

  static pw.Widget _buildPLBar({required double costPct, required double profitPct}) {
    return pw.Column(
      children: [
        pw.Container(
          height: 40,
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(6),
            color: _grey200,
          ),
          child: pw.Row(
            children: [
              if (costPct > 0)
                pw.Expanded(
                  flex: (costPct * 10).round().clamp(1, 999),
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      color: _orange,
                      borderRadius: const pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(6),
                        bottomLeft: pw.Radius.circular(6),
                      ),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      'COGS ${costPct.toStringAsFixed(1)}%',
                      style: const pw.TextStyle(color: _white, fontSize: 9),
                    ),
                  ),
                ),
              if (profitPct > 0)
                pw.Expanded(
                  flex: (profitPct * 10).round().clamp(1, 999),
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      color: _green,
                      borderRadius: pw.BorderRadius.only(
                        topLeft: costPct <= 0 ? const pw.Radius.circular(6) : pw.Radius.zero,
                        bottomLeft: costPct <= 0 ? const pw.Radius.circular(6) : pw.Radius.zero,
                        topRight: const pw.Radius.circular(6),
                        bottomRight: const pw.Radius.circular(6),
                      ),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      'PROFIT ${profitPct.toStringAsFixed(1)}%',
                      style: const pw.TextStyle(color: _white, fontSize: 9),
                    ),
                  ),
                ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            _legendDot(_orange, 'Cost of Goods'),
            pw.SizedBox(width: 20),
            _legendDot(_green, 'Gross Profit'),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildProfitAssessment(double margin) {
    final PdfColor color;
    final String assessment;
    final String advice;
    if (margin >= 30) {
      color = _green;
      assessment = 'Excellent';
      advice = 'Your profit margin is strong. Focus on volume growth and maintaining this margin through controlled costs.';
    } else if (margin >= 20) {
      color = _blue;
      assessment = 'Good';
      advice = 'Solid profitability. Look for opportunities to improve margins by reviewing your lowest-margin products.';
    } else if (margin >= 10) {
      color = _amber;
      assessment = 'Fair';
      advice = 'Margin is acceptable but there is room for improvement. Review slow movers and consider price adjustments.';
    } else if (margin >= 0) {
      color = _orange;
      assessment = 'Low';
      advice = 'Margins are thin. Urgently review pricing strategy, reduce dead stock, and cut unnecessary costs.';
    } else {
      color = _red;
      assessment = 'Loss';
      advice = 'The business is operating at a loss this period. Immediate action required  -  review all product pricing and costs.';
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor(color.red, color.green, color.blue, 0.08),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color, width: 1),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            children: [
              pw.Text(assessment.toUpperCase(), style: pw.TextStyle(color: color, fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('${margin.toStringAsFixed(1)}%', style: pw.TextStyle(color: color, fontSize: 13)),
            ],
          ),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Text(advice, style: const pw.TextStyle(fontSize: 10, lineSpacing: 2, color: _grey700)),
          ),
        ],
      ),
    );
  }

  // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
  //  LAYOUT HELPERS
  // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|

  static pw.Widget _pageHeader(String title, String period, int pageNumber) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 0),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _grey300, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _black)),
              pw.Text(period, style: const pw.TextStyle(fontSize: 10, color: _grey500)),
            ],
          ),
          pw.Text('Page $pageNumber', style: const pw.TextStyle(fontSize: 10, color: _grey500)),
        ],
      ),
    );
  }

  static pw.Widget _pageFooter(String company, String generated) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(company, style: const pw.TextStyle(fontSize: 8, color: _grey500)),
          pw.Text('Confidential  -  $generated', style: const pw.TextStyle(fontSize: 8, color: _grey500)),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _blue, width: 2)),
      ),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _black)),
    );
  }

  static pw.Widget _kpiCard(String title, String value, String sub, PdfColor color, PdfColor bg) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColor(color.red, color.green, color.blue, 0.3), width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 8, color: color, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _black)),
          pw.SizedBox(height: 2),
          pw.Text(sub, style: const pw.TextStyle(fontSize: 8, color: _grey500)),
        ],
      ),
    );
  }

  static pw.Widget _coverKPI(String label, String value, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(value, style: pw.TextStyle(color: color, fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Text(label, style: const pw.TextStyle(color: _grey500, fontSize: 9)),
      ],
    );
  }

  static pw.Widget _summaryBox(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _grey300, width: 0.5),
      ),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10, lineSpacing: 2, color: _grey700)),
    );
  }

  static pw.Widget _infoBox(String text, PdfColor bg, PdfColor border) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: border, width: 0.5),
      ),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9, lineSpacing: 2, color: _grey700)),
    );
  }

  static pw.Widget _successBox(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _greenLight,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _green, width: 0.5),
      ),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10, color: _green)),
    );
  }

  static pw.Widget _emptyState(String msg) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: _grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _grey300, width: 0.5),
      ),
      child: pw.Center(child: pw.Text(msg, style: const pw.TextStyle(color: _grey500, fontSize: 10))),
    );
  }

  static pw.Widget _insightRow(int num, String text, {bool isPositive = true, bool isAlert = false}) {
    final PdfColor color = isAlert ? _red : (isPositive ? _green : _amber);
    final PdfColor bg = isAlert ? _redLight : (isPositive ? _greenLight : _amberLight);
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColor(color.red, color.green, color.blue, 0.4), width: 0.5),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (num > 0) pw.Container(
            width: 20,
            height: 20,
            margin: const pw.EdgeInsets.only(right: 10),
            decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
            alignment: pw.Alignment.center,
            child: pw.Text('$num', style: const pw.TextStyle(color: _white, fontSize: 9)),
          ) else pw.SizedBox(width: 30),
          pw.Expanded(child: pw.Text(text, style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.5))),
        ],
      ),
    );
  }

  static pw.Widget _recommendationRow(int num, String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _blueLight,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColor(_blue.red, _blue.green, _blue.blue, 0.3), width: 0.5),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 20,
            height: 20,
            margin: const pw.EdgeInsets.only(right: 10),
            decoration: const pw.BoxDecoration(color: _blue, shape: pw.BoxShape.circle),
            alignment: pw.Alignment.center,
            child: pw.Text('$num', style: const pw.TextStyle(color: _white, fontSize: 9)),
          ),
          pw.Expanded(child: pw.Text(text, style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.5))),
        ],
      ),
    );
  }

  static pw.Widget _legendDot(PdfColor color, String label) {
    return pw.Row(
      children: [
        pw.Container(width: 10, height: 10, decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle)),
        pw.SizedBox(width: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _grey700)),
      ],
    );
  }

  // â”€â”€ Table helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static pw.TableRow _tableHeaderRow(List<String> headers) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: _black),
      children: headers.map((h) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: pw.Text(h, style: pw.TextStyle(color: _white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
      )).toList(),
    );
  }

  static pw.TableRow _tableDataRow(List<String> cells, int rowIndex) {
    final bg = rowIndex.isEven ? _white : _grey50;
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bg),
      children: cells.map((c) => _tc(c)).toList(),
    );
  }

  static pw.Widget _tc(String text, {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9, color: color,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|
  //  AI TEXT GENERATORS
  // â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|â|

  static List<String> _generateInsights({
    required double monthSales,
    required double weekSales,
    required double todaySales,
    required double grossProfit,
    required double profitMargin,
    required List<Map<String, dynamic>> topProducts,
    required List<Map<String, dynamic>> slowMovers,
    required int lowStockCount,
    required int totalOrders,
    required int pendingOrders,
    required List<Map<String, dynamic>> employeePerformance,
  }) {
    final insights = <String>[];

    // Revenue insight
    final projectedMonth = weekSales * 4.33;
    if (projectedMonth > monthSales * 1.1) {
      insights.add('Sales are trending upward. Based on this week\'s performance (\$${_fmt.format(weekSales)}), the month is on track to exceed current totals  -  a positive growth signal.');
    } else {
      insights.add('Monthly revenue stands at \$${_fmt.format(monthSales)} with \$${_fmt.format(weekSales)} recorded this week. Revenue appears stable; watch for seasonal fluctuations.');
    }

    // Profit insight
    if (profitMargin >= 25) {
      insights.add('Gross profit margin of ${profitMargin.toStringAsFixed(1)}% is above industry benchmark for beverages. The business is pricing its products effectively.');
    } else if (profitMargin >= 10) {
      insights.add('Gross profit margin of ${profitMargin.toStringAsFixed(1)}% is moderate. There may be opportunity to review pricing on high-volume items to improve margins.');
    } else {
      insights.add('Gross profit margin of ${profitMargin.toStringAsFixed(1)}% is below the recommended 20% target for beverage retail. Urgent pricing review is recommended.');
    }

    // Top product insight
    if (topProducts.isNotEmpty) {
      final top = topProducts.first;
      final topRev = (top['totalRevenue'] as num?)?.toDouble() ?? 0;
      final topName = top['productName'] as String? ?? ' - ';
      final topShare = monthSales > 0 ? (topRev / monthSales * 100) : 0.0;
      insights.add('"$topName" is the top revenue driver, contributing \$${_fmt.format(topRev)} (${topShare.toStringAsFixed(1)}% of monthly sales). Ensure this product is consistently well-stocked.');
    }

    // Slow movers
    if (slowMovers.isNotEmpty) {
      final names = slowMovers.take(3).map((p) => p['name'] as String? ?? '').join(', ');
      insights.add('${slowMovers.length} products are slow-moving (including $names). These tie up working capital  -  consider promotions or reduced reorder quantities.');
    } else {
      insights.add('No slow-moving products detected. All catalogue items are generating regular sales  -  strong inventory management.');
    }

    // Stock insight
    if (lowStockCount > 0) {
      insights.add('$lowStockCount product(s) are below safe stock levels. Immediate reordering is required to prevent stockouts and lost sales opportunities.');
    } else {
      insights.add('All products are adequately stocked. No stockouts or low-stock situations detected  -  inventory management is on track.');
    }

    // Orders
    if (totalOrders > 0 && pendingOrders > 3) {
      insights.add('$pendingOrders orders are pending fulfilment. A high backlog can impact customer satisfaction  -  prioritise clearing outstanding orders.');
    } else if (totalOrders > 0) {
      insights.add('Order fulfilment is healthy with $pendingOrders pending orders. Customer orders are being processed efficiently.');
    }

    // Employee
    if (employeePerformance.isNotEmpty) {
      final top = employeePerformance.first;
      insights.add('"${top['userName']}" leads employee sales performance. Recognition programmes can help maintain high performers and motivate others.');
    }

    return insights;
  }

  static List<String> _generateRecommendations({
    required double profitMargin,
    required List<Map<String, dynamic>> slowMovers,
    required int lowStockCount,
    required List<Map<String, dynamic>> topProducts,
    required int pendingOrders,
    required int totalOrders,
  }) {
    final recs = <String>[];

    if (lowStockCount > 0) {
      recs.add('Reorder $lowStockCount low-stock items immediately. Use the AI reorder alerts to determine optimal quantities. Stockouts can cost the business up to 30% in lost sales.');
    }

    if (profitMargin < 20) {
      recs.add('Review selling prices for your top 5 products. Even a 5% price increase on high-volume items can significantly improve your overall margin without impacting demand heavily.');
    }

    if (slowMovers.length > 3) {
      recs.add('Run a targeted promotion on slow-moving stock  -  offer a 10 - 15% discount bundle or pair them with top sellers. This converts dead stock into cash flow.');
    }

    if (topProducts.length >= 3) {
      final top3Names = topProducts.take(3).map((p) => p['productName'] as String? ?? '').join(', ');
      recs.add('Your top 3 products ($top3Names) drive the majority of revenue. Maintain safety stock of at least 30 days\' worth for each to avoid revenue disruption.');
    }

    if (pendingOrders > 5) {
      recs.add('Clear the order backlog by assigning dedicated order processing time each morning. A fast fulfilment rate (under 24 hours) improves customer retention and repeat business.');
    }

    recs.add('Schedule a weekly stock count on Friday afternoons to ensure inventory data accuracy. Accurate stock levels improve AI forecasting and prevent over- or under-ordering.');

    recs.add('Review product categories quarterly. Discontinue products that have had zero sales in 60+ days and replace them with trending alternatives based on customer requests.');

    recs.add('Track the best-performing days of the week and ensure maximum staff coverage on those days to capitalise on peak demand periods.');

    return recs;
  }

  static String _buildSummaryText({
    required double monthSales,
    required int monthTransactions,
    required double grossProfit,
    required double profitMargin,
    required List<Map<String, dynamic>> topProducts,
    required int lowStockCount,
    required int totalOrders,
    required int completedOrders,
  }) {
    final topProductName = topProducts.isNotEmpty ? (topProducts.first['productName'] as String? ?? ' - ') : 'N/A';
    return 'This report covers business performance for the current month. '
        'Total revenue of \$${_fmt.format(monthSales)} was generated across $monthTransactions transactions, '
        'yielding a gross profit of \$${_fmt.format(grossProfit)} at a ${profitMargin.toStringAsFixed(1)}% margin. '
        '"$topProductName" was the top-performing product by revenue. '
        '${lowStockCount > 0 ? '$lowStockCount product(s) require restocking. ' : 'All stock levels are healthy. '}'
        'A total of $totalOrders orders were processed, of which $completedOrders were completed and delivered. '
        'This report should be reviewed weekly by management to guide purchasing, staffing, and pricing decisions.';
  }

  static String _buildConclusion({
    required double monthSales,
    required double profitMargin,
    required int totalOrders,
    required String companyName,
    required String period,
  }) {
    final perfLabel = profitMargin >= 20 ? 'strong' : profitMargin >= 10 ? 'moderate' : 'below-target';
    return '$companyName achieved \$${_fmt.format(monthSales)} in revenue during $period '
        'with $perfLabel profitability at ${profitMargin.toStringAsFixed(1)}% gross margin. '
        'A total of $totalOrders customer orders were managed during this period. '
        'The insights and recommendations in this report are designed to help management make '
        'data-driven decisions on inventory, pricing, and operations. '
        'This report was generated automatically by the Aura business intelligence system.';
  }

  // â”€â”€ Utility â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static String _truncate(String s, int max) => s.length > max ? '${s.substring(0, max)}...' : s;

  static String _stockAction(String status) {
    switch (status) {
      case 'Out of Stock': return 'Order immediately  -  no stock available for sale';
      case 'Low Stock': return 'Reorder soon  -  stock below safe threshold';
      case 'Fair': return 'Monitor  -  approaching low stock level';
      case 'Healthy': return 'No action needed';
      default: return ' - ';
    }
  }

  // Kept for backward-compat
  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) => _tc(text, bold: isHeader);
}

// â”€â”€ Data models â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ChartBar {
  final String label;
  final double value;
  final String subLabel;
  const _ChartBar({required this.label, required this.value, this.subLabel = ''});
}

class _HBar {
  final String label;
  final double value;
  final PdfColor color;
  const _HBar(this.label, this.value, this.color);
}
