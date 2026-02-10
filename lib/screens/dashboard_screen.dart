import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../helpers/demo_data_helper.dart';
import 'login_screen.dart';
import 'user_management_screen.dart';

class DashboardScreen extends StatefulWidget {
  final User? currentUser;

  const DashboardScreen({super.key, this.currentUser});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  int _totalProducts = 0;
  double _totalInventoryValue = 0.0;
  int _lowStockCount = 0;
  List<Product> _lowStockProducts = [];
  bool _isLoading = true;

  bool get _isManager => widget.currentUser?.isManager ?? false;
  bool get _isStaff => widget.currentUser?.isStaff ?? false;
  bool get _hasNoData => _totalProducts == 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final productCount = await _dbHelper.getProductCount();
      final inventoryValue = await _dbHelper.getTotalInventoryValue();
      final lowStockProducts = await _dbHelper.getLowStockProducts();

      setState(() {
        _totalProducts = productCount;
        _totalInventoryValue = inventoryValue;
        _lowStockProducts = lowStockProducts;
        _lowStockCount = lowStockProducts.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: $e')),
        );
      }
    }
  }

  Future<void> _loadDemoData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load Demo Data?'),
        content: const Text(
          'This will add:\n'
          '• 10 sample products\n'
          '• 5 sample employees\n'
          '• 24 sample sales\n\n'
          'Perfect for testing and demonstration purposes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
            ),
            child: const Text('Load Demo Data'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await DemoDataHelper.loadDemoData(widget.currentUser!);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Demo data loaded successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        await _loadDashboardData();
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading demo data: $e')),
          );
        }
      }
    }
  }

  Future<void> _clearDemoData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will remove:\n'
          '• All products\n'
          '• All sales\n'
          '• All employees (except you)\n\n'
          'This action cannot be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await DemoDataHelper.clearAllData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ All data cleared!'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        await _loadDashboardData();
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing data: $e')),
          );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard'),
            if (widget.currentUser != null)
              Text(
                widget.currentUser!.fullName,
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          // Role Badge
          if (widget.currentUser != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isManager ? Colors.amber : Colors.blue[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isManager ? 'MANAGER' : 'STAFF',
                style: TextStyle(
                  color: _isManager ? Colors.black87 : Colors.blue[900],
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
          ),
          if (_isManager)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'load_demo') {
                  _loadDemoData();
                } else if (value == 'clear_data') {
                  _clearDemoData();
                } else if (value == 'logout') {
                  _logout();
                }
              },
              itemBuilder: (context) => [
                // Always show Load Demo Data option if there's no data
                if (_hasNoData)
                  const PopupMenuItem(
                    value: 'load_demo',
                    child: Row(
                      children: [
                        Icon(Icons.download, size: 20, color: Colors.blue),
                        SizedBox(width: 12),
                        Text('Load Demo Data'),
                      ],
                    ),
                  ),
                // Show Clear Data if there IS data
                if (!_hasNoData)
                  const PopupMenuItem(
                    value: 'clear_data',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Clear All Data'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20),
                      SizedBox(width: 12),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Message
                    if (widget.currentUser != null) ...[
                      _buildWelcomeCard(),
                      const SizedBox(height: 24),
                    ],
                    
                    // Demo Data Banner (if no data exists and user is manager)
                    if (_isManager && _hasNoData) ...[
                      _buildDemoDataBanner(),
                      const SizedBox(height: 24),
                    ],
                    
                    // Statistics Cards
                    _buildStatisticsCards(),
                    const SizedBox(height: 24),
                    
                    // Low Stock Warning
                    if (_lowStockCount > 0) ...[
                      _buildLowStockSection(),
                      const SizedBox(height: 24),
                    ],
                    
                    // Quick Actions
                    _buildQuickActions(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      color: const Color(0xFFE3F2FD),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF1565C0),
              child: Text(
                widget.currentUser!.fullName[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, ${widget.currentUser!.fullName.split(' ').first}!',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isManager 
                        ? 'Manager Account' 
                        : 'Staff Account',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoDataBanner() {
    return Card(
      color: const Color(0xFFFFF3E0),
      child: InkWell(
        onTap: _loadDemoData,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.download,
                  color: Color(0xFFF57C00),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Load Demo Data',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quickly populate with sample products, employees & sales',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Products',
                _totalProducts.toString(),
                Icons.inventory_2,
                const Color(0xFF1565C0),
              ),
            ),
            const SizedBox(width: 12),
            // Show inventory value only to managers
            if (_isManager)
              Expanded(
                child: _buildStatCard(
                  'Inventory Value',
                  '\$${_totalInventoryValue.toStringAsFixed(2)}',
                  Icons.attach_money,
                  const Color(0xFF2E7D32),
                ),
              )
            else
              Expanded(
                child: _buildStatCard(
                  'In Stock',
                  '${_totalProducts - _lowStockCount}',
                  Icons.check_circle,
                  const Color(0xFF2E7D32),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Low Stock Items',
          _lowStockCount.toString(),
          Icons.warning_amber_rounded,
          _lowStockCount > 0 ? const Color(0xFFF57C00) : const Color(0xFF9E9E9E),
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool fullWidth = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: fullWidth ? 28 : 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFF57C00),
            ),
            const SizedBox(width: 8),
            const Text(
              'Low Stock Alert',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFFFFF3E0),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ..._lowStockProducts.take(3).map((product) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: product.isOutOfStock
                                  ? Colors.red
                                  : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            'Qty: ${product.quantity}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )),
                if (_lowStockProducts.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '+ ${_lowStockProducts.length - 3} more items need attention',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Add Product',
                Icons.add_box,
                const Color(0xFF1565C0),
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Go to Inventory tab to add products'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Record Sale',
                Icons.point_of_sale,
                const Color(0xFF2E7D32),
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Go to Sales tab to record sales'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        // Add User Management button for managers only
        if (_isManager) ...[
          const SizedBox(height: 12),
          _buildActionButton(
            'Manage Users',
            Icons.people,
            const Color(0xFF6A1B9A),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserManagementScreen(
                    currentUser: widget.currentUser!,
                  ),
                ),
              );
            },
            fullWidth: true,
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool fullWidth = false,
  }) {
    return Card(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: fullWidth
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Icon(icon, color: color, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}