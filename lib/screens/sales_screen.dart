import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/user.dart';
import '../models/cart_item.dart';
import '../services/sync_service.dart';
import 'create_order_screen.dart';

class SalesScreen extends StatefulWidget {
  final User? currentUser;

  const SalesScreen({super.key, this.currentUser});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  StreamSubscription<SyncEvent>? _syncSubscription;
  List<Product> _products = [];
  List<Sale> _recentSales = [];
  int? _selectedProductId;
  final TextEditingController _quantityController = TextEditingController();
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _loadError;
  final List<CartItem> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _syncSubscription = SyncService.instance.onSync.listen((event) {
      if (event.table == SyncTable.products ||
          event.table == SyncTable.sales ||
          event.table == SyncTable.all) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_products.isEmpty) setState(() { _isLoading = true; _loadError = null; });
    try {
      final products = await _dbHelper.readAllProducts();
      final sales = await _dbHelper.readAllSales();
      if (mounted) {
        setState(() {
          _products = products;
          _recentSales = sales.take(20).toList();
          _isLoading = false;
          _loadError = null;
          if (_selectedProductId != null && !_products.any((p) => p.id == _selectedProductId)) {
            _selectedProductId = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  Product? get _selectedProduct {
    if (_selectedProductId == null) return null;
    try {
      return _products.firstWhere((p) => p.id == _selectedProductId);
    } catch (e) {
      return null;
    }
  }

  double get _cartTotal => _cartItems.fold(0, (sum, item) => sum + item.lineTotal);
  int get _cartItemCount => _cartItems.length;

  int _availableStock(int productId) {
    final product = _products.where((p) => p.id == productId).firstOrNull;
    if (product == null) return 0;
    final inCart = _cartItems.where((c) => c.product.id == productId).fold<int>(0, (sum, c) => sum + c.quantity);
    return product.quantity - inCart;
  }

  void _addToCart() {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a product first'), backgroundColor: Colors.black87),
      );
      return;
    }

    final qty = int.tryParse(_quantityController.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity'), backgroundColor: Colors.black87),
      );
      return;
    }

    final available = _availableStock(_selectedProduct!.id!);
    if (qty > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not enough stock! Available: $available'), backgroundColor: const Color(0xFFE53935)),
      );
      return;
    }

    setState(() {
      final existingIndex = _cartItems.indexWhere((c) => c.product.id == _selectedProduct!.id);
      if (existingIndex >= 0) {
        final existing = _cartItems[existingIndex];
        _cartItems[existingIndex] = existing.copyWith(quantity: existing.quantity + qty);
      } else {
        _cartItems.add(CartItem(
          product: _selectedProduct!,
          quantity: qty,
          unitPrice: _selectedProduct!.sellingPrice,
        ));
      }
      _selectedProductId = null;
      _quantityController.text = '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added to cart (${_cartItems.length} item${_cartItems.length != 1 ? "s" : ""})'),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _removeFromCart(int index) {
    setState(() => _cartItems.removeAt(index));
  }

  void _updateCartQuantity(int index, int newQty) {
    if (newQty <= 0) {
      _removeFromCart(index);
      return;
    }
    final item = _cartItems[index];
    final available = item.product.quantity;
    final otherInCart = _cartItems.asMap().entries
        .where((e) => e.value.product.id == item.product.id && e.key != index)
        .fold<int>(0, (sum, e) => sum + e.value.quantity);
    if (newQty > available - otherInCart) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Max available: ${available - otherInCart}'), backgroundColor: const Color(0xFFE53935)),
      );
      return;
    }
    setState(() => _cartItems[index] = item.copyWith(quantity: newQty));
  }

  Future<void> _chargeAll() async {
    if (_cartItems.isEmpty) return;
    if (widget.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user session — please re-login'), backgroundColor: Color(0xFFE53935)),
      );
      return;
    }

    // Re-check stock for each item
    for (final item in _cartItems) {
      final current = _products.where((p) => p.id == item.product.id).firstOrNull;
      if (current == null || item.quantity > current.quantity) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${item.product.name}: only ${current?.quantity ?? 0} in stock'), backgroundColor: const Color(0xFFE53935)),
          );
        }
        return;
      }
    }

    setState(() => _isProcessing = true);

    try {
      final cartData = _cartItems.map((c) => <String, dynamic>{
        'productId': c.product.id!,
        'productName': c.product.name,
        'quantity': c.quantity,
        'unitPrice': c.unitPrice,
      }).toList();

      final sales = await _dbHelper.createBatchSale(cartData, widget.currentUser!);
      final total = sales.fold<double>(0, (sum, s) => sum + s.totalAmount);

      if (mounted) {
        _showReceiptDialog(List.from(_cartItems), total);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Sale saved'),
          ]),
          backgroundColor: Colors.black87,
          duration: const Duration(seconds: 2),
        ));
        setState(() {
          _cartItems.clear();
          _isProcessing = false;
        });
        _loadData();
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sale error: $e'), backgroundColor: const Color(0xFFE53935)));
      }
    }
  }

  void _showReceiptDialog(List<CartItem> items, double total) {
    final now = DateTime.now();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 48),
            const SizedBox(height: 8),
            Text('Sale Complete!', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Text(
                '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
                style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12),
              )),
              const Divider(height: 24),
              ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(item.product.name, style: GoogleFonts.poppins(fontSize: 13))),
                    Text('${item.quantity}x', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(width: 8),
                    Text('\$${item.lineTotal.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('\$${total.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF4CAF50))),
                ],
              ),
              const SizedBox(height: 8),
              Center(child: Text(
                'Served by ${widget.currentUser?.fullName ?? 'Staff'}',
                style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 11),
              )),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Done', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Cart Checkout',
          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: -0.5),
        ),
        actions: [
          if (_cartItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_cartItems.length}',
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.black54), onPressed: _loadData),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _loadError != null
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildProductSelector(),
                    Expanded(child: _buildCartSection()),
                    if (_cartItems.isNotEmpty) _buildBottomBar(),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Failed to load data', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_loadError!, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('Retry', style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSelector() {
    final inStockProducts = _products.where((p) => p.quantity > 0).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add item to cart', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  key: ValueKey('pdrop_$_selectedProductId'),
                  initialValue: _selectedProductId,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black54),
                  decoration: InputDecoration(
                    hintText: 'Select product',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
                    prefixIcon: const Icon(Icons.inventory_2_outlined, color: Colors.black54, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[300]!)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.black87, width: 1.5)),
                  ),
                  isExpanded: true,
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                  items: inStockProducts.map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Text('${p.name} (${_availableStock(p.id!)} left)', overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (id) => setState(() => _selectedProductId = id),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                child: TextFormField(
                  controller: _quantityController,
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'Qty',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[300]!)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.black87, width: 1.5)),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addToCart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_shopping_cart, size: 18),
                    const SizedBox(width: 4),
                    Text('Add', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          if (_selectedProduct != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '\$${_selectedProduct!.sellingPrice.toStringAsFixed(2)} each  —  ${_selectedProduct!.quantity} in stock',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCartSection() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: Colors.black,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Cart header
          if (_cartItems.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.shopping_cart, size: 18, color: Colors.black87),
                const SizedBox(width: 6),
                Text('Cart', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _cartItems.clear()),
                  icon: Icon(Icons.delete_outline, size: 16, color: Colors.red[400]),
                  label: Text('Clear', style: GoogleFonts.poppins(fontSize: 12, color: Colors.red[400])),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Empty cart state
          if (_cartItems.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 16, bottom: 16),
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Cart is empty', style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('Select a product above and tap "Add"', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            ),
          // Cart items
          ..._cartItems.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.product.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                        Text('\$${item.unitPrice.toStringAsFixed(2)} each', style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _updateCartQuantity(idx, item.quantity - 1),
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.remove, size: 16)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('${item.quantity}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        InkWell(
                          onTap: () => _updateCartQuantity(idx, item.quantity + 1),
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.add, size: 16)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('\$${item.lineTotal.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _removeFromCart(idx),
                    child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }),
          // Recent Sales
          if (_recentSales.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.history, size: 18, color: Colors.black54),
                const SizedBox(width: 6),
                Text('Recent Sales', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            ..._recentSales.take(10).map((sale) {
              final saleDate = DateTime.tryParse(sale.saleDate);
              final dateStr = saleDate != null
                  ? '${saleDate.day}/${saleDate.month} ${saleDate.hour}:${saleDate.minute.toString().padLeft(2, '0')}'
                  : '';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[100]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sale.productName, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                          Text(dateStr, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400])),
                        ],
                      ),
                    ),
                    Text('${sale.quantitySold}x', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(width: 8),
                    Text('\$${sale.totalAmount.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
          ] else if (_cartItems.isEmpty) ...[
            const SizedBox(height: 16),
            Center(child: Text('No sales history yet', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]))),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, -3))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$_cartItemCount item${_cartItemCount != 1 ? 's' : ''}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white60)),
                Text('\$${_cartTotal.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _chargeAll,
              icon: _isProcessing
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.flash_on, size: 18),
              label: Text('Charge All', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            if (widget.currentUser != null) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _isProcessing ? null : () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => CreateOrderScreen(
                      currentUser: widget.currentUser!,
                      initialCartItems: _cartItems,
                    ),
                  )).then((_) {
                    _loadData();
                    setState(() => _cartItems.clear());
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Order', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
