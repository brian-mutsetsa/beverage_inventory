import 'dart:io';

void main() async {
  final files = [
    'lib/helpers/demo_data_helper.dart',
    'lib/screens/add_product_screen.dart',
    'lib/screens/inventory_screen.dart',
    'lib/screens/sales_screen.dart',
    'lib/screens/setup_screen.dart',
    'lib/screens/user_management_screen.dart'
  ];

  for (var path in files) {
    final file = File(path);
    if (!file.existsSync()) continue;
    
    var content = await file.readAsString();
    
    // Replace 'Product(' but not 'Product.fromMap('
    content = content.replaceAll(RegExp(r'Product\(\s*id:'), 'Product(\ncompanyId: DatabaseHelper.instance.currentCompanyId,\nid:');
    content = content.replaceAll(RegExp(r'Product\(\s*name:'), 'Product(\ncompanyId: DatabaseHelper.instance.currentCompanyId,\nname:');
    
    // Replace 'Sale('
    content = content.replaceAll(RegExp(r'Sale\(\s*productId:'), 'Sale(\ncompanyId: DatabaseHelper.instance.currentCompanyId,\nproductId:');
    
    // Replace 'User('
    content = content.replaceAll(RegExp(r'User\(\s*pin:'), 'User(\ncompanyId: DatabaseHelper.instance.currentCompanyId,\npin:');
    content = content.replaceAll(RegExp(r'User\(\s*fullName:'), 'User(\ncompanyId: DatabaseHelper.instance.currentCompanyId,\nfullName:');

    // Replace 'AuditLog('
    content = content.replaceAll(RegExp(r'AuditLog\(\s*userId:'), 'AuditLog(\ncompanyId: DatabaseHelper.instance.currentCompanyId,\nuserId:');

    // Add import to add_product_screen.dart if missing
    if (!content.contains("import '../database/database_helper.dart';") && 
        !content.contains("import 'package:beverage_inventory/database/database_helper.dart';")) {
      content = "import '../database/database_helper.dart';\n" + content;
    }

    await file.writeAsString(content);
  }
}
