import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../models/audit_log.dart';
import '../services/sync_service.dart';
import 'add_product_screen.dart';

class InventoryScreen extends StatefulWidget {
  final User? currentUser;

  const InventoryScreen({super.key, this.currentUser});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  StreamSubscription<SyncEvent>? _syncSubscription;
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  String _searchQuery = '';

  bool get _isManager => widget.currentUser?.isManager ?? false;
  bool get _canDelete => _isManager;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    // Listen for real-time cloud sync events
    _syncSubscription = SyncService.instance.onSync.listen((event) {
      if (event.table == SyncTable.products || event.table == SyncTable.all) {
        _loadProducts();
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await _dbHelper.readAllProducts();
      setState(() {
        _products = products;
        _filteredProducts = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _filterProducts(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredProducts = _products;
      } else {
        final q = query.toLowerCase();
        _filteredProducts = _products.where((p) {
          return p.name.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q) ||
              p.supplier.toLowerCase().contains(q) ||
              '\$${p.sellingPrice.toStringAsFixed(2)}'.contains(q) ||
              p.sellingPrice.toStringAsFixed(2).contains(q);
        }).toList();
      }
    });
  }

  Future<void> _deleteProduct(Product product) async {
    if (!_canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Managers only'), backgroundColor: Colors.red));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Product'),
        content: Text('Delete "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbHelper.deleteProduct(product.id!);
        if (widget.currentUser != null) {
          await _dbHelper.logAction(AuditLog(
            companyId: DatabaseHelper.instance.currentCompanyId,
            userId: widget.currentUser!.id!,
            userName: widget.currentUser!.fullName,
            action: 'delete_product',
            details: 'Deleted ${product.name}',
            timestamp: DateTime.now().toIso8601String(),
          ));
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${product.name} deleted'), backgroundColor: Colors.black87));
        _loadProducts();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _navigateToAddProduct([Product? product]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => AddProductScreen(product: product, currentUser: widget.currentUser)),
    );
    if (result == true) _loadProducts();
  }

  Color _getStatusColor(Product product) {
    if (product.isOutOfStock) return const Color(0xFFE53935);
    if (product.isLowStock) return const Color(0xFFFFB300);
    return const Color(0xFF4CAF50);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Inventory',
          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadProducts,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (!_isManager)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.grey[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'View only. Only managers can add, edit, or delete products.',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Row(
              children: [
                Text('Status: ', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
                _buildLegendChip(const Color(0xFF4CAF50), 'In Stock'),
                const SizedBox(width: 8),
                _buildLegendChip(const Color(0xFFFFB300), 'Low Stock'),
                const SizedBox(width: 8),
                _buildLegendChip(const Color(0xFFE53935), 'Empty'),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: TextField(
              onChanged: _filterProducts,
              style: GoogleFonts.poppins(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search by name, category, supplier, price...',
                hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Colors.black, width: 1.5),
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : _filteredProducts.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: Colors.black,
                        onRefresh: _loadProducts,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) => _buildProductCard(_filteredProducts[index]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _isManager ? FloatingActionButton.extended(
        onPressed: () => _navigateToAddProduct(),
        backgroundColor: Colors.black,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Item', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ) : null,
    );
  }

  Widget _buildLegendChip(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
            child: Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isEmpty ? 'No products yet' : 'No matches found',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty ? 'Tap + to add your first product' : 'Try adjusting your search',
            style: GoogleFonts.poppins(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final statusColor = _getStatusColor(product);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: InkWell(
        onTap: _isManager ? () => _navigateToAddProduct(product) : null,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Center(
                      child: Text(
                        product.name[0].toUpperCase(),
                        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
                        ),
                        Text(
                          product.category,
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: product.isOutOfStock ? const Color(0xFFFFEBEE) : (product.isLowStock ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      product.isOutOfStock ? 'Empty' : (product.isLowStock ? 'Low' : 'OK'),
                      style: GoogleFonts.poppins(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildInfoChip(Icons.inventory_2_outlined, 'Qty: ${product.quantity}', Colors.black87),
                  const SizedBox(width: 8),
                  _buildInfoChip(Icons.attach_money, '\$${product.sellingPrice.toStringAsFixed(2)}', Colors.black87),
                  const SizedBox(width: 8),
                  _buildInfoChip(Icons.domain, product.supplier.length > 8 ? '${product.supplier.substring(0, 6)}..' : product.supplier, Colors.black87),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_isManager) ...[  
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 22, color: Colors.black54),
                      onPressed: () => _navigateToAddProduct(product),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 22, color: Color(0xFFE53935)),
                      onPressed: () => _deleteProduct(product),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}