class FolderModel {
  final String id;
  final String name;
  final String userId;
  final int colorIndex;
  final bool isLocked;
  final bool isSystem;
  final DateTime createdAt;

  FolderModel({
    required this.id,
    required this.name,
    required this.userId,
    this.colorIndex = 0,
    this.isLocked = false,
    this.isSystem = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'userId': userId,
      'colorIndex': colorIndex,
      'isLocked': isLocked,
      'isSystem': isSystem,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toLocalMap() => toMap();

  factory FolderModel.fromMap(Map<String, dynamic> map) {
    return FolderModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      userId: map['userId'] ?? '',
      colorIndex: map['colorIndex'] ?? 0,
      isLocked: map['isLocked'] ?? false,
      isSystem: map['isSystem'] ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  factory FolderModel.fromLocalMap(Map<dynamic, dynamic> map) {
    return FolderModel.fromMap(Map<String, dynamic>.from(map));
  }
}