import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/user.dart';
import '../models/audit_log.dart';
import 'dart:math';

class DemoDataHelper {
  static final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  static Future<void> loadDemoData(User currentUser) async {
    // Create demo employees first
    final demoEmployees = await _createDemoEmployees(currentUser);

    // Create demo products
    await _createDemoProducts();

    // Create 30+ days of demo sales for AI/ML training
    await _createDemoSales(currentUser, demoEmployees);
  }

  static Future<List<User>> _createDemoEmployees(User currentUser) async {
    final employeeData = [
      {'name': 'Alice Johnson', 'phone': '+263 77 123 4567'},
      {'name': 'Bob Martinez', 'phone': '+263 77 234 5678'},
      {'name': 'Carol Chen', 'phone': '+263 77 345 6789'},
      {'name': 'David Kumar', 'phone': '+263 77 456 7890'},
      {'name': 'Emma Wilson', 'phone': '+263 77 567 8901'},
    ];

    List<User> createdEmployees = [];

    // Derive prefix from company name instead of hashed PIN
    final company = await _dbHelper.getCompany(DatabaseHelper.instance.currentCompanyId);
    String prefix = (company?.name ?? 'AUR').replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
    if (prefix.length < 3) {
      prefix = prefix.padRight(3, 'X');
    } else {
      prefix = prefix.substring(0, 3);
    }

    for (var emp in employeeData) {
      final pin = await _dbHelper.generateUniquePIN(prefix);
      final employee = User(
        companyId: DatabaseHelper.instance.currentCompanyId,
        pin: pin,
        fullName: emp['name']!,
        role: 'staff',
        phone: emp['phone']!,
        createdAt: DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        createdBy: currentUser.id,
      );
      final created = await _dbHelper.createUser(employee);
      createdEmployees.add(created);
    }

    return createdEmployees;
  }

  static Future<void> _createDemoProducts() async {
    final companyId = DatabaseHelper.instance.currentCompanyId;
    final createdAt = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    final now = DateTime.now().toIso8601String();

    final products = [
      Product(companyId: companyId, name: 'Coca-Cola 500ml', category: 'Soft Drink', quantity: 48, minQuantity: 20, costPrice: 0.80, sellingPrice: 1.50, supplier: 'Coca-Cola Beverages Africa', createdAt: createdAt, updatedAt: now),
      Product(companyId: companyId, name: 'Pepsi 500ml', category: 'Soft Drink', quantity: 32, minQuantity: 20, costPrice: 0.75, sellingPrice: 1.45, supplier: 'PepsiCo Zimbabwe', createdAt: createdAt, updatedAt: now),
      Product(companyId: companyId, name: 'Fanta Orange 500ml', category: 'Soft Drink', quantity: 14, minQuantity: 15, costPrice: 0.70, sellingPrice: 1.40, supplier: 'Coca-Cola Beverages Africa', createdAt: createdAt, updatedAt: now),
      Product(companyId: companyId, name: 'Sprite 500ml', category: 'Soft Drink', quantity: 7, minQuantity: 15, costPrice: 0.70, sellingPrice: 1.40, supplier: 'Coca-Cola Beverages Africa', createdAt: createdAt, updatedAt: now),
      Product(companyId: companyId, name: 'Mazoe Orange 2L', category: 'Juice Concentrate', quantity: 22, minQuantity: 10, costPrice: 2.50, sellingPrice: 4.00, supplier: 'Schweppes Zimbabwe', createdAt: createdAt, updatedAt: now),
      Product(companyId: companyId, name: 'Ceres Apple Juice 1L', category: 'Juice', quantity: 10, minQuantity: 10, costPrice: 1.80, sellingPrice: 3.00, supplier: 'Ceres Fruit Juices', createdAt: createdAt, updatedAt: now),
      Product(companyId: companyId, name: 'Schweppes Tonic 500ml', category: 'Mixer', quantity: 18, minQuantity: 10, costPrice: 0.90, sellingPrice: 1.60, supplier: 'Schweppes Zimbabwe', createdAt: createdAt, updatedAt: now),
      Product(companyId: companyId, name: 'Minute Maid Orange 500ml', category: 'Juice', quantity: 26, minQuantity: 15, costPrice: 1.20, sellingPrice: 2.00, supplier: 'Coca-Cola Beverages Africa', createdAt: createdAt, updatedAt: now),
      Product(companyId: companyId, name: 'Aquafresh Water 500ml', category: 'Water', quantity: 85, minQuantity: 50, costPrice: 0.30, sellingPrice: 0.80, supplier: 'Delta Beverages', createdAt: createdAt, updatedAt: now),
      Product(companyId: companyId, name: 'Mountain Dew 500ml', category: 'Soft Drink', quantity: 4, minQuantity: 15, costPrice: 0.75, sellingPrice: 1.45, supplier: 'PepsiCo Zimbabwe', createdAt: createdAt, updatedAt: now),
    ];

    for (var product in products) {
      await _dbHelper.createProduct(product);
    }
  }

  /// Generates 30 days of realistic sales data with patterns:
  /// - Weekends (Fri-Sat) have higher sales volume
  /// - Mondays are slowest
  /// - Coca-Cola and Water are top sellers
  /// - Gradual upward trend to show growth
  /// - Random noise for realism
  static Future<void> _createDemoSales(
    User currentUser,
    List<User> demoEmployees,
  ) async {
    final products = await _dbHelper.readAllProducts();
    if (products.isEmpty) return;

    final random = Random(42); // Fixed seed for reproducible but realistic data
    final now = DateTime.now();
    final companyId = DatabaseHelper.instance.currentCompanyId;
    final allSalesUsers = [currentUser, ...demoEmployees];

    // Base daily sales volume per product index (0-9)
    // Coca-Cola(0) and Water(8) are top sellers
    final baseDailySales = [12, 7, 6, 5, 4, 3, 4, 5, 18, 3];

    // Day-of-week multipliers (0=Mon..6=Sun)
    // Friday and Saturday are peak days, Monday is slow
    final dayMultipliers = [0.6, 0.8, 0.9, 1.0, 1.2, 1.5, 1.3];

    // Generate sales for each of the past 30 days
    for (int daysAgo = 30; daysAgo >= 0; daysAgo--) {
      final saleDate = now.subtract(Duration(days: daysAgo));
      final weekday = saleDate.weekday - 1; // 0=Mon, 6=Sun
      final dayMult = dayMultipliers[weekday];

      // Slight upward trend: 0.85 at day 30, 1.15 at day 0
      final trendMult = 0.85 + (30 - daysAgo) * 0.01;

      // Each day, 4–7 products sell (not every product every day)
      final productCount = products.length;
      final productsToSell = <int>{};

      // Always sell the popular ones (Coca-Cola, Water)
      productsToSell.add(0); // Coca-Cola
      productsToSell.add(8); // Water

      // Randomly add 3-5 more products
      final extraProducts = 3 + random.nextInt(3);
      while (productsToSell.length < extraProducts + 2 && productsToSell.length < productCount) {
        productsToSell.add(random.nextInt(productCount));
      }

      for (final pIdx in productsToSell) {
        if (pIdx >= products.length) continue;
        final product = products[pIdx];

        // Calculate quantity with noise
        final baseQty = pIdx < baseDailySales.length
            ? baseDailySales[pIdx]
            : 3 + random.nextInt(8); // random base 3-10 for products beyond index 9
        final noise = 0.7 + random.nextDouble() * 0.6; // 0.7 to 1.3
        int qty = (baseQty * dayMult * trendMult * noise).round();
        if (qty < 1) qty = 1;
        if (qty > 30) qty = 30;

        // Sometimes split into 2 transactions (morning + afternoon)
        final splitSale = random.nextDouble() > 0.6;
        final quantities = splitSale
            ? [qty ~/ 2, qty - qty ~/ 2]
            : [qty];

        for (final q in quantities) {
          if (q < 1) continue;

          // Random time of day (8am to 6pm)
          final hour = 8 + random.nextInt(10);
          final minute = random.nextInt(60);
          final saleDateTime = DateTime(
            saleDate.year, saleDate.month, saleDate.day, hour, minute,
          );

          final assignedUser = allSalesUsers[random.nextInt(allSalesUsers.length)];

          final sale = Sale(
            companyId: companyId,
            productId: product.id!,
            productName: product.name,
            quantitySold: q,
            unitPrice: product.sellingPrice,
            totalAmount: product.sellingPrice * q,
            saleDate: saleDateTime.toIso8601String(),
            notes: daysAgo == 0 ? 'Today' : null,
          );

          await _dbHelper.createSale(sale);

          await _dbHelper.logAction(
            AuditLog(
              companyId: companyId,
              userId: assignedUser.id!,
              userName: assignedUser.fullName,
              action: 'record_sale',
              details: 'Sold ${q}x ${product.name} - \$${sale.totalAmount.toStringAsFixed(2)}',
              timestamp: saleDateTime.toIso8601String(),
            ),
          );
        }
      }
    }
  }

  static Future<bool> hasDemoData() async {
    // Check if demo data already exists
    final products = await _dbHelper.readAllProducts();
    final users = await _dbHelper.getAllUsers();

    // If there are products or more than 1 user (the manager), demo data exists
    return products.isNotEmpty || users.length > 1;
  }

  static Future<void> clearAllData() async {
    // This would delete all products, sales, and non-manager users
    // Useful for resetting demo data
    final products = await _dbHelper.readAllProducts();
    for (var product in products) {
      await _dbHelper.deleteProduct(product.id!);
    }

    final sales = await _dbHelper.readAllSales();
    for (var sale in sales) {
      if (sale.id != null) {
        await _dbHelper.deleteSale(sale.id!);
      }
    }

    final users = await _dbHelper.getAllUsers();
    for (var user in users) {
      if (user.role == 'staff') {
        await _dbHelper.deactivateUser(user.id!);
      }
    }
  }
}
