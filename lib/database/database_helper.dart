import 'dart:async';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/user.dart';
import '../models/audit_log.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

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
      version: 2, // UPGRADED FROM 1 TO 2
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';

    // Products table
    await db.execute('''
    CREATE TABLE products (
      id $idType,
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
      userId $intType,
      userName $textType,
      action $textType,
      details TEXT,
      timestamp $textType
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
  }

  // ==================== PRODUCT METHODS ====================

  Future<Product> createProduct(Product product) async {
    final db = await database;
    final id = await db.insert('products', product.toMap());
    return product.copyWith(id: id);
  }

  Future<Product?> readProduct(int id) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Product>> readAllProducts() async {
    final db = await database;
    const orderBy = 'name ASC';
    final result = await db.query('products', orderBy: orderBy);
    return result.map((map) => Product.fromMap(map)).toList();
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getProductCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM products');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<double> getTotalInventoryValue() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(quantity * sellingPrice) as total FROM products'
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Product>> getLowStockProducts() async {
    final db = await database;
    final result = await db.query(
      'products',
      where: 'quantity <= minQuantity',
      orderBy: 'quantity ASC',
    );
    return result.map((map) => Product.fromMap(map)).toList();
  }

  // ==================== SALE METHODS ====================

  Future<Sale> createSale(Sale sale) async {
    final db = await database;
    final id = await db.insert('sales', sale.toMap());
    return sale.copyWith(id: id);
  }

  Future<List<Sale>> readAllSales() async {
    final db = await database;
    const orderBy = 'saleDate DESC';
    final result = await db.query('sales', orderBy: orderBy);
    return result.map((map) => Sale.fromMap(map)).toList();
  }

  Future<int> deleteSale(int id) async {
    final db = await database;
    return await db.delete(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== USER METHODS ====================

  Future<User> createUser(User user) async {
    final db = await database;
    final id = await db.insert('users', user.toMap());
    return user.copyWith(id: id);
  }

  Future<User?> getUserByPin(String pin) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'pin = ? AND isActive = 1',
      whereArgs: [pin],
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
      where: 'role = ?',
      whereArgs: ['manager'],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final result = await db.query('users', orderBy: 'createdAt DESC');
    return result.map((map) => User.fromMap(map)).toList();
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
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

  Future<String> generateUniquePIN() async {
    final random = Random();
    String pin;
    bool isUnique = false;

    do {
      pin = '';
      for (int i = 0; i < 6; i++) {
        pin += random.nextInt(10).toString();
      }

      final existing = await getUserByPin(pin);
      isUnique = existing == null;
    } while (!isUnique);

    return pin;
  }

  // ==================== AUDIT LOG METHODS ====================

  Future<void> logAction(AuditLog log) async {
    final db = await database;
    await db.insert('audit_logs', log.toMap());
  }

  Future<List<AuditLog>> getAuditLogs({int? limit}) async {
    final db = await database;
    final result = await db.query(
      'audit_logs',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return result.map((map) => AuditLog.fromMap(map)).toList();
  }

  Future<List<AuditLog>> getAuditLogsByUser(int userId) async {
    final db = await database;
    final result = await db.query(
      'audit_logs',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => AuditLog.fromMap(map)).toList();
  }

  // ==================== REPORT METHODS ====================

  // Sales Reports
  Future<double> getTotalSales({String? startDate, String? endDate}) async {
    final db = await database;
    String query = 'SELECT SUM(totalAmount) as total FROM sales';
    List<dynamic> args = [];

    if (startDate != null && endDate != null) {
      query += ' WHERE saleDate >= ? AND saleDate <= ?';
      args = [startDate, endDate];
    } else if (startDate != null) {
      query += ' WHERE saleDate >= ?';
      args = [startDate];
    } else if (endDate != null) {
      query += ' WHERE saleDate <= ?';
      args = [endDate];
    }

    final result = await db.rawQuery(query, args);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> getTotalSalesCount({String? startDate, String? endDate}) async {
    final db = await database;
    String query = 'SELECT COUNT(*) as count FROM sales';
    List<dynamic> args = [];

    if (startDate != null && endDate != null) {
      query += ' WHERE saleDate >= ? AND saleDate <= ?';
      args = [startDate, endDate];
    }

    final result = await db.rawQuery(query, args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getSalesByProduct({String? startDate, String? endDate}) async {
    final db = await database;
    String query = '''
      SELECT 
        productName,
        SUM(quantitySold) as totalQuantity,
        SUM(totalAmount) as totalRevenue,
        COUNT(*) as transactionCount
      FROM sales
    ''';
    List<dynamic> args = [];

    if (startDate != null && endDate != null) {
      query += ' WHERE saleDate >= ? AND saleDate <= ?';
      args = [startDate, endDate];
    }

    query += ' GROUP BY productName ORDER BY totalRevenue DESC';

    final result = await db.rawQuery(query, args);
    return result;
  }

  Future<List<Map<String, dynamic>>> getDailySales({int days = 7}) async {
    final db = await database;
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));

    final result = await db.rawQuery('''
      SELECT 
        DATE(saleDate) as date,
        SUM(totalAmount) as total,
        COUNT(*) as count
      FROM sales
      WHERE saleDate >= ? AND saleDate <= ?
      GROUP BY DATE(saleDate)
      ORDER BY date ASC
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

    return result;
  }

  // Inventory Reports
  Future<Map<String, dynamic>> getInventoryStats() async {
    final db = await database;
    
    final totalProducts = await getProductCount();
    final totalValue = await getTotalInventoryValue();
    final lowStockCount = (await getLowStockProducts()).length;
    
    final costResult = await db.rawQuery(
      'SELECT SUM(quantity * costPrice) as totalCost FROM products'
    );
    final totalCost = (costResult.first['totalCost'] as num?)?.toDouble() ?? 0.0;

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
      GROUP BY category
      ORDER BY totalValue DESC
    ''');
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
      WHERE action = 'record_sale'
      GROUP BY userId, userName, action
      ORDER BY actionCount DESC
    ''');
    return result;
  }

  Future<List<Map<String, dynamic>>> getEmployeeActivity({int days = 7}) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days));

    final result = await db.rawQuery('''
      SELECT 
        userId,
        userName,
        action,
        COUNT(*) as count,
        DATE(timestamp) as date
      FROM audit_logs
      WHERE timestamp >= ?
      GROUP BY userId, userName, action, DATE(timestamp)
      ORDER BY timestamp DESC
    ''', [startDate.toIso8601String()]);

    return result;
  }

  // Profit Analysis
  Future<Map<String, dynamic>> getProfitAnalysis({String? startDate, String? endDate}) async {
    final db = await database;
    
    // Get total revenue from sales
    final totalRevenue = await getTotalSales(startDate: startDate, endDate: endDate);
    
    // Get cost of goods sold (need to calculate from products at time of sale)
    // For now, we'll estimate using current product costs
    String query = '''
      SELECT 
        s.productId,
        p.costPrice,
        SUM(s.quantitySold) as totalSold
      FROM sales s
      LEFT JOIN products p ON s.productId = p.id
    ''';
    List<dynamic> args = [];

    if (startDate != null && endDate != null) {
      query += ' WHERE s.saleDate >= ? AND s.saleDate <= ?';
      args = [startDate, endDate];
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
    final profitMargin = totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0.0;

    return {
      'totalRevenue': totalRevenue,
      'totalCost': totalCost,
      'grossProfit': grossProfit,
      'profitMargin': profitMargin,
    };
  }

  // Close database
  Future close() async {
    final db = await database;
    db.close();
  }
}