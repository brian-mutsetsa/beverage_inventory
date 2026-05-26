import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../models/cart_item.dart';
import '../models/order.dart' as app_order;
import '../models/order_item.dart';
import '../models/audit_log.dart';

class CreateOrderScreen extends StatefulWidget {
  final User currentUser;
  final List<CartItem>? initialCartItems;

  const CreateOrderScreen({super.key, required this.currentUser, this.initialCartItems});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();
  List<Product> _products = [];
  final List<CartItem> _cartItems = [];
  bool _isLoading = true;
  bool _isProcessing = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  int? _selectedProductId;
  final TextEditingController _qtyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialCartItems != null) {
      _cartItems.addAll(widget.initialCartItems!);
    }
    _loadProducts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _dbHelper.readAllProducts();
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  double get _orderTotal => _cartItems.fold(0, (sum, item) => sum + item.lineTotal);

  int _availableStock(int productId) {
    final product = _products.where((p) => p.id == productId).firstOrNull;
    if (product == null) return 0;
    final inCart = _cartItems
        .where((c) => c.product.id == productId)
        .fold<int>(0, (sum, c) => sum + c.quantity);
    return product.quantity - inCart;
  }

  void _addItemToOrder() {
    if (_selectedProductId == null) return;
    final product = _products.firstWhere((p) => p.id == _selectedProductId);
    final qty = int.tryParse(_qtyController.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity'), backgroundColor: Colors.black87),
      );
      return;
    }

    final available = _availableStock(_selectedProductId!);
    if (qty > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only $available in stock for ${product.name}'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
      return;
    }

    setState(() {
      final existingIdx = _cartItems.indexWhere((c) => c.product.id == _selectedProductId);
      if (existingIdx >= 0) {
        final existing = _cartItems[existingIdx];
        _cartItems[existingIdx] = existing.copyWith(quantity: existing.quantity + qty);
      } else {
        _cartItems.add(CartItem(product: product, quantity: qty, unitPrice: product.sellingPrice));
      }
      _selectedProductId = null;
      _qtyController.text = '';
    });
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item'), backgroundColor: Colors.black87),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final now = DateTime.now().toIso8601String();
      final order = app_order.Order(
        companyId: DatabaseHelper.instance.currentCompanyId,
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        customerAddress: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        status: 'pending',
        totalAmount: _orderTotal,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: now,
        updatedAt: now,
        createdBy: widget.currentUser.id!,
      );

      final orderItems = _cartItems.map((c) => OrderItem(
        orderId: 0, // will be set by createOrder
        productId: c.product.id!,
        productName: c.product.name,
        quantity: c.quantity,
        unitPrice: c.unitPrice,
        lineTotal: c.lineTotal,
      )).toList();

      await _dbHelper.createOrder(order, orderItems);

      await _dbHelper.logAction(AuditLog(
        companyId: DatabaseHelper.instance.currentCompanyId,
        userId: widget.currentUser.id!,
        userName: widget.currentUser.fullName,
        action: 'create_order',
        details: 'Order for ${_nameController.text.trim()} — \$${_orderTotal.toStringAsFixed(2)}',
        timestamp: now,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed successfully'), backgroundColor: Color(0xFF4CAF50)),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.black87, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE53935))),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5)),
    );
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
        title: Text('New Order', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Customer Info
                        Text('Customer', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameController,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: _inputDecoration('Name *', Icons.person_outline),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: _inputDecoration('Phone', Icons.phone_outlined),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _addressController,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: _inputDecoration('Address', Icons.location_on_outlined),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesController,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: _inputDecoration('Notes', Icons.edit_note),
                          maxLines: 2,
                        ),

                        const SizedBox(height: 24),
                        Text('Items', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),

                        // Add item row
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<int>(
                                key: ValueKey('order_product_$_selectedProductId'),
                                initialValue: _selectedProductId,
                                decoration: _inputDecoration('Product', Icons.inventory_2_outlined),
                                hint: Text('Select', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
                                isExpanded: true,
                                style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                                items: _products.where((p) => p.quantity > 0).map((p) {
                                  final avail = _availableStock(p.id!);
                                  return DropdownMenuItem(
                                    value: p.id,
                                    child: Text('${p.name} ($avail left)', overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (id) => setState(() => _selectedProductId = id),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 72,
                              child: TextFormField(
                                controller: _qtyController,
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: 'Qty',
                                  hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.black87, width: 1.5)),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Material(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: _addItemToOrder,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        // Cart items
                        ..._cartItems.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.product.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                                      Text('${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                                    ],
                                  ),
                                ),
                                Text('\$${item.lineTotal.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => setState(() => _cartItems.removeAt(idx)),
                                  child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  // Bottom bar
                  if (_cartItems.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${_cartItems.length} item${_cartItems.length != 1 ? 's' : ''}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
                              Text('\$${_orderTotal.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _placeOrder,
                            icon: _isProcessing
                                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                : const Icon(Icons.receipt_long, size: 18),
                            label: Text('Place Order', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
}
