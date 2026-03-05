class User {
  final int? id;
  final String companyId; // Added for multi-tenancy
  final String pin;
  final String fullName;
  final String role; // 'manager' or 'staff'
  final String? phone;
  final int isActive; // 1 = active, 0 = deactivated
  final String createdAt;
  final int? createdBy; // ID of manager who created this user
  final String? lastLogin;

  User({
    this.id,
    required this.companyId,
    required this.pin,
    required this.fullName,
    required this.role,
    this.phone,
    this.isActive = 1,
    required this.createdAt,
    this.createdBy,
    this.lastLogin,
  });

  // Convert User to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'pin': pin,
      'fullName': fullName,
      'role': role,
      'phone': phone,
      'isActive': isActive,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'lastLogin': lastLogin,
    };
  }

  // Create User from Map (from database)
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      companyId: map['companyId'] ?? '',
      pin: map['pin'],
      fullName: map['fullName'],
      role: map['role'],
      phone: map['phone'],
      isActive: map['isActive'],
      createdAt: map['createdAt'],
      createdBy: map['createdBy'],
      lastLogin: map['lastLogin'],
    );
  }

  // Create a copy with some fields updated
  User copyWith({
    int? id,
    String? companyId,
    String? pin,
    String? fullName,
    String? role,
    String? phone,
    int? isActive,
    String? createdAt,
    int? createdBy,
    String? lastLogin,
  }) {
    return User(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      pin: pin ?? this.pin,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  // Helper methods
  bool get isManager => role == 'manager';
  bool get isStaff => role == 'staff';
  bool get isActiveUser => isActive == 1;
}