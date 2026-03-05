import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/user.dart';
import '../helpers/pdf_report_generator.dart';

class ReportsScreen extends StatefulWidget {
  final User? currentUser;

  const ReportsScreen({super.key, this.currentUser});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  late TabController _tabController;
  bool _isLoading = true;

  // Sales Data
  double _todaySales = 0.0;
  double _weekSales = 0.0;
  double _monthSales = 0.0;
  int _todayTransactions = 0;
  int _weekTransactions = 0;
  int _monthTransactions = 0;
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _dailySalesData = [];

  // Inventory Data
  Map<String, dynamic> _inventoryStats = {};
  List<Map<String, dynamic>> _categoryData = [];

  // Employee Data
  List<Map<String, dynamic>> _employeePerformance = [];
  List<Map<String, dynamic>> _recentActivity = [];

  // Profit Data
  Map<String, dynamic> _profitAnalysis = {};

  bool get _isManager => widget.currentUser?.isManager ?? false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isManager ? 4 : 2, vsync: this);
    _loadReportsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReportsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      final todayStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).toIso8601String();
      final weekStart = now.subtract(const Duration(days: 7)).toIso8601String();
      final monthStart = DateTime(now.year, now.month, 1).toIso8601String();

      // Load Sales Data
      _todaySales = await _dbHelper.getTotalSales(
        startDate: todayStart,
        endDate: now.toIso8601String(),
      );
      _weekSales = await _dbHelper.getTotalSales(
        startDate: weekStart,
        endDate: now.toIso8601String(),
      );
      _monthSales = await _dbHelper.getTotalSales(
        startDate: monthStart,
        endDate: now.toIso8601String(),
      );

      _todayTransactions = await _dbHelper.getTotalSalesCount(
        startDate: todayStart,
        endDate: now.toIso8601String(),
      );
      _weekTransactions = await _dbHelper.getTotalSalesCount(
        startDate: weekStart,
        endDate: now.toIso8601String(),
      );
      _monthTransactions = await _dbHelper.getTotalSalesCount(
        startDate: monthStart,
        endDate: now.toIso8601String(),
      );

      _topProducts = await _dbHelper.getSalesByProduct(
        startDate: monthStart,
        endDate: now.toIso8601String(),
      );

      _dailySalesData = await _dbHelper.getDailySales(days: 7);

      // Load Inventory Data
      _inventoryStats = await _dbHelper.getInventoryStats();
      _categoryData = await _dbHelper.getProductsByCategory();

      // Load Employee Data (Manager only)
      if (_isManager) {
        _employeePerformance = await _dbHelper.getEmployeePerformance();
        _recentActivity = await _dbHelper.getEmployeeActivity(days: 7);
        _profitAnalysis = await _dbHelper.getProfitAnalysis(
          startDate: monthStart,
          endDate: now.toIso8601String(),
        );
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading reports: $e')));
      }
    }
  }

  Future<void> _exportCurrentTab() async {
    try {
      final currentIndex = _tabController.index;

      if (currentIndex == 0) {
        // Sales Tab
        await PdfReportGenerator.generateSalesReport(
          todaySales: _todaySales,
          weekSales: _weekSales,
          monthSales: _monthSales,
          todayTransactions: _todayTransactions,
          weekTransactions: _weekTransactions,
          monthTransactions: _monthTransactions,
          topProducts: _topProducts,
          dailySales: _dailySalesData,
        );
      } else if (currentIndex == 1) {
        // Inventory Tab
        await PdfReportGenerator.generateInventoryReport(
          stats: _inventoryStats,
          categoryData: _categoryData,
        );
      } else if (_isManager && currentIndex == 2) {
        // Employees Tab
        await PdfReportGenerator.generateEmployeeReport(
          performance: _employeePerformance,
          activity: _recentActivity,
        );
      } else if (_isManager && currentIndex == 3) {
        // Profit Tab
        await PdfReportGenerator.generateProfitReport(
          profitAnalysis: _profitAnalysis,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ PDF report generated successfully!'),
            backgroundColor: Colors.black87,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Reports & Analytics',
          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: -0.5),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: TabBar(
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: Colors.black,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
          controller: _tabController,
          isScrollable: false,
          tabs: [
            const Tab(text: 'Sales', icon: Icon(Icons.point_of_sale, size: 20)),
            const Tab(
              text: 'Inventory',
              icon: Icon(Icons.inventory_2, size: 20),
            ),
            if (_isManager) ...[
              const Tab(text: 'Employees', icon: Icon(Icons.people, size: 20)),
              const Tab(
                text: 'Profit',
                icon: Icon(Icons.trending_up, size: 20),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.black87),
            onPressed: _exportCurrentTab,
            tooltip: 'Export as PDF',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadReportsData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSalesTab(),
                _buildInventoryTab(),
                if (_isManager) ...[_buildEmployeesTab(), _buildProfitTab()],
              ],
            ),
    );
  }

  // ==================== SALES TAB ====================

  Widget _buildSalesTab() {
    return RefreshIndicator(
      onRefresh: _loadReportsData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Period Stats
          Text('Sales Overview', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),
          _buildSalesStatsCards(),
          const SizedBox(height: 24),

          // Daily Sales Trend
          Text('Sales Trend (Last 7 Days)', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          _buildDailySalesTrend(),
          const SizedBox(height: 24),

          // Top Products
          Text('Top Products This Month', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          _buildTopProducts(),
        ],
      ),
    );
  }

  Widget _buildSalesStatsCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Today',
                '\$${_todaySales.toStringAsFixed(2)}',
                '$_todayTransactions transactions',
                Colors.blue,
                Icons.today,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'This Week',
                '\$${_weekSales.toStringAsFixed(2)}',
                '$_weekTransactions transactions',
                Colors.green,
                Icons.date_range,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'This Month',
          '\$${_monthSales.toStringAsFixed(2)}',
          '$_monthTransactions transactions',
          Colors.purple,
          Icons.calendar_month,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildDailySalesTrend() {
    if (_dailySalesData.isEmpty) {
      return Container( padding: const EdgeInsets.all(0), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)), child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No sales data for the past 7 days',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    final maxSale = _dailySalesData
        .map((d) => (d['total'] as num?)?.toDouble() ?? 0.0)
        .reduce((a, b) => a > b ? a : b);

    return Container( padding: const EdgeInsets.all(0), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)), child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _dailySalesData.map((data) {
            final date = DateTime.parse(data['date'] as String);
            final total = (data['total'] as num?)?.toDouble() ?? 0.0;
            final count = (data['count'] as num?)?.toInt() ?? 0;
            final percentage = maxSale > 0 ? (total / maxSale) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(
                          DateFormat('MMM dd').format(date),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            widthFactor: percentage,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '\$${total.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 70),
                    child: Text(
                      '$count ${count == 1 ? 'transaction' : 'transactions'}',
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTopProducts() {
    if (_topProducts.isEmpty) {
      return Container( padding: const EdgeInsets.all(0), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)), child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No product sales this month',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return Column(
      children: _topProducts.take(5).map((product) {
        final name = product['productName'] as String;
        final quantity = (product['totalQuantity'] as num?)?.toInt() ?? 0;
        final revenue = (product['totalRevenue'] as num?)?.toDouble() ?? 0.0;
        final transactions =
            (product['transactionCount'] as num?)?.toInt() ?? 0;

        return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(0), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)), child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1565C0).withOpacity(0.1),
              child: const Icon(
                Icons.local_drink,
                color: Color(0xFF1565C0),
                size: 24,
              ),
            ),
            title: Text(
              name,
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '$quantity units • $transactions ${transactions == 1 ? 'sale' : 'sales'}',
            ),
            trailing: Text(
              '\$${revenue.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ==================== INVENTORY TAB ====================

  Widget _buildInventoryTab() {
    return RefreshIndicator(
      onRefresh: _loadReportsData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Inventory Overview', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),
          _buildInventoryStatsCards(),
          const SizedBox(height: 24),

          Text('Products by Category', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          _buildCategoryBreakdown(),
        ],
      ),
    );
  }

  Widget _buildInventoryStatsCards() {
    final totalProducts = _inventoryStats['totalProducts'] ?? 0;
    final totalValue =
        (_inventoryStats['totalValue'] as num?)?.toDouble() ?? 0.0;
    final totalCost = (_inventoryStats['totalCost'] as num?)?.toDouble() ?? 0.0;
    final potentialProfit =
        (_inventoryStats['potentialProfit'] as num?)?.toDouble() ?? 0.0;
    final lowStockCount = _inventoryStats['lowStockCount'] ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Products',
                totalProducts.toString(),
                'items in stock',
                Colors.blue,
                Icons.inventory_2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Low Stock',
                lowStockCount.toString(),
                'need attention',
                Colors.orange,
                Icons.warning_amber,
              ),
            ),
          ],
        ),
        if (_isManager) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Value',
                  '\$${totalValue.toStringAsFixed(2)}',
                  'selling price',
                  Colors.green,
                  Icons.attach_money,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total Cost',
                  '\$${totalCost.toStringAsFixed(2)}',
                  'cost price',
                  Colors.purple,
                  Icons.shopping_cart,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Potential Profit',
            '\$${potentialProfit.toStringAsFixed(2)}',
            'if all sold at retail',
            Colors.teal,
            Icons.trending_up,
            fullWidth: true,
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryBreakdown() {
    if (_categoryData.isEmpty) {
      return Container( padding: const EdgeInsets.all(0), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)), child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No category data available',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return Column(
      children: _categoryData.map((category) {
        final name = category['category'] as String;
        final count = (category['productCount'] as num?)?.toInt() ?? 0;
        final quantity = (category['totalQuantity'] as num?)?.toInt() ?? 0;
        final value = (category['totalValue'] as num?)?.toDouble() ?? 0.0;

        return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(0), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)), child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.withOpacity(0.1),
              child: const Icon(Icons.category, color: Colors.purple),
            ),
            title: Text(
              name,
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('$count products • $quantity units in stock'),
            trailing: _isManager
                ? Text(
                    '\$${value.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  )
                : Text(
                    '$quantity units',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        );
      }).toList(),
    );
  }

  // ==================== EMPLOYEES TAB (Manager Only) ====================

  Widget _buildEmployeesTab() {
    return RefreshIndicator(
      onRefresh: _loadReportsData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Employee Performance', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),
          _buildEmployeePerformance(),
          const SizedBox(height: 24),

          Text('Recent Activity (Last 7 Days)', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildEmployeePerformance() {
    if (_employeePerformance.isEmpty) {
      return Container( padding: const EdgeInsets.all(0), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)), child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No employee sales recorded yet',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return Column(
      children: _employeePerformance.map((employee) {
        final name = employee['userName'] as String;
        final salesCount = (employee['actionCount'] as num?)?.toInt() ?? 0;

        return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(0), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)), child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1565C0),
              child: Text(
                name[0].toUpperCase(),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              name,
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '$salesCount ${salesCount == 1 ? 'sale' : 'sales'} recorded',
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$salesCount',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentActivity() {
    if (_recentActivity.isEmpty) {
      return Container( padding: const EdgeInsets.all(0), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)), child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No recent activity',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    // Group by user
    final Map<String, List<Map<String, dynamic>>> groupedActivity = {};
    for (var activity in _recentActivity) {
      final userName = activity['userName'] as String;
      groupedActivity.putIfAbsent(userName, () => []).add(activity);
    }

    return Column(
      children: groupedActivity.entries.map((entry) {
        final userName = entry.key;
        final activities = entry.value;
        final totalActions = activities.fold<int>(
          0,
          (sum, a) => sum + ((a['count'] as num?)?.toInt() ?? 0),
        );

        return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(0), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)), child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Text(
                userName[0].toUpperCase(),
                style: GoogleFonts.poppins(
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              userName,
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('$totalActions actions this week'),
            children: activities.map((activity) {
              final action = activity['action'] as String;
              final count = (activity['count'] as num?)?.toInt() ?? 0;
              final actionLabel = action
                  .replaceAll('_', ' ')
                  .split(' ')
                  .map((w) => w[0].toUpperCase() + w.substring(1))
                  .join(' ');

              return ListTile(
                dense: true,
                leading: Icon(_getActionIcon(action), size: 20),
                title: Text(actionLabel),
                trailing: Text(
                  '$count',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'record_sale':
        return Icons.point_of_sale;
      case 'add_product':
        return Icons.add_box;
      case 'edit_product':
        return Icons.edit;
      case 'delete_product':
        return Icons.delete;
      default:
        return Icons.circle;
    }
  }

  // ==================== PROFIT TAB (Manager Only) ====================

  Widget _buildProfitTab() {
    return RefreshIndicator(
      onRefresh: _loadReportsData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Profit Analysis (This Month)', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),
          _buildProfitCards(),
          const SizedBox(height: 24),

          _buildProfitBreakdown(),
        ],
      ),
    );
  }

  Widget _buildProfitCards() {
    final revenue =
        (_profitAnalysis['totalRevenue'] as num?)?.toDouble() ?? 0.0;
    final cost = (_profitAnalysis['totalCost'] as num?)?.toDouble() ?? 0.0;
    final profit = (_profitAnalysis['grossProfit'] as num?)?.toDouble() ?? 0.0;
    final margin = (_profitAnalysis['profitMargin'] as num?)?.toDouble() ?? 0.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Revenue',
                '\$${revenue.toStringAsFixed(2)}',
                'sales income',
                Colors.green,
                Icons.attach_money,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Total Cost',
                '\$${cost.toStringAsFixed(2)}',
                'goods sold',
                Colors.orange,
                Icons.shopping_cart,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Gross Profit',
                '\$${profit.toStringAsFixed(2)}',
                'revenue - cost',
                Colors.blue,
                Icons.trending_up,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Profit Margin',
                '${margin.toStringAsFixed(1)}%',
                'profit / revenue',
                Colors.purple,
                Icons.percent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfitBreakdown() {
    final revenue =
        (_profitAnalysis['totalRevenue'] as num?)?.toDouble() ?? 0.0;
    final cost = (_profitAnalysis['totalCost'] as num?)?.toDouble() ?? 0.0;
    final profit = (_profitAnalysis['grossProfit'] as num?)?.toDouble() ?? 0.0;

    if (revenue == 0) {
      return Container( padding: const EdgeInsets.all(0), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)), child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No sales data this month',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    final costPercentage = (cost / revenue) * 100;
    final profitPercentage = (profit / revenue) * 100;

    return Container( padding: const EdgeInsets.all(0), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)), child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revenue Breakdown', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 16),

            // Visual breakdown
            Container(
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200],
              ),
              child: Row(
                children: [
                  if (cost > 0)
                    Expanded(
                      flex: (costPercentage * 100).toInt(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${costPercentage.toStringAsFixed(1)}%',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  if (profit > 0)
                    Expanded(
                      flex: (profitPercentage * 100).toInt(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.only(
                            topRight: const Radius.circular(8),
                            bottomRight: const Radius.circular(8),
                            topLeft: cost == 0
                                ? const Radius.circular(8)
                                : Radius.zero,
                            bottomLeft: cost == 0
                                ? const Radius.circular(8)
                                : Radius.zero,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${profitPercentage.toStringAsFixed(1)}%',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(
                  'Cost',
                  Colors.orange,
                  '\$${cost.toStringAsFixed(2)}',
                ),
                _buildLegendItem(
                  'Profit',
                  Colors.green,
                  '\$${profit.toStringAsFixed(2)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, String value) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== SHARED WIDGETS ====================
  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    Color color,
    IconData icon, {
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: GoogleFonts.poppins(fontSize: fullWidth ? 28 : 24, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }
}