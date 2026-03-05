import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/user.dart';
import '../models/audit_log.dart';

class SalesScreen extends StatefulWidget {
  final User? currentUser;

  const SalesScreen({super.key, this.currentUser});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Product> _products = [];
  List<Sale> _sales = [];
  int? _selectedProductId;
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _quantityController.addListener(_updateTotal);
  }

  @override
  void dispose() {
    _quantityController.removeListener(_updateTotal);
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateTotal() {
    setState(() {});
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final products = await _dbHelper.readAllProducts();
      final sales = await _dbHelper.readAllSales();
      
      setState(() {
        _products = products;
        _sales = sales;
        _isLoading = false;
        
        if (_selectedProductId != null && !_products.any((p) => p.id == _selectedProductId)) {
          _selectedProductId = null;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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

  double get _totalAmount {
    if (_selectedProduct == null) return 0.0;
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    return _selectedProduct!.sellingPrice * quantity;
  }

  Future<void> _recordSale() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a product'), backgroundColor: Colors.black87));
      return;
    }

    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid quantity'), backgroundColor: Colors.black87));
      return;
    }

    if (quantity > _selectedProduct!.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Not enough stock! Available: ${_selectedProduct!.quantity}'), backgroundColor: const Color(0xFFE53935)));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final sale = Sale(
        companyId: DatabaseHelper.instance.currentCompanyId,
        productId: _selectedProduct!.id!,
        productName: _selectedProduct!.name,
        quantitySold: quantity,
        unitPrice: _selectedProduct!.sellingPrice,
        totalAmount: _selectedProduct!.sellingPrice * quantity,
        saleDate: DateTime.now().toIso8601String(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      await _dbHelper.createSale(sale);

      final updatedProduct = _selectedProduct!.copyWith(
        quantity: _selectedProduct!.quantity - quantity,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _dbHelper.updateProduct(updatedProduct);

      if (widget.currentUser != null && widget.currentUser!.id != null) {
        await _dbHelper.logAction(AuditLog(
          companyId: DatabaseHelper.instance.currentCompanyId,
          userId: widget.currentUser!.id!,
          userName: widget.currentUser!.fullName,
          action: 'record_sale',
          details: 'Sold ${quantity}x ${_selectedProduct!.name} - \$${sale.totalAmount.toStringAsFixed(2)}',
          timestamp: DateTime.now().toIso8601String(),
        ));
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sale recorded: ${quantity}x ${_selectedProduct!.name}'), backgroundColor: const Color(0xFF4CAF50)));

      setState(() {
        _selectedProductId = null;
        _quantityController.text = '1';
        _notesController.clear();
        _isProcessing = false;
      });

      _loadData();
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon, {String? hintText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.black87, width: 1.5)),
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
          'Checkout',
          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildSalesForm(),
                  Container(height: 1, color: Colors.grey[200], margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8)),
                  _buildSalesHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildSalesForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  value: _selectedProductId,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black54),
                  decoration: _inputDecoration('Item', Icons.inventory_2_outlined),
                  hint: Text('Choose a product', style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13)),
                  isExpanded: true,
                  style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87),
                  items: _products.map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Text('${p.name} (${p.quantity} left)', overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (id) => setState(() => _selectedProductId = id),
                ),
                if (_selectedProduct != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Unit Price', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                            Text('\$${_selectedProduct!.sellingPrice.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                          ],
                        ),
                        Container(width: 1, height: 32, color: Colors.grey[300]),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('In Stock', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                            Text(
                              '${_selectedProduct!.quantity}',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: _selectedProduct!.quantity > 0 ? const Color(0xFF4CAF50) : const Color(0xFFE53935)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _quantityController,
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                        decoration: _inputDecoration('Qty', Icons.tag),
                        keyboardType: TextInputType.number,
                        enabled: !_isProcessing,
                        onChanged: (v) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _isProcessing ? null : () {
                          final current = int.tryParse(_quantityController.text) ?? 1;
                          if (current > 1) setState(() => _quantityController.text = (current - 1).toString());
                        },
                        child: Container(width: 56, height: 56, alignment: Alignment.center, child: const Icon(Icons.remove, color: Colors.black87)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _isProcessing ? null : () {
                          final current = int.tryParse(_quantityController.text) ?? 1;
                          setState(() => _quantityController.text = (current + 1).toString());
                        },
                        child: Container(width: 56, height: 56, alignment: Alignment.center, child: const Icon(Icons.add, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: _inputDecoration('Notes (Optional)', Icons.edit_note_rounded, hintText: 'Customer name or details'),
                  maxLines: 2,
                  enabled: !_isProcessing,
                ),
              ],
            ),
          ),
          
          if (_selectedProduct != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Amount', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70)),
                      Text('\$${_totalAmount.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _recordSale,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isProcessing 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Text('Charge', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSalesHistory() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Sales', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                child: Text('${_sales.length}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sales.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey[200]!)),
                          child: Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
                        ),
                        const SizedBox(height: 16),
                        Text('No sales today', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54)),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _sales.length > 20 ? 20 : _sales.length, // Show only last 20 recent
                  itemBuilder: (context, index) => _buildSaleCard(_sales.reversed.toList()[index]),
                ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(Sale sale) {
    final date = DateTime.parse(sale.saleDate);
    final dateStr = DateFormat('MMM dd, hh:mm a').format(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                child: const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sale.productName, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                    Text('${sale.quantitySold}x @ \$${sale.unitPrice.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$${sale.totalAmount.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                  Text(dateStr, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400])),
                ],
              ),
            ],
          ),
          if (sale.notes != null && sale.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.notes, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Expanded(child: Text(sale.notes!, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]))),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}