class Product {
  final int? id;
  final String name;
  final String category;
  final int quantity;
  final int minQuantity;
  final double costPrice;
  final double sellingPrice;
  final String supplier;
  final String? barcode;
  final String? imagePath;
  final String createdAt;
  final String updatedAt;

  Product({
    this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.minQuantity,
    required this.costPrice,
    required this.sellingPrice,
    required this.supplier,
    this.barcode,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert Product to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'quantity': quantity,
      'minQuantity': minQuantity,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'supplier': supplier,
      'barcode': barcode,
      'imagePath': imagePath,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Create Product from Map (from database)
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      quantity: map['quantity'],
      minQuantity: map['minQuantity'],
      costPrice: map['costPrice'],
      sellingPrice: map['sellingPrice'],
      supplier: map['supplier'],
      barcode: map['barcode'],
      imagePath: map['imagePath'],
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }

  // Create a copy of Product with some fields updated
  Product copyWith({
    int? id,
    String? name,
    String? category,
    int? quantity,
    int? minQuantity,
    double? costPrice,
    double? sellingPrice,
    String? supplier,
    String? barcode,
    String? imagePath,
    String? createdAt,
    String? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      minQuantity: minQuantity ?? this.minQuantity,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      supplier: supplier ?? this.supplier,
      barcode: barcode ?? this.barcode,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Check if product is low on stock
  bool get isLowStock => quantity <= minQuantity && quantity > 0;

  // Check if product is out of stock
  bool get isOutOfStock => quantity == 0;

  // Calculate potential profit per unit
  double get profitPerUnit => sellingPrice - costPrice;

  // Calculate total value of stock
  double get totalStockValue => quantity * costPrice;
}