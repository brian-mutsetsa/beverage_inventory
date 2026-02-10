import 'package:flutter/material.dart';
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
    // Listen to quantity changes
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
    setState(() {
      // This triggers rebuild which updates the total
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await _dbHelper.readAllProducts();
      final sales = await _dbHelper.readAllSales();
      
      setState(() {
        _products = products;
        _sales = sales;
        _isLoading = false;
        
        // Clear selection if product no longer exists
        if (_selectedProductId != null &&
            !_products.any((p) => p.id == _selectedProductId)) {
          _selectedProductId = null;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
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

  double get _totalAmount {
    if (_selectedProduct == null) return 0.0;
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    return _selectedProduct!.sellingPrice * quantity;
  }

  Future<void> _recordSale() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product')),
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid quantity')),
      );
      return;
    }

    if (quantity > _selectedProduct!.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not enough stock! Available: ${_selectedProduct!.quantity}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Create sale record
      final sale = Sale(
        productId: _selectedProduct!.id!,
        productName: _selectedProduct!.name,
        quantitySold: quantity,
        unitPrice: _selectedProduct!.sellingPrice,
        totalAmount: _selectedProduct!.sellingPrice * quantity,
        saleDate: DateTime.now().toIso8601String(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      await _dbHelper.createSale(sale);

      // Update product quantity
      final updatedProduct = _selectedProduct!.copyWith(
        quantity: _selectedProduct!.quantity - quantity,
        updatedAt: DateTime.now().toIso8601String(),
      );

      await _dbHelper.updateProduct(updatedProduct);

      // Log the action with user info
      if (widget.currentUser != null && widget.currentUser!.id != null) {
        await _dbHelper.logAction(AuditLog(
          userId: widget.currentUser!.id!,
          userName: widget.currentUser!.fullName,
          action: 'record_sale',
          details: 'Sold ${quantity}x ${_selectedProduct!.name} - \$${sale.totalAmount.toStringAsFixed(2)}',
          timestamp: DateTime.now().toIso8601String(),
        ));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sale recorded: ${quantity}x ${_selectedProduct!.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reset form
      setState(() {
        _selectedProductId = null;
        _quantityController.text = '1';
        _notesController.clear();
        _isProcessing = false;
      });

      // Reload data
      _loadData();
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording sale: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Sales Form
                  _buildSalesForm(),
                  
                  const Divider(height: 32),
                  
                  // Sales History
                  _buildSalesHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildSalesForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Record Sale',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Product Dropdown
          DropdownButtonFormField<int>(
            value: _selectedProductId,
            decoration: const InputDecoration(
              labelText: 'Select Product',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.local_drink),
            ),
            hint: const Text('Choose a product'),
            isExpanded: true,
            items: _products.map((product) {
              return DropdownMenuItem<int>(
                value: product.id,
                child: Text('${product.name} (Stock: ${product.quantity})'),
              );
            }).toList(),
            onChanged: (productId) {
              setState(() {
                _selectedProductId = productId;
              });
            },
          ),
          const SizedBox(height: 16),

          // Show selected product details
          if (_selectedProduct != null) ...[
            Card(
              color: const Color(0xFFE3F2FD),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Price per unit:'),
                        Text(
                          '\$${_selectedProduct!.sellingPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Available stock:'),
                        Text(
                          '${_selectedProduct!.quantity} units',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _selectedProduct!.quantity > 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Quantity Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.shopping_cart),
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !_isProcessing,
                  onChanged: (value) {
                    // This ensures total updates when typing
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Quick quantity buttons
              IconButton(
                onPressed: _isProcessing
                    ? null
                    : () {
                        final current = int.tryParse(_quantityController.text) ?? 1;
                        if (current > 1) {
                          setState(() {
                            _quantityController.text = (current - 1).toString();
                          });
                        }
                      },
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Decrease',
              ),
              IconButton(
                onPressed: _isProcessing
                    ? null
                    : () {
                        final current = int.tryParse(_quantityController.text) ?? 1;
                        setState(() {
                          _quantityController.text = (current + 1).toString();
                        });
                      },
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Increase',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Notes (Optional)
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (Optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note),
              hintText: 'e.g., Customer name',
            ),
            maxLines: 2,
            enabled: !_isProcessing,
          ),
          const SizedBox(height: 16),

          // Show total amount
          if (_selectedProduct != null) ...[
            Card(
              color: const Color(0xFFC8E6C9),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '\$${_totalAmount.toStringAsFixed(2)}',
                      key: ValueKey(_totalAmount),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Record Sale Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _recordSale,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
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
                  : const Text(
                      'Record Sale',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesHistory() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Sales History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${_sales.length} transactions',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sales.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No sales recorded yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _sales.length,
                  itemBuilder: (context, index) {
                    final sale = _sales[index];
                    return _buildSaleCard(sale);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(Sale sale) {
    final date = DateTime.parse(sale.saleDate);
    final dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(date);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.point_of_sale, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sale.productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${sale.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Quantity: ${sale.quantitySold}'),
                const SizedBox(width: 16),
                Text('Unit Price: \$${sale.unitPrice.toStringAsFixed(2)}'),
              ],
            ),
            if (sale.notes != null && sale.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sale.notes!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}