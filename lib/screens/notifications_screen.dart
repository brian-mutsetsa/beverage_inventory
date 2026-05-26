import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../models/audit_log.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../services/sync_service.dart';

class NotificationsScreen extends StatefulWidget {
  final User? currentUser;

  const NotificationsScreen({super.key, this.currentUser});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  StreamSubscription<SyncEvent>? _syncSubscription;

  List<AuditLog> _allLogs = [];
  Set<int> _fulfilledRequestIds = {};
  Map<int, Product> _productsMap = {};
  bool _isLoading = true;

  bool get _isManager => widget.currentUser?.isManager ?? false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _syncSubscription = SyncService.instance.onSync.listen((event) {
      if (event.table == SyncTable.auditLogs ||
          event.table == SyncTable.products ||
          event.table == SyncTable.all) {
        _loadNotifications();
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    if (_allLogs.isEmpty) setState(() => _isLoading = true);
    try {
      final logs = await _dbHelper.getOrderRequests();
      final fulfilled = await _dbHelper.getFulfilledOrderRequestIds();
      final products = await _dbHelper.readAllProducts();

      final productsMap = <int, Product>{};
      for (final p in products) {
        if (p.id != null) productsMap[p.id!] = p;
      }

      if (mounted) {
        setState(() {
          _allLogs = logs;
          _fulfilledRequestIds = fulfilled;
          _productsMap = productsMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Helpers ──

  int? _extractProductId(String? details) {
    if (details == null) return null;
    final match = RegExp(r'product_id:(\d+)').firstMatch(details);
    return match != null ? int.parse(match.group(1)!) : null;
  }

  int? _extractOriginalStock(String? details) {
    if (details == null) return null;
    // New format: "(stock: 3, min: 10, need: 7)"
    var match = RegExp(r'stock:\s*(\d+)').firstMatch(details);
    if (match != null) return int.parse(match.group(1)!);
    // Old format: "(current stock: 3)"
    match = RegExp(r'current stock:\s*(\d+)').firstMatch(details);
    return match != null ? int.parse(match.group(1)!) : null;
  }

  String _extractProductName(String? details) {
    if (details == null) return 'Unknown product';
    final match = RegExp(r'(?:for)\s+(.+?)\s*\(').firstMatch(details);
    return match?.group(1) ?? 'Unknown product';
  }

  String _timeAgo(String timestamp) {
    final date = DateTime.tryParse(timestamp);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  // ── Build Items ──

  List<_NotificationItem> _buildItems() {
    final items = <_NotificationItem>[];

    // Collect fulfilled logs keyed by request id
    final fulfillMap = <int, AuditLog>{};
    for (final log in _allLogs) {
      if (log.action == 'order_fulfilled' && log.details != null) {
        final match =
            RegExp(r'fulfilled_request_id:(\d+)').firstMatch(log.details!);
        if (match != null) {
          fulfillMap[int.parse(match.group(1)!)] = log;
        }
      }
    }

    // Collect stock_updated logs keyed by request id
    final stockUpdateMap = <int, List<AuditLog>>{};
    for (final log in _allLogs) {
      if (log.action == 'stock_updated' && log.details != null) {
        final match =
            RegExp(r'related_request_id:(\d+)').firstMatch(log.details!);
        if (match != null) {
          final reqId = int.parse(match.group(1)!);
          stockUpdateMap.putIfAbsent(reqId, () => []).add(log);
        }
      }
    }

    for (final log in _allLogs) {
      if (log.action != 'order_request') continue;

      final isFulfilled = _fulfilledRequestIds.contains(log.id);
      final fulfilledBy = fulfillMap[log.id];

      // Resolve product
      final productId = _extractProductId(log.details);
      Product? product;
      if (productId != null) {
        product = _productsMap[productId];
      } else {
        // Backward compat: try matching by name
        final name = _extractProductName(log.details);
        for (final p in _productsMap.values) {
          if (p.name == name) {
            product = p;
            break;
          }
        }
      }

      final originalStock = _extractOriginalStock(log.details);
      final stockUpdates = stockUpdateMap[log.id] ?? [];

      // Stock-based resolution: product stock now meets min
      final isStockResolved = product != null &&
          product.quantity >= product.minQuantity;

      items.add(_NotificationItem(
        request: log,
        isFulfilled: isFulfilled,
        fulfilledLog: fulfilledBy,
        isOwnRequest: log.userId == widget.currentUser?.id,
        product: product,
        originalStock: originalStock,
        stockUpdates: stockUpdates,
        isStockResolved: isStockResolved,
      ));
    }
    return items;
  }

  // ── Update Stock ──

  Future<void> _updateProductStock(_NotificationItem item, int addQuantity) async {
    if (item.product == null || widget.currentUser == null) return;

    final newQuantity = item.product!.quantity + addQuantity;
    final updatedProduct = item.product!.copyWith(
      quantity: newQuantity,
      updatedAt: DateTime.now().toIso8601String(),
    );

    await _dbHelper.updateProduct(updatedProduct);

    // Log manual edit
    await _dbHelper.logAction(AuditLog(
      companyId: DatabaseHelper.instance.currentCompanyId,
      userId: widget.currentUser!.id!,
      userName: widget.currentUser!.fullName,
      action: 'edit_product',
      details:
          'Updated stock for ${item.product!.name}: ${item.product!.quantity} \u2192 $newQuantity',
      timestamp: DateTime.now().toIso8601String(),
    ));

    await _loadNotifications();

    if (mounted) {
      final met = newQuantity >= item.product!.minQuantity;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            met
                ? '${item.product!.name} restocked to $newQuantity \u2713'
                : '${item.product!.name} updated to $newQuantity (need ${item.product!.minQuantity - newQuantity} more)',
          ),
          backgroundColor:
              met ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
        ),
      );
    }
  }

  // ── Dialogs ──

  void _showUpdateStockDialog(_NotificationItem item) {
    if (item.product == null) return;
    final product = item.product!;
    final deficit = product.minQuantity - product.quantity;
    final controller = TextEditingController(text: deficit > 0 ? deficit.toString() : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.add_shopping_cart, color: Color(0xFFFFB300)),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Add Stock',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.name,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _infoRow(
                        'Current Stock', '${product.quantity}', Colors.orange),
                    const SizedBox(height: 6),
                    _infoRow('Min Required', '${product.minQuantity}',
                        Colors.grey[700]!),
                    if (deficit > 0) ...[
                      const Divider(height: 16),
                      _infoRow(
                          'Need', '$deficit more', Colors.red),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity to Add',
                  hintText: 'e.g. $deficit',
                  prefixIcon: const Icon(Icons.add, color: Color(0xFFFFB300)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              if (deficit > 0)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        controller.text = deficit.toString(),
                    icon: const Icon(Icons.auto_fix_high, size: 16),
                    label: Text('Add $deficit (to meet minimum)',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFB300),
                      side: const BorderSide(color: Color(0xFFFFB300)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              // Preview
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final addQty = int.tryParse(value.text) ?? 0;
                  final newTotal = product.quantity + addQty;
                  final willMeet = newTotal >= product.minQuantity;
                  final remaining = product.minQuantity - newTotal;
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: willMeet
                          ? const Color(0xFFF1F8E9)
                          : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          willMeet ? Icons.check_circle : Icons.info_outline,
                          size: 16,
                          color: willMeet
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF9800),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            willMeet
                                ? 'New stock: $newTotal \u2014 meets minimum \u2713'
                                : 'New stock: $newTotal \u2014 still need $remaining more',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: willMeet
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFFF9800),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final addQty = int.tryParse(controller.text);
              if (addQty != null && addQty > 0) {
                Navigator.pop(ctx);
                _updateProductStock(item, addQty);
              }
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text('Add Stock',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: valueColor)),
      ],
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    final pendingItems = items.where((i) => !i.isResolved).toList();
    final resolvedItems = items.where((i) => i.isResolved).toList();
    final pendingCount = pendingItems.length;
    final resolvedCount = resolvedItems.length;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFFFFB300)))
          : RefreshIndicator(
              color: const Color(0xFFFFB300),
              onRefresh: _loadNotifications,
              child: items.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildSummaryBar(pendingCount, resolvedCount),
                        const SizedBox(height: 16),
                        if (pendingCount > 0) ...[
                          _buildSectionHeader(
                              'Pending', pendingCount, const Color(0xFFFF9800)),
                          const SizedBox(height: 8),
                          ...pendingItems.map(_buildNotificationCard),
                          const SizedBox(height: 20),
                        ],
                        if (resolvedCount > 0) ...[
                          _buildSectionHeader('Resolved', resolvedCount,
                              const Color(0xFF4CAF50)),
                          const SizedBox(height: 8),
                          ...resolvedItems.map(_buildNotificationCard),
                        ],
                      ],
                    ),
            ),
    );
  }

  Widget _buildSummaryBar(int pending, int fulfilled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF9800),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$pending Pending',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color:
                        pending > 0 ? const Color(0xFFFF9800) : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 24, color: Colors.grey[200]),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$fulfilled Resolved',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color:
                        fulfilled > 0 ? const Color(0xFF4CAF50) : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$label ($count)',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none_rounded,
                    size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No notifications yet',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Order requests will appear here',
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard(_NotificationItem item) {
    final log = item.request;
    final product = item.product;
    final productName = product?.name ?? _extractProductName(log.details);
    final isResolved = item.isResolved;

    // Stock info
    final currentStock = product?.quantity;
    final minRequired = product?.minQuantity;
    final deficit =
        (minRequired != null && currentStock != null && currentStock < minRequired)
            ? minRequired - currentStock
            : 0;

    // Card styling
    IconData icon;
    Color iconColor;
    Color? cardBorder;
    String title;
    String subtitle;

    if (isResolved) {
      icon = Icons.check_circle_rounded;
      iconColor = const Color(0xFF4CAF50);
      cardBorder = const Color(0xFF4CAF50).withValues(alpha: 0.3);
      title = '$productName \u2014 Restocked';
      if (currentStock != null && minRequired != null) {
        subtitle = 'Stock: $currentStock / Min: $minRequired \u2713';
      } else if (item.fulfilledLog != null) {
        subtitle =
            'Resolved by ${item.fulfilledLog!.userName} \u00b7 ${_timeAgo(item.fulfilledLog!.timestamp)}';
      } else {
        subtitle = 'Resolved';
      }
    } else if (item.isPartiallyFulfilled) {
      icon = Icons.trending_up_rounded;
      iconColor = const Color(0xFF2196F3);
      cardBorder = const Color(0xFF2196F3).withValues(alpha: 0.3);
      title = '$productName \u2014 Partially Restocked';
      subtitle =
          'Stock: $currentStock / Min: $minRequired (still need $deficit more)';
    } else {
      icon = Icons.notification_important_rounded;
      iconColor = const Color(0xFFFF9800);
      cardBorder = null;
      title = '$productName \u2014 Low Stock';
      if (currentStock != null && minRequired != null) {
        subtitle = 'Stock: $currentStock / Min: $minRequired (need $deficit more)';
      } else {
        subtitle = 'Pending';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isResolved ? const Color(0xFFF1F8E9) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder ?? Colors.grey[200]!),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isResolved
                                ? Colors.black54
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: isResolved
                                ? const Color(0xFF4CAF50)
                                : item.isPartiallyFulfilled
                                    ? const Color(0xFF2196F3)
                                    : Colors.grey[600],
                            fontWeight: (isResolved ||
                                    item.isPartiallyFulfilled)
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Requested by ${log.userName} \u00b7 ${_timeAgo(log.timestamp)}',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(item),
                ],
              ),

              // Stock update timeline entries
              if (item.stockUpdates.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...item.stockUpdates.map((su) => Padding(
                      padding: const EdgeInsets.only(left: 46, top: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3)
                                  .withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatStockUpdateText(su.details),
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFF2196F3)),
                            ),
                          ),
                          Text(
                            _timeAgo(su.timestamp),
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    )),
              ],

              // Resolved info
              if (isResolved && item.fulfilledLog != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 46),
                  child: Row(
                    children: [
                      const Icon(Icons.check, size: 14, color: Color(0xFF4CAF50)),
                      const SizedBox(width: 6),
                      Text(
                        _formatFulfilledText(item.fulfilledLog!),
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF4CAF50),
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],

              // Manager action: Update Stock button for pending items
              if (!isResolved && _isManager && product != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 46),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showUpdateStockDialog(item),
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: Text(
                          'Add Stock (need ${deficit > 0 ? deficit : 0} more)',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB300),
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatStockUpdateText(String? details) {
    if (details == null) return 'Stock updated';
    // "Stock updated: Coca Cola (3 → 7, need 3 more, min: 10)"
    final arrowMatch = RegExp(r'\((\d+)\s*\u2192\s*(\d+)').firstMatch(details);
    final needMatch = RegExp(r'need\s+(\d+)\s+more').firstMatch(details);
    if (arrowMatch != null) {
      final from = arrowMatch.group(1);
      final to = arrowMatch.group(2);
      final needPart =
          needMatch != null ? ' (need ${needMatch.group(1)} more)' : '';
      return 'Stock: $from \u2192 $to$needPart';
    }
    return 'Stock updated';
  }

  String _formatFulfilledText(AuditLog log) {
    if (log.userName == 'System') {
      return 'Auto-resolved when stock was replenished \u00b7 ${_timeAgo(log.timestamp)}';
    }
    return 'Resolved by ${log.userName} \u00b7 ${_timeAgo(log.timestamp)}';
  }

  Widget _buildStatusBadge(_NotificationItem item) {
    if (item.isResolved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Resolved',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4CAF50),
          ),
        ),
      );
    }

    if (item.isPartiallyFulfilled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'In Progress',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2196F3),
          ),
        ),
      );
    }

    if (_isManager) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFF9800).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_outlined,
                size: 12, color: Color(0xFFFF9800)),
            const SizedBox(width: 4),
            Text(
              'Action',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFF9800),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Pending',
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFFF9800),
        ),
      ),
    );
  }
}

/// Internal model for a notification item with stock context.
class _NotificationItem {
  final AuditLog request;
  final bool isFulfilled;
  final AuditLog? fulfilledLog;
  final bool isOwnRequest;
  final Product? product;
  final int? originalStock;
  final List<AuditLog> stockUpdates;
  final bool isStockResolved;

  _NotificationItem({
    required this.request,
    required this.isFulfilled,
    this.fulfilledLog,
    required this.isOwnRequest,
    this.product,
    this.originalStock,
    this.stockUpdates = const [],
    this.isStockResolved = false,
  });

  /// Resolved = explicitly fulfilled OR stock now meets minimum.
  bool get isResolved => isFulfilled || isStockResolved;

  /// Stock was partially replenished but still below min.
  bool get isPartiallyFulfilled =>
      !isResolved &&
      product != null &&
      originalStock != null &&
      product!.quantity > originalStock! &&
      product!.quantity < product!.minQuantity;
}
