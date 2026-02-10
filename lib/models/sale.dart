class Sale {
  final int? id;
  final int productId;
  final String productName;
  final int quantitySold;
  final double unitPrice;
  final double totalAmount;
  final String saleDate;
  final String? notes;

  Sale({
    this.id,
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.unitPrice,
    required this.totalAmount,
    required this.saleDate,
    this.notes,
  });

  Sale copyWith({
    int? id,
    int? productId,
    String? productName,
    int? quantitySold,
    double? unitPrice,
    double? totalAmount,
    String? saleDate,
    String? notes,
  }) {
    return Sale(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantitySold: quantitySold ?? this.quantitySold,
      unitPrice: unitPrice ?? this.unitPrice,
      totalAmount: totalAmount ?? this.totalAmount,
      saleDate: saleDate ?? this.saleDate,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'quantitySold': quantitySold,
      'unitPrice': unitPrice,
      'totalAmount': totalAmount,
      'saleDate': saleDate,
      'notes': notes,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as int?,
      productId: map['productId'] as int,
      productName: map['productName'] as String,
      quantitySold: map['quantitySold'] as int,
      unitPrice: (map['unitPrice'] as num).toDouble(),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      saleDate: map['saleDate'] as String,
      notes: map['notes'] as String?,
    );
  }

  @override
  String toString() {
    return 'Sale(id: $id, productName: $productName, quantitySold: $quantitySold, totalAmount: $totalAmount, saleDate: $saleDate)';
  }
}