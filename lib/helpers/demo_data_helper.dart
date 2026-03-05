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

    // Create demo sales (NOW assigned to employees)
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

    for (var emp in employeeData) {
      final prefix = currentUser.pin.substring(0, 3);
      final pin = await _dbHelper.generateUniquePIN(prefix);
      final employee = User(
        companyId: DatabaseHelper.instance.currentCompanyId,
        pin: pin,
        fullName: emp['name']!,
        role: 'staff',
        phone: emp['phone']!,
        createdAt: DateTime.now().toIso8601String(),
        createdBy: currentUser.id,
      );
      final created = await _dbHelper.createUser(employee);
      createdEmployees.add(created);
    }

    return createdEmployees;
  }

  static Future<void> _createDemoProducts() async {
    final now = DateTime.now().toIso8601String();

    final products = [
      Product(
        companyId: DatabaseHelper.instance.currentCompanyId,
        name: 'Coca-Cola 500ml',
        category: 'Soft Drink',
        quantity: 50,
        minQuantity: 20,
        costPrice: 0.80,
        sellingPrice: 1.50,
        supplier: 'Coca-Cola Beverages Africa',
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        companyId: DatabaseHelper.instance.currentCompanyId,
        name: 'Pepsi 500ml',
        category: 'Soft Drink',
        quantity: 35,
        minQuantity: 20,
        costPrice: 0.75,
        sellingPrice: 1.45,
        supplier: 'PepsiCo Zimbabwe',
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        companyId: DatabaseHelper.instance.currentCompanyId,
        name: 'Fanta Orange 500ml',
        category: 'Soft Drink',
        quantity: 15,
        minQuantity: 15,
        costPrice: 0.70,
        sellingPrice: 1.40,
        supplier: 'Coca-Cola Beverages Africa',
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        companyId: DatabaseHelper.instance.currentCompanyId,
        name: 'Sprite 500ml',
        category: 'Soft Drink',
        quantity: 8,
        minQuantity: 15,
        costPrice: 0.70,
        sellingPrice: 1.40,
        supplier: 'Coca-Cola Beverages Africa',
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        companyId: DatabaseHelper.instance.currentCompanyId,
        name: 'Mazoe Orange 2L',
        category: 'Juice Concentrate',
        quantity: 25,
        minQuantity: 10,
        costPrice: 2.50,
        sellingPrice: 4.00,
        supplier: 'Schweppes Zimbabwe',
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        companyId: DatabaseHelper.instance.currentCompanyId,
        name: 'Ceres Apple Juice 1L',
        category: 'Juice',
        quantity: 12,
        minQuantity: 10,
        costPrice: 1.80,
        sellingPrice: 3.00,
        supplier: 'Ceres Fruit Juices',
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        companyId: DatabaseHelper.instance.currentCompanyId,
        name: 'Schweppes Tonic 500ml',
        category: 'Mixer',
        quantity: 20,
        minQuantity: 10,
        costPrice: 0.90,
        sellingPrice: 1.60,
        supplier: 'Schweppes Zimbabwe',
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        companyId: DatabaseHelper.instance.currentCompanyId,
        name: 'Minute Maid Orange 500ml',
        category: 'Juice',
        quantity: 30,
        minQuantity: 15,
        costPrice: 1.20,
        sellingPrice: 2.00,
        supplier: 'Coca-Cola Beverages Africa',
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        companyId: DatabaseHelper.instance.currentCompanyId,
        name: 'Aquafresh Water 500ml',
        category: 'Water',
        quantity: 100,
        minQuantity: 50,
        costPrice: 0.30,
        sellingPrice: 0.80,
        supplier: 'Delta Beverages',
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        companyId: DatabaseHelper.instance.currentCompanyId,
        name: 'Mountain Dew 500ml',
        category: 'Soft Drink',
        quantity: 5,
        minQuantity: 15,
        costPrice: 0.75,
        sellingPrice: 1.45,
        supplier: 'PepsiCo Zimbabwe',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    for (var product in products) {
      await _dbHelper.createProduct(product);
    }
  }

  static Future<void> _createDemoSales(
    User currentUser,
    List<User> demoEmployees,
  ) async {
    final products = await _dbHelper.readAllProducts();
    if (products.isEmpty) return;

    final random = Random();
    final now = DateTime.now();

    // Create a list of all users who can record sales (manager + employees)
    final allSalesUsers = [currentUser, ...demoEmployees];

    final salesData = [
      // Day 1 (7 days ago)
      {'productIndex': 0, 'quantity': 10, 'daysAgo': 7},
      {'productIndex': 1, 'quantity': 5, 'daysAgo': 7},
      {'productIndex': 8, 'quantity': 20, 'daysAgo': 7},

      // Day 2 (6 days ago)
      {'productIndex': 0, 'quantity': 8, 'daysAgo': 6},
      {'productIndex': 4, 'quantity': 3, 'daysAgo': 6},
      {'productIndex': 7, 'quantity': 6, 'daysAgo': 6},

      // Day 3 (5 days ago)
      {'productIndex': 2, 'quantity': 12, 'daysAgo': 5},
      {'productIndex': 5, 'quantity': 4, 'daysAgo': 5},
      {'productIndex': 8, 'quantity': 15, 'daysAgo': 5},

      // Day 4 (4 days ago)
      {'productIndex': 0, 'quantity': 15, 'daysAgo': 4},
      {'productIndex': 1, 'quantity': 8, 'daysAgo': 4},
      {'productIndex': 6, 'quantity': 5, 'daysAgo': 4},

      // Day 5 (3 days ago)
      {'productIndex': 3, 'quantity': 10, 'daysAgo': 3},
      {'productIndex': 4, 'quantity': 5, 'daysAgo': 3},
      {'productIndex': 7, 'quantity': 8, 'daysAgo': 3},

      // Day 6 (2 days ago)
      {'productIndex': 0, 'quantity': 12, 'daysAgo': 2},
      {'productIndex': 2, 'quantity': 7, 'daysAgo': 2},
      {'productIndex': 8, 'quantity': 25, 'daysAgo': 2},

      // Day 7 (Yesterday)
      {'productIndex': 1, 'quantity': 10, 'daysAgo': 1},
      {'productIndex': 5, 'quantity': 6, 'daysAgo': 1},
      {'productIndex': 9, 'quantity': 8, 'daysAgo': 1},

      // Today
      {'productIndex': 0, 'quantity': 5, 'daysAgo': 0},
      {'productIndex': 4, 'quantity': 2, 'daysAgo': 0},
      {'productIndex': 8, 'quantity': 10, 'daysAgo': 0},
    ];

    for (var saleData in salesData) {
      final productIndex = saleData['productIndex'] as int;
      final quantity = saleData['quantity'] as int;
      final daysAgo = saleData['daysAgo'] as int;

      if (productIndex >= products.length) continue;

      final product = products[productIndex];
      final saleDate = now.subtract(Duration(days: daysAgo));

      // Randomly assign sale to one of the users
      final assignedUser = allSalesUsers[random.nextInt(allSalesUsers.length)];

      final sale = Sale(
        companyId: DatabaseHelper.instance.currentCompanyId,
        productId: product.id!,
        productName: product.name,
        quantitySold: quantity,
        unitPrice: product.sellingPrice,
        totalAmount: product.sellingPrice * quantity,
        saleDate: saleDate.toIso8601String(),
        notes: daysAgo == 0
            ? 'Demo sale - Today'
            : 'Demo sale - $daysAgo days ago',
      );

      await _dbHelper.createSale(sale);

      // Log the action with the assigned user
      await _dbHelper.logAction(
        AuditLog(
          companyId: DatabaseHelper.instance.currentCompanyId,
          userId: assignedUser.id!,
          userName: assignedUser.fullName,
          action: 'record_sale',
          details:
              'Sold ${quantity}x ${product.name} - \$${sale.totalAmount.toStringAsFixed(2)}',
          timestamp: saleDate.toIso8601String(),
        ),
      );
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
