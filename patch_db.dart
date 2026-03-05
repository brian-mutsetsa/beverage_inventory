import 'dart:io';

void main() async {
  final file = File('lib/database/database_helper.dart');
  String content = await file.readAsString();

  // 1. Add currentCompanyId to DatabaseHelper class
  content = content.replaceFirst('  static Database? _database;', '  static Database? _database;\n\n  String currentCompanyId = \'\';');

  // 2. Change version to 3
  content = content.replaceFirst('version: 2, // UPGRADED FROM 1 TO 2', 'version: 3, // UPGRADED FROM 2 TO 3');

  // 3. Add companyIdType
  content = content.replaceFirst('const realType = \'REAL NOT NULL\';', 'const realType = \'REAL NOT NULL\';\n    const companyIdType = \'TEXT NOT NULL\';');

  // 4. Add companyId column to tables in _createDB
  content = content.replaceAll(RegExp(r'id \$idType,'), 'id \$idType,\n      companyId \$companyIdType,');

  // 5. Upgrade logic
  final upgradeLogic = '''
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE products ADD COLUMN companyId TEXT DEFAULT ""');
      await db.execute('ALTER TABLE sales ADD COLUMN companyId TEXT DEFAULT ""');
      await db.execute('ALTER TABLE users ADD COLUMN companyId TEXT DEFAULT ""');
      await db.execute('ALTER TABLE audit_logs ADD COLUMN companyId TEXT DEFAULT ""');
    }
  }''';
  content = content.replaceFirst(RegExp(r'    }\n  }'), '    }\n$upgradeLogic');

  // Now the difficult part: patch the queries to include companyId
  // Instead of complex regex for all queries, we will just use basic regex where possible,
  // or leave some for manual patching if they break.
  
  // Actually, since there are many queries, let's write out the new versions of read all products etc.
  
  // readAllProducts
  content = content.replaceFirst(
    "final result = await db.query('products', orderBy: orderBy);",
    "final result = await db.query('products', where: 'companyId = ?', whereArgs: [currentCompanyId], orderBy: orderBy);"
  );
  
  // readProduct
  content = content.replaceFirst(
    "where: 'id = ?',\n      whereArgs: [id],",
    "where: 'id = ? AND companyId = ?',\n      whereArgs: [id, currentCompanyId],"
  );

  // updateProduct
  content = content.replaceFirst(
       "where: 'id = ?',\n      whereArgs: [product.id],",
       "where: 'id = ? AND companyId = ?',\n      whereArgs: [product.id, currentCompanyId],"
  );
  
  // deleteProduct
  content = content.replaceFirst(
       "where: 'id = ?',\n      whereArgs: [id],",
       "where: 'id = ? AND companyId = ?',\n      whereArgs: [id, currentCompanyId],"
  );
  
  // getProductCount
  content = content.replaceFirst(
    "await db.rawQuery('SELECT COUNT(*) as count FROM products');",
    "await db.rawQuery('SELECT COUNT(*) as count FROM products WHERE companyId = ?', [currentCompanyId]);"
  );
  
  // getTotalInventoryValue
  content = content.replaceFirst(
    "await db.rawQuery(\n      'SELECT SUM(quantity * sellingPrice) as total FROM products'\n    );",
    "await db.rawQuery(\n      'SELECT SUM(quantity * sellingPrice) as total FROM products WHERE companyId = ?', [currentCompanyId]\n    );"
  );
  
  // getLowStockProducts
  content = content.replaceFirst(
    "where: 'quantity <= minQuantity',\n      orderBy: 'quantity ASC',",
    "where: 'quantity <= minQuantity AND companyId = ?',\n      whereArgs: [currentCompanyId], orderBy: 'quantity ASC',"
  );
  
  // readAllSales
  content = content.replaceFirst(
    "final result = await db.query('sales', orderBy: orderBy);",
    "final result = await db.query('sales', where: 'companyId = ?', whereArgs: [currentCompanyId], orderBy: orderBy);"
  );
  
  // deleteSale
  content = content.replaceFirst(
      "where: 'id = ?',\n      whereArgs: [id],",
      "where: 'id = ? AND companyId = ?',\n      whereArgs: [id, currentCompanyId],"
  );
  
  // getUserByPin
  content = content.replaceFirst(
    "where: 'pin = ? AND isActive = 1',\n      whereArgs: [pin],",
    "where: 'pin = ? AND isActive = 1 AND companyId = ?',\n      whereArgs: [pin, currentCompanyId],"
  );
  
  // getManagerUser
  content = content.replaceFirst(
    "where: 'role = ?',\n      whereArgs: ['manager'],",
    "where: 'role = ? AND companyId = ?',\n      whereArgs: ['manager', currentCompanyId],"
  );
  
  // getAllUsers
  content = content.replaceFirst(
    "await db.query('users', orderBy: 'createdAt DESC');",
    "await db.query('users', where: 'companyId = ?', whereArgs: [currentCompanyId], orderBy: 'createdAt DESC');"
  );
  
  // updateUser
  content = content.replaceFirst(
    "where: 'id = ?',\n      whereArgs: [user.id],",
    "where: 'id = ? AND companyId = ?',\n      whereArgs: [user.id, currentCompanyId],"
  );
  
  // deactivateUser
  content = content.replaceFirst(
    "where: 'id = ?',\n      whereArgs: [userId],",
    "where: 'id = ? AND companyId = ?',\n      whereArgs: [userId, currentCompanyId],"
  );
  
  // reactivateUser
  content = content.replaceFirst(
    "where: 'id = ?',\n      whereArgs: [userId],",
    "where: 'id = ? AND companyId = ?',\n      whereArgs: [userId, currentCompanyId],"
  );
  
  // getAuditLogs
  content = content.replaceFirst(
    "orderBy: 'timestamp DESC',\n      limit: limit,",
    "where: 'companyId = ?', whereArgs: [currentCompanyId], orderBy: 'timestamp DESC',\n      limit: limit,"
  );
  
  // getAuditLogsByUser
  content = content.replaceFirst(
    "where: 'userId = ?',\n      whereArgs: [userId],",
    "where: 'userId = ? AND companyId = ?',\n      whereArgs: [userId, currentCompanyId],"
  );

  await file.writeAsString(content);
}
