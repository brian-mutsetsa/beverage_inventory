import 'dart:async';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/company.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/user.dart';
import '../models/audit_log.dart';
import '../models/order.dart' as app_order;
import '../models/order_item.dart';
import '../services/sync_service.dart';
import '../services/notification_service.dart';
import '../helpers/security_helper.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  String currentCompanyId = '';

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('beverage_inventory.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6, // UPGRADED FROM 5 TO 6
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';
    const companyIdType = 'TEXT NOT NULL';

    // Products table
    await db.execute('''
    CREATE TABLE products (
      id $idType,
      companyId $companyIdType,
      name $textType,
      category $textType,
      quantity $intType,
      minQuantity $intType,
      costPrice $realType,
      sellingPrice $realType,
      supplier $textType,
      barcode TEXT,
      imagePath TEXT,
      createdAt $textType,
      updatedAt $textType
    )
    ''');

    // Sales table
    await db.execute('''
    CREATE TABLE sales (
      id $idType,
      companyId $companyIdType,
      productId $intType,
      productName $textType,
      quantitySold $intType,
      unitPrice $realType,
      totalAmount $realType,
      saleDate $textType,
      notes TEXT
    )
    ''');

    // Users table
    await db.execute('''
    CREATE TABLE users (
      id $idType,
      companyId $companyIdType,
      pin $textType,
      fullName $textType,
      role $textType,
      phone TEXT,
      isActive INTEGER DEFAULT 1,
      createdAt $textType,
      createdBy INTEGER,
      lastLogin TEXT
    )
    ''');

    // Audit logs table
    await db.execute('''
    CREATE TABLE audit_logs (
      id $idType,
      companyId $companyIdType,
      userId $intType,
      userName $textType,
      action $textType,
      details TEXT,
      timestamp $textType
    )
    ''');
    // Companies table
    await db.execute('''
    CREATE TABLE companies (
      id $idType,
      companyId $companyIdType,
      name $textType,
      createdBy $textType,
      createdAt $textType
    )
    ''');

    // Orders table
    await db.execute('''
    CREATE TABLE orders (
      id $idType,
      companyId $companyIdType,
      customerName $textType,
      customerPhone TEXT,
      customerAddress TEXT,
      status $textType DEFAULT 'pending',
      totalAmount $realType,
      notes TEXT,
      createdAt $textType,
      updatedAt $textType,
      createdBy $intType
    )
    ''');

    // Order items table
    await db.execute('''
    CREATE TABLE order_items (
      id $idType,
      orderId $intType,
      productId $intType,
      productName $textType,
      quantity $intType,
      unitPrice $realType,
      lineTotal $realType,
      FOREIGN KEY (orderId) REFERENCES orders(id)
    )
    ''');

    // Performance indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_companyId ON products(companyId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_companyId ON sales(companyId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_users_companyId ON users(companyId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_logs_companyId ON audit_logs(companyId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_companies_companyId ON companies(companyId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_users_pin ON users(pin)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_saleDate ON sales(saleDate)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_companyId ON orders(companyId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_order_items_orderId ON order_items(orderId)');

    // Sync queue for offline support
    await db.execute('''
    CREATE TABLE sync_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      companyId TEXT NOT NULL,
      entityType TEXT NOT NULL,
      entityId INTEGER NOT NULL,
      action TEXT NOT NULL DEFAULT 'upsert',
      createdAt TEXT NOT NULL
    )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add audit_logs table if upgrading from version 1
      await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        userName TEXT NOT NULL,
        action TEXT NOT NULL,
        details TEXT,
        timestamp TEXT NOT NULL
      )
      ''');
    }
    if (oldVersion < 4) {
      // Add companies table
      await db.execute('''
      CREATE TABLE IF NOT EXISTS companies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        companyId TEXT NOT NULL,
        name TEXT NOT NULL,
        createdBy TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_companies_companyId ON companies(companyId)');
    }
    if (oldVersion < 5) {
      // Add orders and order_items tables
      await db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        companyId TEXT NOT NULL,
        customerName TEXT NOT NULL,
        customerPhone TEXT,
        customerAddress TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        totalAmount REAL NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        createdBy INTEGER NOT NULL
      )
      ''');
      await db.execute('''
      CREATE TABLE IF NOT EXISTS order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId INTEGER NOT NULL,
        productId INTEGER NOT NULL,
        productName TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unitPrice REAL NOT NULL,
        lineTotal REAL NOT NULL,
        FOREIGN KEY (orderId) REFERENCES orders(id)
      )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_companyId ON orders(companyId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_order_items_orderId ON order_items(orderId)');

      // Migrate plaintext PINs to hashed PINs
      await _migratePinsToHashed(db);
    }
    if (oldVersion < 6) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        companyId TEXT NOT NULL,
        entityType TEXT NOT NULL,
        entityId INTEGER NOT NULL,
        action TEXT NOT NULL DEFAULT 'upsert',
        createdAt TEXT NOT NULL
      )
      ''');
    }
  }

  /// One-time migration: hash all plaintext PINs in the users table.
  static Future<void> _migratePinsToHashed(Database db) async {
    final users = await db.query('users');
    for (final row in users) {
      final pin = row['pin'] as String;
      if (!SecurityHelper.isAlreadyHashed(pin)) {
        final hashed = SecurityHelper.hashPin(pin);
        await db.update(
          'users',
          {'pin': hashed},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }

  // ==================== COMPANY METHODS ====================

  Future<Company> createCompany(Company company) async {
    final db = await database;
    final id = await db.insert('companies', company.toMap());
    final created = company.copyWith(id: id);
    SyncService.instance.pushCompany(created);
    return created;
  }

  Future<Company?> getCompany(String companyId) async {
    final db = await database;
    final maps = await db.query(
      'companies',
      where: 'companyId = ?',
      whereArgs: [companyId],
    );
    if (maps.isNotEmpty) {
      return Company.fromMap(maps.first);
    }
    return null;
  }

  // ==================== PRODUCT METHODS ====================

  Future<Product> createProduct(Product product) async {
    final db = await database;
    final id = await db.insert('products', product.toMap());
    final created = product.copyWith(id: id);
    // Push to cloud in background
    SyncService.instance.pushProduct(created);
    return created;
  }

  Future<Product?> readProduct(int id) async {
    final db = await database;
    final maps = await db.query('products', where: 'id = ? AND companyId = ?', whereArgs: [id, currentCompanyId]);

    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Product>> readAllProducts() async {
    final db = await database;
    const orderBy = 'name ASC';
    final result = await db.query(
      'products',
      where: 'companyId = ?',
      whereArgs: [currentCompanyId],
      orderBy: orderBy,
    );
    return result.map((map) => Product.fromMap(map)).toList();
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;

    // Get old product to detect stock changes
    final oldMaps = await db.query('products', where: 'id = ?', whereArgs: [product.id]);
    final oldProduct = oldMaps.isNotEmpty ? Product.fromMap(oldMaps.first) : null;

    final result = await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
    // Push to cloud in background
    SyncService.instance.pushProduct(product);

    // Auto-resolve order requests if stock changed
    if (oldProduct != null && product.quantity != oldProduct.quantity) {
      await _checkAndResolveOrderRequests(product, oldProduct.quantity);
    }

    // Notify all screens of product change
    SyncService.instance.notifyLocal(SyncTable.products);

    return result;
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    final result = await db.delete('products', where: 'id = ? AND companyId = ?', whereArgs: [id, currentCompanyId]);
    // Push deletion to cloud
    SyncService.instance.pushProductDelete(id, currentCompanyId);
    return result;
  }

  Future<int> getProductCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE companyId = ?',
      [currentCompanyId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<double> getTotalInventoryValue() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(quantity * sellingPrice) as total FROM products WHERE companyId = ?',
      [currentCompanyId],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Product>> getLowStockProducts() async {
    final db = await database;
    final result = await db.query(
      'products',
      where: 'companyId = ? AND quantity < minQuantity',
      whereArgs: [currentCompanyId],
      orderBy: 'quantity ASC',
    );
    return result.map((map) => Product.fromMap(map)).toList();
  }

  // ==================== SALE METHODS ====================

  Future<Sale> createSale(Sale sale) async {
    final db = await database;
    final id = await db.insert('sales', sale.toMap());
    final created = sale.copyWith(id: id);
    // Push to cloud in background
    SyncService.instance.pushSale(created);
    return created;
  }

  Future<List<Sale>> readAllSales() async {
    final db = await database;
    const orderBy = 'saleDate DESC';
    final result = await db.query(
      'sales',
      where: 'companyId = ?',
      whereArgs: [currentCompanyId],
      orderBy: orderBy,
    );
    return result.map((map) => Sale.fromMap(map)).toList();
  }

  Future<int> deleteSale(int id) async {
    final db = await database;
    final result = await db.delete('sales', where: 'id = ? AND companyId = ?', whereArgs: [id, currentCompanyId]);
    // Push deletion to cloud
    SyncService.instance.pushSaleDelete(id, currentCompanyId);
    return result;
  }

  // ==================== USER METHODS ====================

  Future<User> createUser(User user) async {
    final db = await database;
    final originalPin = user.pin;
    // Hash the PIN before storing locally
    final hashedPin = SecurityHelper.isAlreadyHashed(originalPin)
        ? originalPin
        : SecurityHelper.hashPin(originalPin);
    final userWithHashedPin = user.copyWith(pin: hashedPin);
    final id = await db.insert('users', userWithHashedPin.toMap());
    final created = userWithHashedPin.copyWith(id: id);
    // Push PLAINTEXT PIN to Supabase (so managers can see PINs and other devices can join)
    final createdForCloud = created.copyWith(pin: originalPin);
    SyncService.instance.pushUser(createdForCloud);
    return created;
  }

  Future<User?> getUserByPin(String pin) async {
    final db = await database;
    final hashedPin = SecurityHelper.hashPin(pin);
    final maps = await db.query(
      'users',
      where: 'pin = ? AND isActive = 1 AND companyId = ?',
      whereArgs: [hashedPin, currentCompanyId],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getManagerUser() async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'role = ? AND companyId = ?',
      whereArgs: ['manager', currentCompanyId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'companyId = ?',
      whereArgs: [currentCompanyId],
      orderBy: 'createdAt DESC',
    );
    return result.map((map) => User.fromMap(map)).toList();
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    final result = db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
    // Push to cloud in background
    SyncService.instance.pushUser(user);
    return result;
  }

  Future<void> deactivateUser(int userId) async {
    final db = await database;
    await db.update(
      'users',
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> reactivateUser(int userId) async {
    final db = await database;
    await db.update(
      'users',
      {'isActive': 1},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<String> generateUniquePIN(String prefix) async {
    final random = Random();
    String pin;
    bool isUnique = false;

    do {
      pin = prefix;
      for (int i = 0; i < 3; i++) {
        pin += random.nextInt(10).toString();
      }

      // Reject weak PINs
      if (SecurityHelper.isWeakPin(pin)) continue;

      final hashedPin = SecurityHelper.hashPin(pin);
      final db = await database;
      final existing = await db.query(
        'users',
        where: 'pin = ? AND companyId = ?',
        whereArgs: [hashedPin, currentCompanyId],
      );
      isUnique = existing.isEmpty;
    } while (!isUnique);

    return pin;
  }

  // ==================== AUDIT LOG METHODS ====================

  Future<AuditLog> logAction(AuditLog log) async {
    final db = await database;
    final id = await db.insert('audit_logs', log.toMap());
    // Push to cloud in background
    final created = AuditLog(
      id: id,
      companyId: log.companyId,
      userId: log.userId,
      userName: log.userName,
      action: log.action,
      details: log.details,
      timestamp: log.timestamp,
    );
    SyncService.instance.pushAuditLog(created);
    // Notify screens of new audit log
    SyncService.instance.notifyLocal(SyncTable.auditLogs);
    return created;
  }

  Future<List<AuditLog>> getAuditLogs({int? limit}) async {
    final db = await database;
    final result = await db.query(
      'audit_logs',
      where: 'companyId = ?',
      whereArgs: [currentCompanyId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return result.map((map) => AuditLog.fromMap(map)).toList();
  }

  Future<List<AuditLog>> getAuditLogsByAction(String action, {int? limit}) async {
    final db = await database;
    final result = await db.query(
      'audit_logs',
      where: 'action = ? AND companyId = ?',
      whereArgs: [action, currentCompanyId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return result.map((map) => AuditLog.fromMap(map)).toList();
  }

  Future<List<AuditLog>> getAuditLogsByUser(int userId) async {
    final db = await database;
    final result = await db.query(
      'audit_logs',
      where: 'userId = ? AND companyId = ?',
      whereArgs: [userId, currentCompanyId],
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => AuditLog.fromMap(map)).toList();
  }

  Future<List<AuditLog>> getOrderRequests() async {
    final db = await database;
    final result = await db.query(
      'audit_logs',
      where: "(action = 'order_request' OR action = 'order_fulfilled' OR action = 'stock_updated') AND companyId = ?",
      whereArgs: [currentCompanyId],
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => AuditLog.fromMap(map)).toList();
  }

  /// Get all order_fulfilled log IDs that reference a specific order_request ID.
  Future<Set<int>> getFulfilledOrderRequestIds() async {
    final db = await database;
    final result = await db.query(
      'audit_logs',
      columns: ['details'],
      where: "action = 'order_fulfilled' AND companyId = ?",
      whereArgs: [currentCompanyId],
    );
    final ids = <int>{};
    for (final row in result) {
      final details = row['details'] as String? ?? '';
      // Details contain "fulfilled_request_id:123"
      final match = RegExp(r'fulfilled_request_id:(\d+)').firstMatch(details);
      if (match != null) {
        ids.add(int.parse(match.group(1)!));
      }
    }
    return ids;
  }

  Future<bool> hasRecentOrderRequest(int productId) async {
    final db = await database;
    final oneDayAgo = DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
    final result = await db.query(
      'audit_logs',
      where: "action = 'order_request' AND companyId = ? AND details LIKE ? AND timestamp > ?",
      whereArgs: [currentCompanyId, '%Reorder request for %', oneDayAgo],
    );
    // Check if any of those logs contain a product name matching this productId
    if (result.isEmpty) return false;
    final product = await readProduct(productId);
    if (product == null) return false;
    return result.any((r) => (r['details'] as String? ?? '').contains(product.name));
  }

  /// Extract product_id from order request details string.
  int? extractProductIdFromDetails(String? details) {
    if (details == null) return null;
    final match = RegExp(r'product_id:(\d+)').firstMatch(details);
    return match != null ? int.parse(match.group(1)!) : null;
  }

  /// Check pending order requests when product stock changes and auto-resolve.
  Future<void> _checkAndResolveOrderRequests(Product product, int oldQuantity) async {
    if (product.id == null) return;
    final db = await database;

    // Find order_request logs for this product
    final requests = await db.query(
      'audit_logs',
      where: "action = 'order_request' AND companyId = ? AND (details LIKE ? OR details LIKE ?)",
      whereArgs: [
        currentCompanyId,
        '%product_id:${product.id}%',
        '%for ${product.name} (%',
      ],
    );

    if (requests.isEmpty) return;

    final fulfilled = await getFulfilledOrderRequestIds();
    final pendingRequests = requests
        .map((r) => AuditLog.fromMap(r))
        .where((r) => !fulfilled.contains(r.id))
        .toList();

    if (pendingRequests.isEmpty) return;

    final isFullyResolved = product.quantity >= product.minQuantity;
    final deficit = product.minQuantity - product.quantity;

    for (final req in pendingRequests) {
      if (isFullyResolved) {
        // Auto-create order_fulfilled
        final details =
            'Auto-resolved: ${product.name} restocked ($oldQuantity \u2192 ${product.quantity}, min: ${product.minQuantity}) | fulfilled_request_id:${req.id} | product_id:${product.id}';
        final fulfilledLog = AuditLog(
          companyId: currentCompanyId,
          userId: req.userId,
          userName: 'System',
          action: 'order_fulfilled',
          details: details,
          timestamp: DateTime.now().toIso8601String(),
        );
        final id = await db.insert('audit_logs', fulfilledLog.toMap());
        SyncService.instance.pushAuditLog(AuditLog(
          id: id,
          companyId: fulfilledLog.companyId,
          userId: fulfilledLog.userId,
          userName: fulfilledLog.userName,
          action: fulfilledLog.action,
          details: fulfilledLog.details,
          timestamp: fulfilledLog.timestamp,
        ));
      } else if (product.quantity > oldQuantity) {
        // Stock increased but still below min — log progress
        final details =
            'Stock updated: ${product.name} ($oldQuantity \u2192 ${product.quantity}, need $deficit more, min: ${product.minQuantity}) | related_request_id:${req.id} | product_id:${product.id}';
        final updateLog = AuditLog(
          companyId: currentCompanyId,
          userId: req.userId,
          userName: 'System',
          action: 'stock_updated',
          details: details,
          timestamp: DateTime.now().toIso8601String(),
        );
        final id = await db.insert('audit_logs', updateLog.toMap());
        SyncService.instance.pushAuditLog(AuditLog(
          id: id,
          companyId: updateLog.companyId,
          userId: updateLog.userId,
          userName: updateLog.userName,
          action: updateLog.action,
          details: updateLog.details,
          timestamp: updateLog.timestamp,
        ));
      }
    }

    // Fire push notification
    try {
      if (isFullyResolved) {
        NotificationService.instance.showInstantNotification(
          '\u2705 Stock Replenished',
          '${product.name} restocked to ${product.quantity} (min: ${product.minQuantity})',
        );
      } else if (product.quantity > oldQuantity) {
        NotificationService.instance.showInstantNotification(
          '\ud83d\udce6 Stock Updated',
          '${product.name}: $oldQuantity \u2192 ${product.quantity} (still need $deficit more)',
        );
      }
    } catch (_) {}
  }

  // ==================== REPORT METHODS ====================

  // Sales Reports
  Future<double> getTotalSales({String? startDate, String? endDate}) async {
    final db = await database;
    String query = 'SELECT SUM(totalAmount) as total FROM sales WHERE companyId = ?';
    List<dynamic> args = [currentCompanyId];

    if (startDate != null && endDate != null) {
      query += ' AND saleDate >= ? AND saleDate <= ?';
      args.addAll([startDate, endDate]);
    } else if (startDate != null) {
      query += ' AND saleDate >= ?';
      args.add(startDate);
    } else if (endDate != null) {
      query += ' AND saleDate <= ?';
      args.add(endDate);
    }

    final result = await db.rawQuery(query, args);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> getTotalSalesCount({String? startDate, String? endDate}) async {
    final db = await database;
    String query = 'SELECT COUNT(*) as count FROM sales WHERE companyId = ?';
    List<dynamic> args = [currentCompanyId];

    if (startDate != null && endDate != null) {
      query += ' AND saleDate >= ? AND saleDate <= ?';
      args.addAll([startDate, endDate]);
    }

    final result = await db.rawQuery(query, args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getSalesByProduct({
    String? startDate,
    String? endDate,
  }) async {
    final db = await database;
    String query = '''
      SELECT 
        productName,
        SUM(quantitySold) as totalQuantity,
        SUM(totalAmount) as totalRevenue,
        COUNT(*) as transactionCount
      FROM sales
      WHERE companyId = ?
    ''';
    List<dynamic> args = [currentCompanyId];

    if (startDate != null && endDate != null) {
      query += ' AND saleDate >= ? AND saleDate <= ?';
      args.addAll([startDate, endDate]);
    }

    query += ' GROUP BY productName ORDER BY totalRevenue DESC';

    final result = await db.rawQuery(query, args);
    return result;
  }

  Future<List<Map<String, dynamic>>> getDailySales({int days = 7}) async {
    final db = await database;
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));

    final result = await db.rawQuery(
      '''
      SELECT 
        DATE(saleDate) as date,
        SUM(totalAmount) as total,
        COUNT(*) as count
      FROM sales
      WHERE companyId = ? AND saleDate >= ? AND saleDate <= ?
      GROUP BY DATE(saleDate)
      ORDER BY date ASC
    ''',
      [currentCompanyId, startDate.toIso8601String(), endDate.toIso8601String()],
    );

    return result;
  }

  // Inventory Reports
  Future<Map<String, dynamic>> getInventoryStats() async {
    final db = await database;

    final totalProducts = await getProductCount();
    final totalValue = await getTotalInventoryValue();
    final lowStockCount = (await getLowStockProducts()).length;

    final costResult = await db.rawQuery(
      'SELECT SUM(quantity * costPrice) as totalCost FROM products WHERE companyId = ?',
      [currentCompanyId],
    );
    final totalCost =
        (costResult.first['totalCost'] as num?)?.toDouble() ?? 0.0;

    return {
      'totalProducts': totalProducts,
      'totalValue': totalValue,
      'totalCost': totalCost,
      'potentialProfit': totalValue - totalCost,
      'lowStockCount': lowStockCount,
    };
  }

  Future<List<Map<String, dynamic>>> getProductsByCategory() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        category,
        COUNT(*) as productCount,
        SUM(quantity) as totalQuantity,
        SUM(quantity * sellingPrice) as totalValue
      FROM products
      WHERE companyId = ?
      GROUP BY category
      ORDER BY totalValue DESC
    ''', [currentCompanyId]);
    return result;
  }

  // Top Sellers & Slow Movers for enhanced inventory report
  Future<List<Map<String, dynamic>>> getTopSellers({int days = 30, int limit = 5}) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final result = await db.rawQuery('''
      SELECT 
        p.name,
        p.category,
        SUM(s.quantitySold) as totalSold,
        SUM(s.totalAmount) as totalRevenue
      FROM sales s
      JOIN products p ON s.productId = p.id
      WHERE s.companyId = ? AND s.saleDate >= ?
      GROUP BY s.productId
      ORDER BY totalSold DESC
      LIMIT ?
    ''', [currentCompanyId, startDate, limit]);
    return result;
  }

  Future<List<Map<String, dynamic>>> getSlowMovers({int days = 30}) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final result = await db.rawQuery('''
      SELECT 
        p.name,
        p.category,
        p.quantity,
        COALESCE(SUM(s.quantitySold), 0) as totalSold
      FROM products p
      LEFT JOIN sales s ON p.id = s.productId AND s.saleDate >= ?
      WHERE p.companyId = ?
      GROUP BY p.id
      HAVING totalSold < 5
      ORDER BY totalSold ASC
    ''', [startDate, currentCompanyId]);
    return result;
  }

  Future<List<Map<String, dynamic>>> getStockHealth() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        CASE 
          WHEN quantity = 0 THEN 'Out of Stock'
          WHEN quantity <= minQuantity THEN 'Low Stock'
          WHEN quantity <= minQuantity * 2 THEN 'Fair'
          ELSE 'Healthy'
        END as status,
        COUNT(*) as count
      FROM products
      WHERE companyId = ?
      GROUP BY status
      ORDER BY 
        CASE status
          WHEN 'Out of Stock' THEN 1
          WHEN 'Low Stock' THEN 2
          WHEN 'Fair' THEN 3
          ELSE 4
        END
    ''', [currentCompanyId]);
    return result;
  }

  // Employee Performance Reports
  Future<List<Map<String, dynamic>>> getEmployeePerformance() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        userId,
        userName,
        COUNT(*) as actionCount,
        action
      FROM audit_logs
      WHERE companyId = ? AND action = 'record_sale'
      GROUP BY userId, userName, action
      ORDER BY actionCount DESC
    ''', [currentCompanyId]);
    return result;
  }

  Future<List<Map<String, dynamic>>> getEmployeeActivity({int days = 7}) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days));

    final result = await db.rawQuery(
      '''
      SELECT 
        userId,
        userName,
        action,
        COUNT(*) as count,
        DATE(timestamp) as date
      FROM audit_logs
      WHERE companyId = ? AND timestamp >= ?
      GROUP BY userId, userName, action, DATE(timestamp)
      ORDER BY timestamp DESC
    ''',
      [currentCompanyId, startDate.toIso8601String()],
    );

    return result;
  }

  // Profit Analysis
  Future<Map<String, dynamic>> getProfitAnalysis({
    String? startDate,
    String? endDate,
  }) async {
    final db = await database;

    // Get total revenue from sales
    final totalRevenue = await getTotalSales(
      startDate: startDate,
      endDate: endDate,
    );

    // Get cost of goods sold (need to calculate from products at time of sale)
    // For now, we'll estimate using current product costs
    String query = '''
      SELECT 
        s.productId,
        p.costPrice,
        SUM(s.quantitySold) as totalSold
      FROM sales s
      LEFT JOIN products p ON s.productId = p.id
      WHERE s.companyId = ?
    ''';
    List<dynamic> args = [currentCompanyId];

    if (startDate != null && endDate != null) {
      query += ' AND s.saleDate >= ? AND s.saleDate <= ?';
      args.addAll([startDate, endDate]);
    }

    query += ' GROUP BY s.productId, p.costPrice';

    final result = await db.rawQuery(query, args);

    double totalCost = 0.0;
    for (var row in result) {
      final costPrice = (row['costPrice'] as num?)?.toDouble() ?? 0.0;
      final totalSold = (row['totalSold'] as num?)?.toInt() ?? 0;
      totalCost += costPrice * totalSold;
    }

    final grossProfit = totalRevenue - totalCost;
    final profitMargin = totalRevenue > 0
        ? (grossProfit / totalRevenue) * 100
        : 0.0;

    return {
      'totalRevenue': totalRevenue,
      'totalCost': totalCost,
      'grossProfit': grossProfit,
      'profitMargin': profitMargin,
    };
  }

  // ==================== STOCK ADJUSTMENT ====================

  /// Adjust stock for a product by a delta. Can be positive (delivery) or negative (correction).
  /// Returns the updated product. Throws if result would go below 0.
  Future<Product> adjustStock(int productId, int quantityDelta, String reason) async {
    final product = await readProduct(productId);
    if (product == null) throw Exception('Product not found');

    final newQuantity = product.quantity + quantityDelta;
    if (newQuantity < 0) throw Exception('Stock cannot go below zero');

    final updated = product.copyWith(
      quantity: newQuantity,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await updateProduct(updated);
    return updated;
  }

  // ==================== BATCH SALE (Multi-Cart) ====================

  /// Process a batch sale: create sale records for each cart item, decrement stock.
  /// All-or-nothing via database transaction.
  Future<List<Sale>> createBatchSale(List<Map<String, dynamic>> cartItems, User currentUser) async {
    final db = await database;
    final sales = <Sale>[];

    await db.transaction((txn) async {
      for (final item in cartItems) {
        final productId = item['productId'] as int;
        final quantity = item['quantity'] as int;
        final productName = item['productName'] as String;
        final unitPrice = item['unitPrice'] as double;
        final totalAmount = unitPrice * quantity;

        // Create sale record
        final sale = Sale(
          companyId: currentCompanyId,
          productId: productId,
          productName: productName,
          quantitySold: quantity,
          unitPrice: unitPrice,
          totalAmount: totalAmount,
          saleDate: DateTime.now().toIso8601String(),
        );
        final saleId = await txn.insert('sales', sale.toMap());
        sales.add(sale.copyWith(id: saleId));

        // Decrement stock
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity - ?, updatedAt = ? WHERE id = ?',
          [quantity, DateTime.now().toIso8601String(), productId],
        );
      }
    });

    // Push each sale + log after transaction succeeds
    for (final sale in sales) {
      SyncService.instance.pushSale(sale);
    }

    // Log audit for the batch
    if (currentUser.id != null) {
      final itemSummary = cartItems.map((i) => '${i['quantity']}x ${i['productName']}').join(', ');
      final total = sales.fold<double>(0, (sum, s) => sum + s.totalAmount);
      await logAction(AuditLog(
        companyId: currentCompanyId,
        userId: currentUser.id!,
        userName: currentUser.fullName,
        action: 'record_sale',
        details: 'Batch sale: $itemSummary - \$${total.toStringAsFixed(2)}',
        timestamp: DateTime.now().toIso8601String(),
      ));
    }

    SyncService.instance.notifyLocal(SyncTable.products);
    SyncService.instance.notifyLocal(SyncTable.sales);

    return sales;
  }

  // ==================== ORDER METHODS ====================

  Future<app_order.Order> createOrder(app_order.Order order, List<OrderItem> items) async {
    final db = await database;
    late int orderId;

    await db.transaction((txn) async {
      orderId = await txn.insert('orders', order.toMap());
      for (final item in items) {
        final itemWithOrderId = OrderItem(
          orderId: orderId,
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          lineTotal: item.lineTotal,
        );
        await txn.insert('order_items', itemWithOrderId.toMap());
      }
    });

    final created = order.copyWith(id: orderId);
    return created;
  }

  Future<List<app_order.Order>> getOrders({String? status}) async {
    final db = await database;
    String where = 'companyId = ?';
    List<dynamic> args = [currentCompanyId];
    if (status != null) {
      where += ' AND status = ?';
      args.add(status);
    }
    final result = await db.query(
      'orders',
      where: where,
      whereArgs: args,
      orderBy: 'createdAt DESC',
    );
    return result.map((m) => app_order.Order.fromMap(m)).toList();
  }

  Future<app_order.Order?> getOrderById(int id) async {
    final db = await database;
    final maps = await db.query('orders', where: 'id = ? AND companyId = ?', whereArgs: [id, currentCompanyId]);
    if (maps.isEmpty) return null;
    return app_order.Order.fromMap(maps.first);
  }

  Future<List<OrderItem>> getOrderItems(int orderId) async {
    final db = await database;
    final result = await db.query('order_items', where: 'orderId = ?', whereArgs: [orderId]);
    return result.map((m) => OrderItem.fromMap(m)).toList();
  }

  Future<void> updateOrderStatus(int orderId, String newStatus) async {
    final db = await database;
    await db.update(
      'orders',
      {'status': newStatus, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<List<app_order.Order>> getOrdersByCustomer(String phone) async {
    final db = await database;
    final result = await db.query(
      'orders',
      where: 'companyId = ? AND customerPhone LIKE ?',
      whereArgs: [currentCompanyId, '%$phone%'],
      orderBy: 'createdAt DESC',
    );
    return result.map((m) => app_order.Order.fromMap(m)).toList();
  }

  Future<int> getOrderCount({String? status}) async {
    final db = await database;
    String query = 'SELECT COUNT(*) as count FROM orders WHERE companyId = ?';
    List<dynamic> args = [currentCompanyId];
    if (status != null) {
      query += ' AND status = ?';
      args.add(status);
    }
    final result = await db.rawQuery(query, args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---- Sync Queue -----------------------------------------------------------
  Future<void> addToSyncQueue(String entityType, int entityId, String action) async {
    final db = await database;
    await db.insert('sync_queue', {
      'companyId': currentCompanyId,
      'entityType': entityType,
      'entityId': entityId,
      'action': action,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await database;
    return db.query('sync_queue', where: 'companyId = ?', whereArgs: [currentCompanyId], orderBy: 'id ASC');
  }

  Future<void> removeSyncQueueItem(int id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getSyncQueueCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM sync_queue WHERE companyId = ?', [currentCompanyId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Returns today's revenue, transaction count, gross profit and margin.
  Future<Map<String, dynamic>> getTodaySummary() async {
    final now = DateTime.now();
    final startDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T00:00:00.000';
    final endDate   = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T23:59:59.999';
    final revenue = await getTotalSales(startDate: startDate, endDate: endDate);
    final count   = await getTotalSalesCount(startDate: startDate, endDate: endDate);
    final profit  = await getProfitAnalysis(startDate: startDate, endDate: endDate);
    return {
      'revenue': revenue,
      'count': count,
      'profit': profit['grossProfit'] as double,
      'margin': profit['profitMargin'] as double,
    };
  }

  // Close database
  Future close() async {
    final db = await database;
    db.close();
  }
}
