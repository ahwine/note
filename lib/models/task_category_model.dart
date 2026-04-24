class TaskCategoryModel {
  final String id;
  final String name;
  final String userId;
  final int order;
  final DateTime createdAt;

  const TaskCategoryModel({
    required this.id,
    required this.name,
    required this.userId,
    required this.order,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'userId': userId,
      'order': order,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TaskCategoryModel.fromMap(Map map) {
    return TaskCategoryModel(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Misc',
      userId: map['userId'] ?? '',
      order: map['order'] ?? 0,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  TaskCategoryModel copyWith({
    String? id,
    String? name,
    String? userId,
    int? order,
    DateTime? createdAt,
  }) {
    return TaskCategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
