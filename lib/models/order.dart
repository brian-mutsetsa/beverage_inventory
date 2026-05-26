class Order {
  final int? id;
  final String companyId;
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String status; // pending, processing, completed, delivered, cancelled
  final double totalAmount;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final int createdBy;

  Order({
    this.id,
    required this.companyId,
    required this.customerName,
    this.customerPhone,
    this.customerAddress,
    required this.status,
    required this.totalAmount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'status': status,
      'totalAmount': totalAmount,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] as int?,
      companyId: map['companyId'] ?? '',
      customerName: map['customerName'] as String,
      customerPhone: map['customerPhone'] as String?,
      customerAddress: map['customerAddress'] as String?,
      status: map['status'] as String,
      totalAmount: (map['totalAmount'] as num).toDouble(),
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String,
      createdBy: map['createdBy'] as int,
    );
  }

  Order copyWith({
    int? id,
    String? companyId,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? status,
    double? totalAmount,
    String? notes,
    String? createdAt,
    String? updatedAt,
    int? createdBy,
  }) {
    return Order(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
