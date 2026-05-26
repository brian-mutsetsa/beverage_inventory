import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../models/order.dart' as app_order;
import '../models/user.dart';
import 'order_detail_screen.dart';
import 'create_order_screen.dart';

class OrdersScreen extends StatefulWidget {
  final User currentUser;

  const OrdersScreen({super.key, required this.currentUser});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  late TabController _tabController;
  List<app_order.Order> _allOrders = [];
  List<app_order.Order> _orders = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const _tabs = ['All', 'Pending', 'Processing', 'Completed', 'Delivered'];
  static const _statusFilters = [null, 'pending', 'processing', 'completed', 'delivered'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _loadOrders();
    });
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final status = _statusFilters[_tabController.index];
      final orders = await _dbHelper.getOrders(status: status);
      if (mounted) {
        setState(() {
          _allOrders = orders;
          _applySearch();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _orders = List.from(_allOrders);
    } else {
      final q = _searchQuery.toLowerCase();
      _orders = _allOrders.where((o) {
        return o.customerName.toLowerCase().contains(q) ||
            (o.customerPhone?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return const Color(0xFFFFA726);
      case 'processing': return const Color(0xFF42A5F5);
      case 'completed': return const Color(0xFF4CAF50);
      case 'delivered': return const Color(0xFF7E57C2);
      case 'cancelled': return const Color(0xFFE53935);
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.schedule;
      case 'processing': return Icons.sync;
      case 'completed': return Icons.check_circle_outline;
      case 'delivered': return Icons.local_shipping_outlined;
      case 'cancelled': return Icons.cancel_outlined;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Orders', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _OrderSearchDelegate(
                  allOrders: _allOrders,
                  onTap: (order) async {
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (context) => OrderDetailScreen(orderId: order.id!, currentUser: widget.currentUser),
                    ));
                    _loadOrders();
                  },
                  statusColor: _statusColor,
                  statusIcon: _statusIcon,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black87),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                builder: (context) => CreateOrderScreen(currentUser: widget.currentUser),
              ));
              _loadOrders();
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.black,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey[500],
          labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
          tabAlignment: TabAlignment.start,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Column(
                  children: [
                    // Inline search bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.poppins(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search by customer name or phone...',
                          hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: Colors.grey[400], size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() { _searchQuery = ''; _applySearch(); });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black54)),
                        ),
                        onChanged: (val) {
                          setState(() { _searchQuery = val.trim(); _applySearch(); });
                        },
                      ),
                    ),
                    Expanded(
                      child: _orders.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                                  const SizedBox(height: 8),
                                  Text(_searchQuery.isNotEmpty ? 'No matching orders' : 'No orders yet',
                                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400])),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                  onRefresh: _loadOrders,
                  color: Colors.black,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      return _buildOrderCard(order);
                    },
                  ),
                ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildOrderCard(app_order.Order order) {
    final color = _statusColor(order.status);
    final created = DateTime.tryParse(order.createdAt);
    final dateStr = created != null
        ? '${created.day}/${created.month}/${created.year}'
        : '';

    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(
          builder: (context) => OrderDetailScreen(orderId: order.id!, currentUser: widget.currentUser),
        ));
        _loadOrders();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_statusIcon(order.status), color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.customerName, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(dateStr, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\$${order.totalAmount.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.status[0].toUpperCase() + order.status.substring(1),
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderSearchDelegate extends SearchDelegate<app_order.Order?> {
  final List<app_order.Order> allOrders;
  final void Function(app_order.Order) onTap;
  final Color Function(String) statusColor;
  final IconData Function(String) statusIcon;

  _OrderSearchDelegate({
    required this.allOrders,
    required this.onTap,
    required this.statusColor,
    required this.statusIcon,
  });

  @override
  String get searchFieldLabel => 'Customer name or phone...';

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget? buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  List<app_order.Order> get _filtered {
    if (query.isEmpty) return allOrders;
    final q = query.toLowerCase();
    return allOrders.where((o) =>
        o.customerName.toLowerCase().contains(q) ||
        (o.customerPhone?.toLowerCase().contains(q) ?? false)).toList();
  }

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final results = _filtered;
    if (results.isEmpty) {
      return Center(
        child: Text('No matching orders', style: GoogleFonts.poppins(color: Colors.grey[400])),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final order = results[index];
        final color = statusColor(order.status);
        final created = DateTime.tryParse(order.createdAt);
        final dateStr = created != null ? '${created.day}/${created.month}/${created.year}' : '';
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(statusIcon(order.status), color: color, size: 18),
          ),
          title: Text(order.customerName, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text('${order.customerPhone ?? ''} \u2014 $dateStr', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
          trailing: Text('\$${order.totalAmount.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          onTap: () {
            close(context as BuildContext, null);
            onTap(order);
          },
        );
      },
    );
  }
}
