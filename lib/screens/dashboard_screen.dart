import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../models/audit_log.dart';
import '../helpers/demo_data_helper.dart';
import '../services/sync_service.dart';
import '../services/notification_service.dart';
import '../services/session_manager.dart';
import 'login_screen.dart';
import 'user_management_screen.dart';
import 'stock_adjustment_screen.dart';
import 'orders_screen.dart';
import '../widgets/ai_insights_widget.dart';
import '../widgets/sales_chart_widget.dart';
import 'excel_import_screen.dart';

class DashboardScreen extends StatefulWidget {
  final User? currentUser;

  const DashboardScreen({super.key, this.currentUser});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  StreamSubscription<SyncEvent>? _syncSubscription;

  int _totalProducts = 0;
  double _totalInventoryValue = 0.0;
  int _lowStockCount = 0;
  List<Product> _lowStockProducts = [];
  bool _isLoading = true;
  final Set<int> _orderedProductIds = {};
  int _pendingOrderCount = 0;
  final _chartKey = GlobalKey();

  bool get _isManager => widget.currentUser?.isManager ?? false;
  bool get _isStaff => widget.currentUser?.isStaff ?? false;
  bool get _hasNoData => _totalProducts == 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    // Listen for real-time cloud sync events
    _syncSubscription = SyncService.instance.onSync.listen((event) {
      if (event.table == SyncTable.products ||
          event.table == SyncTable.auditLogs ||
          event.table == SyncTable.all) {
        _refreshDashboardData();
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    await _fetchData();
  }

  /// Silently refresh data without showing a loading spinner.
  Future<void> _refreshDashboardData() async {
    await _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final productCount = await _dbHelper.getProductCount();
      final inventoryValue = await _dbHelper.getTotalInventoryValue();
      final lowStockProducts = await _dbHelper.getLowStockProducts();
      int pendingOrders = 0;
      try { pendingOrders = await _dbHelper.getOrderCount(status: 'pending'); } catch (_) {}

      if (mounted) {
        setState(() {
          _totalProducts = productCount;
          _totalInventoryValue = inventoryValue;
          _lowStockProducts = lowStockProducts;
          _lowStockCount = lowStockProducts.length;
          _pendingOrderCount = pendingOrders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading dashboard: $e')));
      }
    }
  }

  Future<void> _loadDemoData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Load Demo Data?'),
        content: const Text(
          'This will add:\n• 10 sample products\n• 5 sample employees\n• 24 sample sales\n\nPerfect for testing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Load Demo Data',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);

      try {
        await DemoDataHelper.loadDemoData(widget.currentUser!);
        SyncService.instance.notifyLocal(SyncTable.all);
        // Push all demo data to Supabase
        await SyncService.instance.pushAll(DatabaseHelper.instance.currentCompanyId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demo data loaded successfully!'),
              backgroundColor: Colors.black87,
            ),
          );
        }
        await _loadDashboardData();
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _clearDemoData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will remove all products, sales, and employees (except you). Cannot be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Clear All',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);

      try {
        await DemoDataHelper.clearAllData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All data cleared!'),
              backgroundColor: Colors.black87,
            ),
          );
        }
        await _loadDashboardData();
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _sendTestNotification() async {
    // Send the notification
    await NotificationService.instance.showCloudSyncNotification(1);

    if (!mounted) return;

    // Always show an in-app banner since the OS won't popup while the app is in the foreground
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_done, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Notification sent! Press Home to see the popup banner.',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _openExcelImport() async {
    if (widget.currentUser == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ExcelImportScreen(currentUser: widget.currentUser!),
      ),
    );
    if (result == true) {
      await _loadDashboardData();
      // Rebuild chart with fresh data
      setState(() {});
    }
  }

  Future<void> _showSessionTimeoutDialog() async {
    final session = SessionManager.instance;
    final currentMinutes = session.isEnabled ? session.timeoutDuration.inMinutes : 0;
    int selected = currentMinutes;

    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Session Timeout', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Auto-logout after inactivity:', style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 16),
              ...[ 
                {'label': '5 minutes', 'value': 5},
                {'label': '15 minutes', 'value': 15},
                {'label': '30 minutes', 'value': 30},
                {'label': 'Never', 'value': 0},
              ].map((opt) => RadioListTile<int>(
                title: Text(opt['label'] as String, style: GoogleFonts.poppins(fontSize: 14)),
                value: opt['value'] as int,
                groupValue: selected,
                activeColor: Colors.black,
                onChanged: (v) => setDialogState(() => selected = v!),
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Save', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await session.setTimeoutMinutes(result);
      if (result > 0) {
        session.startMonitoring(() {
          // Timeout handler in HomeScreen will handle this
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result > 0 ? 'Timeout set to $result minutes' : 'Session timeout disabled'),
            backgroundColor: Colors.black87,
          ),
        );
      }
    }
  }

  Future<void> _sendOrderRequest(Product product) async {
    if (widget.currentUser == null) return;

    final deficit = product.minQuantity - product.quantity;
    final actionDetail =
        'Reorder request for ${product.name} (stock: ${product.quantity}, min: ${product.minQuantity}, need: $deficit) | product_id:${product.id} | min_required:${product.minQuantity}';

    await _dbHelper.logAction(AuditLog(
      companyId: DatabaseHelper.instance.currentCompanyId,
      userId: widget.currentUser!.id!,
      userName: widget.currentUser!.fullName,
      action: 'order_request',
      details: actionDetail,
      timestamp: DateTime.now().toIso8601String(),
    ));

    setState(() {
      _orderedProductIds.add(product.id!);
    });

    // Fire a local push notification so it appears outside the app
    await NotificationService.instance.showInstantNotification(
      '📋 Order Request Created',
      '${product.name}: need $deficit units (stock: ${product.quantity}, min: ${product.minQuantity})',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order request created for ${product.name} (need $deficit units)',
          ),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFFFF8E1,
      ), // Slight warm tint on background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aura',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: -0.5,
              ),
            ),
            if (widget.currentUser != null)
              Text(
                'Hi, ${widget.currentUser!.fullName.split(' ').first}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        actions: [
          if (widget.currentUser != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _isManager
                    ? const Color(0xFFE0E0E0)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Center(
                child: Text(
                  _isManager ? 'MANAGER' : 'STAFF',
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          if (_isManager)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black87),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (value) {
                if (value == 'load_demo')
                  _loadDemoData();
                else if (value == 'clear_data')
                  _clearDemoData();
                else if (value == 'session_timeout')
                  _showSessionTimeoutDialog();
                else if (value == 'import_excel')
                  _openExcelImport();
                else if (value == 'test_notification')
                  _sendTestNotification();
                else if (value == 'logout')
                  _logout();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'load_demo',
                  child: Text('Load Demo Data'),
                ),
                const PopupMenuItem(
                  value: 'import_excel',
                  child: Row(
                    children: [
                      Icon(Icons.upload_file_outlined, size: 18, color: Colors.black87),
                      SizedBox(width: 12),
                      Text('Import Sales (Excel)'),
                    ],
                  ),
                ),
                if (!_hasNoData)
                  const PopupMenuItem(
                    value: 'clear_data',
                    child: Text(
                      'Clear All Data',
                      style: TextStyle(color: Color(0xFFE53935)),
                    ),
                  ),
                const PopupMenuItem(
                  value: 'session_timeout',
                  child: Text('Session Timeout'),
                ),
                const PopupMenuItem(
                  value: 'test_notification',
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active_outlined, size: 18, color: Colors.black87),
                      SizedBox(width: 12),
                      Text('Test Notification'),
                    ],
                  ),
                ),
                const PopupMenuItem(value: 'logout', child: Text('Logout')),
              ],
            )
          else
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black87),
              onPressed: _logout,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFB300)),
            )
          : RefreshIndicator(
              color: const Color(0xFFFFB300),
              onRefresh: _refreshDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isManager && _hasNoData) ...[
                      _buildDemoDataBanner(),
                      const SizedBox(height: 32),
                    ],
                    _buildStatisticsCards(),
                    const SizedBox(height: 32),
                    if (!_hasNoData) ...[
                      SalesChartWidget(key: _chartKey),
                      const SizedBox(height: 32),
                    ],
                    if (!_isStaff && !_hasNoData) ...[
                      const AIInsightsWidget(),
                      const SizedBox(height: 32),
                    ],
                    if (_lowStockCount > 0) ...[
                      _buildLowStockSection(),
                      const SizedBox(height: 32),
                    ],
                    _buildQuickActions(),
                    const SizedBox(height: 48), // Bottom padding
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDemoDataBanner() {
    return InkWell(
      onTap: _loadDemoData,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF8E1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Color(0xFFFFB300),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Setup',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Load demo data to see Aura in action.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Products',
                _totalProducts.toString(),
                Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(width: 16),
            if (_isManager)
              Expanded(
                child: _buildStatCard(
                  'Value',
                  '\$${_totalInventoryValue.toStringAsFixed(0)}',
                  Icons.account_balance_wallet_outlined,
                ),
              )
            else
              Expanded(
                child: _buildStatCard(
                  'In Stock',
                  '${_totalProducts - _lowStockCount}',
                  Icons.check_circle_outline,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _buildStatCard(
          'Low Stock',
          _lowStockCount.toString(),
          Icons.warning_amber_rounded,
          fullWidth: true,
          isAlert: _lowStockCount > 0,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon, {
    bool fullWidth = false,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isAlert ? const Color(0xFFFFF8E1) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isAlert ? const Color(0xFFFFE0B2) : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isAlert ? const Color(0xFFFFB300) : Colors.black54,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isAlert ? const Color(0xFFFFB300) : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: fullWidth ? 32 : 28,
              fontWeight: FontWeight.bold,
              color: isAlert ? const Color(0xFFFFB300) : Colors.black,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Action Needed',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              ..._lowStockProducts
                  .take(3)
                  .map(
                    (product) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: product.isOutOfStock
                                  ? const Color(0xFFFFF8E1)
                                  : const Color(0xFFFFF3E0),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              product.isOutOfStock
                                  ? Icons.error_outline
                                  : Icons.warning_amber,
                              color: product.isOutOfStock
                                  ? const Color(0xFFFFB300)
                                  : const Color(0xFFFFB300),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Stock: ${product.quantity} / Min: ${product.minQuantity}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Need ${product.minQuantity - product.quantity} more',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFE53935),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _orderedProductIds.contains(product.id)
                                ? null
                                : () => _sendOrderRequest(product),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _orderedProductIds.contains(product.id)
                                  ? Colors.grey[300]
                                  : const Color(0xFFFFB300),
                              foregroundColor: _orderedProductIds.contains(product.id)
                                  ? Colors.grey[500]
                                  : Colors.black87,
                              disabledBackgroundColor: Colors.grey[300],
                              disabledForegroundColor: Colors.grey[500],
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                            ),
                            child: Text(
                              _orderedProductIds.contains(product.id) ? 'Sent' : 'Order',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (_lowStockProducts.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+ ${_lowStockProducts.length - 3} more items',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Add Product',
                Icons.add_box_outlined,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Use Inventory tab')),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                'Record Sale',
                Icons.point_of_sale_outlined,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Use Sales tab')),
                  );
                },
              ),
            ),
          ],
        ),
        if (_isManager) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton('Adjust Stock', Icons.tune_outlined, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StockAdjustmentScreen(currentUser: widget.currentUser!),
                    ),
                  ).then((_) => _refreshDashboardData());
                }),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionButton('Manage Users', Icons.people_outline, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          UserManagementScreen(currentUser: widget.currentUser!),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: _pendingOrderCount > 0
              ? _buildActionButtonWithBadge('Orders', Icons.receipt_long_outlined, _pendingOrderCount, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrdersScreen(currentUser: widget.currentUser!),
                    ),
                  ).then((_) => _refreshDashboardData());
                })
              : _buildActionButton('Orders', Icons.receipt_long_outlined, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrdersScreen(currentUser: widget.currentUser!),
                    ),
                  ).then((_) => _refreshDashboardData());
                }),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed, {
    bool fullWidth = false,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: fullWidth
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.black87, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.black87, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildActionButtonWithBadge(String label, IconData icon, int badgeCount, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black87, size: 24),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFA726),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount pending',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
