class Company {
  final int? id;
  final String companyId;
  final String name;
  final String createdBy;
  final String createdAt;

  Company({
    this.id,
    required this.companyId,
    required this.name,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'companyId': companyId,
      'name': name,
      'createdBy': createdBy,
      'createdAt': createdAt,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id'] as int?,
      companyId: map['companyId'] as String,
      name: map['name'] as String,
      createdBy: map['createdBy'] as String,
      createdAt: map['createdAt'] as String,
    );
  }

  Company copyWith({
    int? id,
    String? companyId,
    String? name,
    String? createdBy,
    String? createdAt,
  }) {
    return Company(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
