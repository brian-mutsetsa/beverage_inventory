class AuditLog {
  final int? id;
  final int userId;
  final String userName;
  final String action; // 'add_product', 'record_sale', 'edit_product', etc.
  final String? details; // JSON string with action details
  final String timestamp;

  AuditLog({
    this.id,
    required this.userId,
    required this.userName,
    required this.action,
    this.details,
    required this.timestamp,
  });

  // Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'action': action,
      'details': details,
      'timestamp': timestamp,
    };
  }

  // Create from Map (from database)
  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'],
      userId: map['userId'],
      userName: map['userName'],
      action: map['action'],
      details: map['details'],
      timestamp: map['timestamp'],
    );
  }
}