import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
import '../helpers/security_helper.dart';
import '../models/company.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/user.dart' as app_user;
import '../models/audit_log.dart';
import 'supabase_config.dart';
import 'supabase_service.dart';
import 'notification_service.dart';

/// Orchestrates syncing between local SQLite and Supabase cloud.
/// 
/// Architecture:
/// - Offline-first: SQLite is always the source of truth for reads
/// - Push on write: After every local write, push to Supabase in background
/// - Pull on demand: Full sync pulls cloud data into local DB
/// - Real-time: Subscribes to Supabase channels so other devices' changes
///   are reflected locally
class SyncService {
  static final SyncService instance = SyncService._init();
  SyncService._init();

  final _supabase = SupabaseService.instance;
  final _db = DatabaseHelper.instance;

  /// Stream controller that fires whenever remote data changes arrive.
  /// Screens can listen to this to know when to refresh.
  final _syncController = StreamController<SyncEvent>.broadcast();
  Stream<SyncEvent> get onSync => _syncController.stream;

  final List<RealtimeChannel> _activeChannels = [];

  bool get isEnabled => SupabaseConfig.isConfigured;

  /// Number of sales/products waiting to be synced to the cloud.
  final ValueNotifier<int> pendingCount = ValueNotifier(0);

  // Debounce state for cloud-save notifications (service-level, not screen-level)
  Timer? _cloudSaveDebounce;
  int _cloudSaveCount = 0;

  Future<void> _refreshPendingCount() async {
    final count = await _db.getSyncQueueCount();
    pendingCount.value = count;
  }

  // ==================== PUSH (Local → Cloud) ====================

  /// Push a single product to Supabase after local create/update.
  Future<void> pushProduct(Product product) async {
    if (!isEnabled) return;
    try {
      await _supabase.upsertProduct(product);
      _flushQueueInBackground();
    } catch (e) {
      if (product.id != null) {
        await _db.addToSyncQueue('product', product.id!, 'upsert');
        await _refreshPendingCount();
      }
    }
  }

  /// Push product deletion to Supabase.
  Future<void> pushProductDelete(int localId, String companyId) async {
    if (!isEnabled) return;
    await _supabase.deleteProduct(localId, companyId);
  }

  /// Push a single sale to Supabase after local create.
  Future<void> pushSale(Sale sale) async {
    debugPrint('[SyncService] pushSale called. isEnabled=$isEnabled saleId=${sale.id}');
    if (!isEnabled) {
      debugPrint('[SyncService] pushSale SKIPPED — isEnabled is false');
      return;
    }
    try {
      debugPrint('[SyncService] Calling upsertSale...');
      await _supabase.upsertSale(sale);
      debugPrint('[SyncService] upsertSale SUCCESS');
      _syncController.add(SyncEvent(SyncTable.sales, SyncAction.cloudSaved));
      _flushQueueInBackground();
      // Debounce cloud-save notification at service level (screen-independent)
      _cloudSaveCount++;
      _cloudSaveDebounce?.cancel();
      debugPrint('[SyncService] Scheduling notification in 800ms (count=$_cloudSaveCount)');
      _cloudSaveDebounce = Timer(const Duration(milliseconds: 800), () {
        final count = _cloudSaveCount;
        _cloudSaveCount = 0;
        debugPrint('[SyncService] Timer fired — calling showCloudSyncNotification(count=$count)');
        NotificationService.instance.showCloudSyncNotification(count);
      });
    } catch (e, stack) {
      debugPrint('[SyncService] pushSale FAILED: $e\n$stack');
      if (sale.id != null) {
        await _db.addToSyncQueue('sale', sale.id!, 'upsert');
        await _refreshPendingCount();
      }
    }
  }

  /// Push sale deletion to Supabase.
  Future<void> pushSaleDelete(int localId, String companyId) async {
    if (!isEnabled) return;
    await _supabase.deleteSale(localId, companyId);
  }

  /// Push a user to Supabase after local create/update.
  Future<void> pushUser(app_user.User user) async {
    if (!isEnabled) return;
    await _supabase.upsertUser(user);
  }

  /// Push an audit log entry to Supabase.
  Future<void> pushAuditLog(AuditLog log) async {
    if (!isEnabled) return;
    await _supabase.insertAuditLog(log);
  }

  /// Push a company to Supabase after registration.
  Future<void> pushCompany(Company company) async {
    if (!isEnabled) return;
    await _supabase.upsertCompany(company);
  }

  /// Fire a local sync event so other screens can react to local data changes.
  void notifyLocal(SyncTable table) {
    _syncController.add(SyncEvent(table, SyncAction.updated));
  }

  /// Retry all queued (failed) sync items.
  Future<void> flushQueue() async {
    if (!isEnabled) return;
    try {
      final queue = await _db.getSyncQueue();
      if (queue.isEmpty) return;
      for (final item in queue) {
        final id = item['id'] as int;
        final entityType = item['entityType'] as String;
        final entityId = item['entityId'] as int;
        try {
          if (entityType == 'sale') {
            final sales = await _db.readAllSales();
            final sale = sales.where((s) => s.id == entityId).firstOrNull;
            if (sale != null) await _supabase.upsertSale(sale);
          } else if (entityType == 'product') {
            final products = await _db.readAllProducts();
            final product = products.where((p) => p.id == entityId).firstOrNull;
            if (product != null) await _supabase.upsertProduct(product);
          }
          await _db.removeSyncQueueItem(id);
        } catch (e) {
          break; // Still offline, stop trying
        }
      }
      await _refreshPendingCount();
    } catch (e) {
      debugPrint('SyncService.flushQueue error: $e');
    }
  }

  void _flushQueueInBackground() {
    flushQueue();
  }

  // ==================== FULL SYNC (Cloud → Local) ====================

  /// Perform a full pull of all company data from Supabase into local SQLite.
  /// Used on app startup or manual refresh.
  Future<void> fullSync(String companyId) async {
    if (!isEnabled) return;

    try {
      await _syncProducts(companyId);
      await _syncSales(companyId);
      await _syncUsers(companyId);
      await _syncAuditLogs(companyId);

      _syncController.add(SyncEvent(SyncTable.all, SyncAction.synced));
      debugPrint('SyncService: Full sync completed for $companyId');
    } catch (e) {
      debugPrint('SyncService: Full sync error: $e');
    }
  }

  Future<void> _syncProducts(String companyId) async {
    final remoteProducts = await _supabase.getProducts(companyId);
    final localProducts = await _db.readAllProducts();
    final localIds = {for (var p in localProducts) p.id};

    for (final remote in remoteProducts) {
      final localId = remote['local_id'] as int;
      final product = Product(
        id: localId,
        companyId: remote['company_id'],
        name: remote['name'],
        category: remote['category'],
        quantity: remote['quantity'],
        minQuantity: remote['min_quantity'],
        costPrice: (remote['cost_price'] as num).toDouble(),
        sellingPrice: (remote['selling_price'] as num).toDouble(),
        supplier: remote['supplier'],
        barcode: remote['barcode'],
        imagePath: remote['image_path'],
        createdAt: remote['created_at'],
        updatedAt: remote['updated_at'],
      );

      if (localIds.contains(localId)) {
        // Update existing — cloud wins for data from other devices
        await _db.updateProduct(product);
      } else {
        // Insert — record from another device
        final db = await _db.database;
        await db.insert('products', product.toMap());
      }
    }
  }

  Future<void> _syncSales(String companyId) async {
    final remoteSales = await _supabase.getSales(companyId);
    final localSales = await _db.readAllSales();
    final localIds = {for (var s in localSales) s.id};

    for (final remote in remoteSales) {
      final localId = remote['local_id'] as int;

      if (!localIds.contains(localId)) {
        final sale = Sale(
          id: localId,
          companyId: remote['company_id'],
          productId: remote['product_id'],
          productName: remote['product_name'],
          quantitySold: remote['quantity_sold'],
          unitPrice: (remote['unit_price'] as num).toDouble(),
          totalAmount: (remote['total_amount'] as num).toDouble(),
          saleDate: remote['sale_date'],
          notes: remote['notes'],
        );
        final db = await _db.database;
        await db.insert('sales', sale.toMap());
      }
    }
  }

  Future<void> _syncUsers(String companyId) async {
    final remoteUsers = await _supabase.getUsers(companyId);
    final localUsers = await _db.getAllUsers();
    final localIds = {for (var u in localUsers) u.id};

    for (final remote in remoteUsers) {
      final localId = remote['local_id'] as int;
      // Always hash PINs from Supabase before local storage
      final rawPin = remote['pin'] as String;
      final safePin = SecurityHelper.isAlreadyHashed(rawPin)
          ? rawPin
          : SecurityHelper.hashPin(rawPin);
      final userMap = {
        'id': localId,
        'companyId': remote['company_id'],
        'pin': safePin,
        'fullName': remote['full_name'],
        'role': remote['role'],
        'phone': remote['phone'],
        'isActive': remote['is_active'] ?? 1,
        'createdAt': remote['created_at'],
        'createdBy': remote['created_by'],
        'lastLogin': remote['last_login'],
      };

      final db = await _db.database;
      if (localIds.contains(localId)) {
        // Direct DB update — do NOT call _db.updateUser which pushes hash back to Supabase
        await db.update('users', userMap, where: 'id = ?', whereArgs: [localId]);
      } else {
        await db.insert('users', userMap);
      }
    }
  }

  Future<void> _syncAuditLogs(String companyId) async {
    final remoteLogs = await _supabase.getAuditLogs(companyId);
    final localLogs = await _db.getAuditLogs();
    final localIds = {for (var l in localLogs) l.id};

    for (final remote in remoteLogs) {
      final localId = remote['local_id'] as int;
      if (!localIds.contains(localId)) {
        final log = AuditLog(
          id: localId,
          companyId: remote['company_id'],
          userId: remote['user_id'],
          userName: remote['user_name'],
          action: remote['action'],
          details: remote['details'],
          timestamp: remote['timestamp'],
        );
        final db = await _db.database;
        await db.insert('audit_logs', log.toMap());
      }
    }
  }

  // ==================== PUSH ALL (Local → Cloud) ====================

  /// Push all local data to Supabase. Useful for initial upload when
  /// Supabase is first configured.
  Future<void> pushAll(String companyId) async {
    if (!isEnabled) return;

    try {
      final products = await _db.readAllProducts();
      for (final p in products) {
        await _supabase.upsertProduct(p);
      }

      final sales = await _db.readAllSales();
      for (final s in sales) {
        await _supabase.upsertSale(s);
      }

      final users = await _db.getAllUsers();
      for (final u in users) {
        await _supabase.upsertUser(u);
      }

      final logs = await _db.getAuditLogs();
      for (final l in logs) {
        await _supabase.insertAuditLog(l);
      }

      debugPrint('SyncService: Push all completed for $companyId');
    } catch (e) {
      debugPrint('SyncService: Push all error: $e');
    }
  }

  // ==================== REAL-TIME LISTENERS ====================

  /// Start listening for real-time changes on all tables for a company.
  /// Call this after login when companyId is known.
  void startListening(String companyId) {
    if (!isEnabled) return;
    stopListening(); // Clear any existing subscriptions

    // Products channel
    _activeChannels.add(_supabase.subscribeToTable(
      table: 'products',
      companyId: companyId,
      onInsert: (_) => _syncController.add(SyncEvent(SyncTable.products, SyncAction.inserted)),
      onUpdate: (_) => _syncController.add(SyncEvent(SyncTable.products, SyncAction.updated)),
      onDelete: (_) => _syncController.add(SyncEvent(SyncTable.products, SyncAction.deleted)),
    ));

    // Sales channel
    _activeChannels.add(_supabase.subscribeToTable(
      table: 'sales',
      companyId: companyId,
      onInsert: (_) => _syncController.add(SyncEvent(SyncTable.sales, SyncAction.inserted)),
      onUpdate: (_) => _syncController.add(SyncEvent(SyncTable.sales, SyncAction.updated)),
      onDelete: (_) => _syncController.add(SyncEvent(SyncTable.sales, SyncAction.deleted)),
    ));

    // Users channel
    _activeChannels.add(_supabase.subscribeToTable(
      table: 'app_users',
      companyId: companyId,
      onInsert: (_) => _syncController.add(SyncEvent(SyncTable.users, SyncAction.inserted)),
      onUpdate: (_) => _syncController.add(SyncEvent(SyncTable.users, SyncAction.updated)),
      onDelete: (_) => _syncController.add(SyncEvent(SyncTable.users, SyncAction.deleted)),
    ));

    // Audit logs channel
    _activeChannels.add(_supabase.subscribeToTable(
      table: 'audit_logs',
      companyId: companyId,
      onInsert: (_) => _syncController.add(SyncEvent(SyncTable.auditLogs, SyncAction.inserted)),
      onUpdate: (_) => _syncController.add(SyncEvent(SyncTable.auditLogs, SyncAction.updated)),
      onDelete: (_) => _syncController.add(SyncEvent(SyncTable.auditLogs, SyncAction.deleted)),
    ));

    debugPrint('SyncService: Real-time listeners started for $companyId');
  }

  /// Stop all real-time listeners. Call on logout.
  void stopListening() {
    for (final channel in _activeChannels) {
      _supabase.unsubscribe(channel);
    }
    _activeChannels.clear();
  }

  void dispose() {
    stopListening();
    _syncController.close();
  }
}

// ==================== SYNC EVENT MODEL ====================

enum SyncTable { products, sales, users, auditLogs, all }
enum SyncAction { inserted, updated, deleted, synced, cloudSaved }

class SyncEvent {
  final SyncTable table;
  final SyncAction action;
  SyncEvent(this.table, this.action);
}
