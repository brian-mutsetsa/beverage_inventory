import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../models/order.dart' as app_order;
import '../models/order_item.dart';
import '../models/user.dart';
import '../models/audit_log.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  final User currentUser;

  const OrderDetailScreen({super.key, required this.orderId, required this.currentUser});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  app_order.Order? _order;
  List<OrderItem> _items = [];
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() => _isLoading = true);
    try {
      final order = await _dbHelper.getOrderById(widget.orderId);
      final items = await _dbHelper.getOrderItems(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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

  Future<void> _updateStatus(String newStatus) async {
    if (_order == null) return;

    // If moving to processing, decrement stock
    if (newStatus == 'processing' && _order!.status == 'pending') {
      // Check stock availability
      for (final item in _items) {
        final product = await _dbHelper.readProduct(item.productId);
        if (product == null || product.quantity < item.quantity) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${item.productName}: not enough stock (${product?.quantity ?? 0} available)'),
                backgroundColor: const Color(0xFFE53935),
              ),
            );
          }
          return;
        }
      }
    }

    setState(() => _isProcessing = true);

    try {
      await _dbHelper.updateOrderStatus(widget.orderId, newStatus);

      // Decrement stock when starting processing
      if (newStatus == 'processing' && _order!.status == 'pending') {
        for (final item in _items) {
          await _dbHelper.adjustStock(item.productId, -item.quantity, 'Order #${widget.orderId} processing');
        }
      }

      // Restore stock if cancelling a processing order
      if (newStatus == 'cancelled' && _order!.status == 'processing') {
        for (final item in _items) {
          await _dbHelper.adjustStock(item.productId, item.quantity, 'Order #${widget.orderId} cancelled');
        }
      }

      await _dbHelper.logAction(AuditLog(
        companyId: DatabaseHelper.instance.currentCompanyId,
        userId: widget.currentUser.id!,
        userName: widget.currentUser.fullName,
        action: 'update_order',
        details: 'Order #${widget.orderId} → $newStatus',
        timestamp: DateTime.now().toIso8601String(),
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order updated to $newStatus'), backgroundColor: const Color(0xFF4CAF50)),
        );
      }

      _loadOrder();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  List<_StatusAction> _getActions() {
    if (_order == null) return [];
    switch (_order!.status) {
      case 'pending':
        return [
          _StatusAction('Start Processing', 'processing', const Color(0xFF42A5F5), Icons.play_arrow),
          _StatusAction('Cancel', 'cancelled', const Color(0xFFE53935), Icons.cancel_outlined),
        ];
      case 'processing':
        return [
          _StatusAction('Mark Completed', 'completed', const Color(0xFF4CAF50), Icons.check_circle_outline),
          _StatusAction('Cancel', 'cancelled', const Color(0xFFE53935), Icons.cancel_outlined),
        ];
      case 'completed':
        return [
          _StatusAction('Mark Delivered', 'delivered', const Color(0xFF7E57C2), Icons.local_shipping_outlined),
        ];
      default:
        return [];
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
        title: Text('Order #${widget.orderId}', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _order == null
              ? Center(child: Text('Order not found', style: GoogleFonts.poppins(color: Colors.grey[400])))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          // Status badge
                          _buildStatusBadge(),
                          const SizedBox(height: 20),
                          // Customer info
                          _buildSection('Customer', [
                            _buildInfoRow(Icons.person_outline, _order!.customerName),
                            if (_order!.customerPhone != null) _buildInfoRow(Icons.phone_outlined, _order!.customerPhone!),
                            if (_order!.customerAddress != null) _buildInfoRow(Icons.location_on_outlined, _order!.customerAddress!),
                          ]),
                          const SizedBox(height: 16),
                          // Items
                          _buildSection('Items', [
                            ..._items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Expanded(child: Text(item.productName, style: GoogleFonts.poppins(fontSize: 13))),
                                  Text('${item.quantity}x', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                                  const SizedBox(width: 8),
                                  Text('\$${item.lineTotal.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            )),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
                                Text('\$${_order!.totalAmount.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ]),
                          if (_order!.notes != null && _order!.notes!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildSection('Notes', [
                              Text(_order!.notes!, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700])),
                            ]),
                          ],
                          const SizedBox(height: 16),
                          // Timestamps
                          _buildSection('Timeline', [
                            _buildInfoRow(Icons.schedule, 'Created: ${_formatDate(_order!.createdAt)}'),
                            _buildInfoRow(Icons.update, 'Updated: ${_formatDate(_order!.updatedAt)}'),
                          ]),
                        ],
                      ),
                    ),
                    // Action buttons
                    if (_getActions().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: Colors.grey[200]!)),
                        ),
                        child: Row(
                          children: _getActions().map((action) {
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ElevatedButton.icon(
                                  onPressed: _isProcessing ? null : () => _confirmAction(action),
                                  icon: Icon(action.icon, size: 18),
                                  label: Text(action.label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: action.color,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
    );
  }

  void _confirmAction(_StatusAction action) {
    if (action.status == 'cancelled') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Cancel Order?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text(
            _order!.status == 'processing'
                ? 'This will restore reserved stock back to inventory.'
                : 'This order will be cancelled.',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('No', style: GoogleFonts.poppins(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateStatus(action.status);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
              child: Text('Cancel Order', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      _updateStatus(action.status);
    }
  }

  Widget _buildStatusBadge() {
    final color = _statusColor(_order!.status);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Text(
          _order!.status[0].toUpperCase() + _order!.status.substring(1),
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.poppins(fontSize: 13))),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusAction {
  final String label;
  final String status;
  final Color color;
  final IconData icon;
  _StatusAction(this.label, this.status, this.color, this.icon);
}
