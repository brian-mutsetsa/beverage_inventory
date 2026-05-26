import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../models/audit_log.dart';

class StockAdjustmentScreen extends StatefulWidget {
  final User currentUser;

  const StockAdjustmentScreen({super.key, required this.currentUser});

  @override
  State<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends State<StockAdjustmentScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Product> _products = [];
  List<AuditLog> _recentAdjustments = [];
  int? _selectedProductId;
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  String _adjustmentType = 'add'; // 'add' or 'correct'
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadAdjustmentHistory();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
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

  Future<void> _loadAdjustmentHistory() async {
    try {
      final logs = await _dbHelper.getAuditLogsByAction('stock_adjustment', limit: 15);
      if (mounted) setState(() => _recentAdjustments = logs);
    } catch (_) {}
  }

  Product? get _selectedProduct {
    if (_selectedProductId == null) return null;
    try {
      return _products.firstWhere((p) => p.id == _selectedProductId);
    } catch (e) {
      return null;
    }
  }

  Future<void> _applyAdjustment() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a product'), backgroundColor: Colors.black87),
      );
      return;
    }

    final qty = int.tryParse(_quantityController.text);
    if (qty == null || qty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity'), backgroundColor: Colors.black87),
      );
      return;
    }

    if (_adjustmentType == 'add' && qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be greater than 0'), backgroundColor: Colors.black87),
      );
      return;
    }

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a reason'), backgroundColor: Colors.black87),
      );
      return;
    }

    // For 'add': adds qty to current stock.
    // For 'correct': sets stock to exactly qty (delta = qty - currentStock, can be negative).
    final delta = _adjustmentType == 'add'
        ? qty
        : (qty - _selectedProduct!.quantity);

    setState(() => _isProcessing = true);

    try {
      await _dbHelper.adjustStock(_selectedProduct!.id!, delta, reason);

      final logDetail = _adjustmentType == 'add'
          ? '+$qty ${_selectedProduct!.name} — $reason'
          : 'Set ${_selectedProduct!.name} to $qty — $reason';

      await _dbHelper.logAction(AuditLog(
        companyId: DatabaseHelper.instance.currentCompanyId,
        userId: widget.currentUser.id!,
        userName: widget.currentUser.fullName,
        action: 'stock_adjustment',
        details: logDetail,
        timestamp: DateTime.now().toIso8601String(),
      ));

      if (mounted) {
        final msg = _adjustmentType == 'add'
            ? 'Added $qty to ${_selectedProduct!.name}'
            : 'Stock set to $qty for ${_selectedProduct!.name}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: const Color(0xFF4CAF50)),
        );

        setState(() {
          _selectedProductId = null;
          _quantityController.clear();
          _reasonController.clear();
          _isProcessing = false;
        });
        _loadProducts();
        _loadAdjustmentHistory();
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
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.black87, width: 1.5),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Adjust Stock',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Adjustment type toggle
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        // Received (Add)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _adjustmentType = 'add'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _adjustmentType == 'add'
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _adjustmentType == 'add'
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_circle_outline,
                                    size: 18,
                                    color: _adjustmentType == 'add'
                                        ? const Color(0xFF4CAF50)
                                        : Colors.grey[500],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Received',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _adjustmentType == 'add'
                                          ? const Color(0xFF4CAF50)
                                          : Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Correction (Set absolute value)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _adjustmentType = 'correct'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _adjustmentType == 'correct'
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _adjustmentType == 'correct'
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: _adjustmentType == 'correct'
                                        ? const Color(0xFF1976D2)
                                        : Colors.grey[500],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Correction',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _adjustmentType == 'correct'
                                          ? const Color(0xFF1976D2)
                                          : Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Product selector
                  DropdownButtonFormField<int>(
                    key: ValueKey('stock_product_$_selectedProductId'),
                    initialValue: _selectedProductId,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.black54,
                    ),
                    decoration: _inputDecoration('Product', Icons.inventory_2_outlined),
                    hint: Text(
                      'Select product',
                      style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
                    ),
                    isExpanded: true,
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                    items: _products
                        .map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                '${p.name} (${p.quantity} in stock)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (id) => setState(() => _selectedProductId = id),
                  ),

                  if (_selectedProduct != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Stock',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                              Text(
                                '${_selectedProduct!.quantity}',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Category',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                              Text(
                                _selectedProduct!.category,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quantityController,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                    decoration: _inputDecoration(
                      _adjustmentType == 'correct' ? 'New Stock Level' : 'Quantity',
                      _adjustmentType == 'correct'
                          ? Icons.inventory_2_outlined
                          : Icons.tag,
                    ).copyWith(
                      helperText: _adjustmentType == 'correct' && _selectedProduct != null
                          ? 'Current: ${_selectedProduct!.quantity} — type the correct total'
                          : null,
                      helperStyle:
                          GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                    ),
                    keyboardType: TextInputType.number,
                  ),

                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reasonController,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: _inputDecoration('Reason', Icons.edit_note_rounded),
                    maxLines: 2,
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _applyAdjustment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _adjustmentType == 'add' ? 'Add Stock' : 'Set Stock',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  // Recent Adjustments history
                  if (_recentAdjustments.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        const Icon(Icons.history, size: 18, color: Colors.black54),
                        const SizedBox(width: 6),
                        Text(
                          'Recent Adjustments',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._recentAdjustments.map((log) {
                      final ts = DateTime.tryParse(log.timestamp);
                      final dateStr = ts != null
                          ? '${ts.day}/${ts.month}/${ts.year} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}'
                          : '';
                      final isAdd = (log.details ?? '').startsWith('+');
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isAdd
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isAdd ? Icons.add : Icons.edit_outlined,
                                size: 16,
                                color: isAdd
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFF1976D2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log.details ?? '',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '$dateStr — ${log.userName ?? ''}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
    );
  }
}
