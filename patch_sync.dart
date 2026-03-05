import 'dart:io';

void main() async {
  final file = File('lib/database/database_helper.dart');
  String content = await file.readAsString();

  // 1. Add import
  if (!content.contains("import '../services/firebase_service.dart';")) {
    content = "import '../services/firebase_service.dart';\n" + content;
  }

  // 2. Patch createProduct
  content = content.replaceFirst(
    "final id = await db.insert('products', product.toMap());\n    return product.copyWith(id: id);",
    "final id = await db.insert('products', product.toMap());\n    final newProduct = product.copyWith(id: id);\n    FirebaseService.instance.syncProduct(newProduct);\n    return newProduct;"
  );

  // 3. Patch updateProduct
  content = content.replaceFirst(
    "return db.update(\n      'products',\n      product.toMap(),\n      where: 'id = ? AND companyId = ?',\n      whereArgs: [product.id, currentCompanyId],\n    );",
    "final result = await db.update(\n      'products',\n      product.toMap(),\n      where: 'id = ? AND companyId = ?',\n      whereArgs: [product.id, currentCompanyId],\n    );\n    FirebaseService.instance.syncProduct(product);\n    return result;"
  );

  // 4. Patch deleteProduct
  content = content.replaceFirst(
      "return await db.delete(\n      'products',\n      where: 'id = ? AND companyId = ?',\n      whereArgs: [id, currentCompanyId],\n    );",
      "final result = await db.delete(\n      'products',\n      where: 'id = ? AND companyId = ?',\n      whereArgs: [id, currentCompanyId],\n    );\n    FirebaseService.instance.deleteProductFromCloud(currentCompanyId, id);\n    return result;"
  );

  // 5. Patch createSale
  content = content.replaceFirst(
    "final id = await db.insert('sales', sale.toMap());\n    return sale.copyWith(id: id);",
    "final id = await db.insert('sales', sale.toMap());\n    final newSale = sale.copyWith(id: id);\n    FirebaseService.instance.syncSale(newSale);\n    return newSale;"
  );

  // 6. Patch deleteSale
  content = content.replaceFirst(
    "return await db.delete(\n      'sales',\n      where: 'id = ? AND companyId = ?',\n      whereArgs: [id, currentCompanyId],\n    );",
    "final result = await db.delete(\n      'sales',\n      where: 'id = ? AND companyId = ?',\n      whereArgs: [id, currentCompanyId],\n    );\n    FirebaseService.instance.deleteSaleFromCloud(currentCompanyId, id);\n    return result;"
  );

  // 7. Patch createUser
  content = content.replaceFirst(
    "final id = await db.insert('users', user.toMap());\n    return user.copyWith(id: id);",
    "final id = await db.insert('users', user.toMap());\n    final newUser = user.copyWith(id: id);\n    FirebaseService.instance.syncUser(newUser);\n    return newUser;"
  );

  // 8. Patch updateUser
  content = content.replaceFirst(
    "return db.update(\n      'users',\n      user.toMap(),\n      where: 'id = ? AND companyId = ?',\n      whereArgs: [user.id, currentCompanyId],\n    );",
    "final result = await db.update(\n      'users',\n      user.toMap(),\n      where: 'id = ? AND companyId = ?',\n      whereArgs: [user.id, currentCompanyId],\n    );\n    FirebaseService.instance.syncUser(user);\n    return result;"
  );

  await file.writeAsString(content);
}
