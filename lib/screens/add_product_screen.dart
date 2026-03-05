import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../models/audit_log.dart';

class AddProductScreen extends StatefulWidget {
  final Product? product; // If provided, we're editing, not adding
  final User? currentUser;

  const AddProductScreen({super.key, this.product, this.currentUser});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _quantityController;
  late TextEditingController _minQuantityController;
  late TextEditingController _costPriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _supplierController;
  late TextEditingController _barcodeController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _categoryController = TextEditingController(text: widget.product?.category ?? 'Soft Drink');
    _quantityController = TextEditingController(text: widget.product?.quantity.toString() ?? '0');
    _minQuantityController = TextEditingController(text: widget.product?.minQuantity.toString() ?? '10');
    _costPriceController = TextEditingController(text: widget.product?.costPrice.toString() ?? '');
    _sellingPriceController = TextEditingController(text: widget.product?.sellingPrice.toString() ?? '');
    _supplierController = TextEditingController(text: widget.product?.supplier ?? '');
    _barcodeController = TextEditingController(text: widget.product?.barcode ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _minQuantityController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _supplierController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now().toIso8601String();
      final product = Product(
        companyId: DatabaseHelper.instance.currentCompanyId,
        id: widget.product?.id,
        name: _nameController.text.trim(),
        category: _categoryController.text.trim(),
        quantity: int.parse(_quantityController.text),
        minQuantity: int.parse(_minQuantityController.text),
        costPrice: double.parse(_costPriceController.text),
        sellingPrice: double.parse(_sellingPriceController.text),
        supplier: _supplierController.text.trim(),
        barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        imagePath: widget.product?.imagePath,
        createdAt: widget.product?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.product == null) {
        await _dbHelper.createProduct(product);
        if (widget.currentUser != null && widget.currentUser!.id != null) {
          await _dbHelper.logAction(AuditLog(
            companyId: DatabaseHelper.instance.currentCompanyId,
            userId: widget.currentUser!.id!,
            userName: widget.currentUser!.fullName,
            action: 'add_product',
            details: 'Added product: ${product.name}',
            timestamp: now,
          ));
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product added'), backgroundColor: Colors.black87));
      } else {
        await _dbHelper.updateProduct(product);
        if (widget.currentUser != null && widget.currentUser!.id != null) {
          await _dbHelper.logAction(AuditLog(
            companyId: DatabaseHelper.instance.currentCompanyId,
            userId: widget.currentUser!.id!,
            userName: widget.currentUser!.fullName,
            action: 'edit_product',
            details: 'Updated product: ${product.name}',
            timestamp: now,
          ));
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated'), backgroundColor: Colors.black87));
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon, {String? hintText, String? prefixText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
      prefixText: prefixText,
      prefixStyle: GoogleFonts.poppins(color: Colors.black87, fontSize: 15),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE53935)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          isEditing ? 'Edit Item' : 'New Item',
          style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            physics: const BouncingScrollPhysics(),
            children: [
              Text(
                'Basic Details',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              
              TextFormField(
                controller: _nameController,
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500),
                decoration: _inputDecoration('Product Name', Icons.inventory_2_outlined, hintText: 'e.g. Coca-Cola 500ml'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                style: GoogleFonts.poppins(fontSize: 15),
                decoration: _inputDecoration('Category', Icons.category_outlined, hintText: 'e.g. Soft Drink'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              
              const SizedBox(height: 32),
              Text(
                'Inventory',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      style: GoogleFonts.poppins(fontSize: 15),
                      decoration: _inputDecoration('Stock Qty', Icons.format_list_numbered),
                      keyboardType: TextInputType.number,
                      validator: (v) => (v == null || int.tryParse(v) == null) ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _minQuantityController,
                      style: GoogleFonts.poppins(fontSize: 15),
                      decoration: _inputDecoration('Min Stock Alert', Icons.warning_amber_rounded),
                      keyboardType: TextInputType.number,
                      validator: (v) => (v == null || int.tryParse(v) == null) ? 'Invalid' : null,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              Text(
                'Pricing',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costPriceController,
                      style: GoogleFonts.poppins(fontSize: 15),
                      decoration: _inputDecoration('Cost Price', Icons.payments_outlined, prefixText: '\$'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => (v == null || double.tryParse(v) == null) ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _sellingPriceController,
                      style: GoogleFonts.poppins(fontSize: 15),
                      decoration: _inputDecoration('Selling Price', Icons.sell_outlined, prefixText: '\$'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => (v == null || double.tryParse(v) == null) ? 'Invalid' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              Text(
                'Supplier Info',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              
              TextFormField(
                controller: _supplierController,
                style: GoogleFonts.poppins(fontSize: 15),
                decoration: _inputDecoration('Supplier', Icons.domain, hintText: 'e.g. Acme Drinks'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _barcodeController,
                style: GoogleFonts.poppins(fontSize: 15),
                decoration: _inputDecoration('Barcode (Optional)', Icons.qr_code_2),
              ),
              const SizedBox(height: 48),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: _isSaving ? 0 : 4,
                    shadowColor: Colors.black38,
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                          isEditing ? 'Save Changes' : 'Add Item',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}