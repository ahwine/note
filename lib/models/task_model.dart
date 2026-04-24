import 'package:cloud_firestore/cloud_firestore.dart';

const Object _taskReminderUnset = Object();
const Object _taskCompletedAtUnset = Object();

class TaskModel {
  final String id;
  final String title;
  final String userId;
  final bool isCompleted;
  final DateTime? reminderAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final String categoryId;
  final String categoryName;
  final int sortOrder;

  TaskModel({
    required this.id,
    required this.title,
    required this.userId,
    this.isCompleted = false,
    this.reminderAt,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.categoryId = 'misc',
    this.categoryName = 'Misc',
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'userId': userId,
      'isCompleted': isCompleted,
      'reminderAt': reminderAt != null ? Timestamp.fromDate(reminderAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'sortOrder': sortOrder,
    };
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'title': title,
      'userId': userId,
      'isCompleted': isCompleted,
      'reminderAt': reminderAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'categoryId': categoryId,
      'categoryName': categoryName,
      'sortOrder': sortOrder,
    };
  }

  factory TaskModel.fromMap(Map map) {
    return TaskModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      userId: map['userId'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      reminderAt: _readDate(map['reminderAt']),
      createdAt: _readDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _readDate(map['updatedAt']) ?? _readDate(map['createdAt']) ?? DateTime.now(),
      completedAt: _readDate(map['completedAt']),
      categoryId: map['categoryId'] ?? 'misc',
      categoryName: map['categoryName'] ?? 'Misc',
      sortOrder: (map['sortOrder'] ?? 0) is int
          ? map['sortOrder'] ?? 0
          : int.tryParse('${map['sortOrder']}') ?? 0,
    );
  }

  factory TaskModel.fromLocalMap(Map map) {
    return TaskModel.fromMap(Map.from(map));
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? userId,
    bool? isCompleted,
    Object? reminderAt = _taskReminderUnset,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? completedAt = _taskCompletedAtUnset,
    String? categoryId,
    String? categoryName,
    int? sortOrder,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      userId: userId ?? this.userId,
      isCompleted: isCompleted ?? this.isCompleted,
      reminderAt: identical(reminderAt, _taskReminderUnset)
          ? this.reminderAt
          : reminderAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: identical(completedAt, _taskCompletedAtUnset)
          ? this.completedAt
          : completedAt as DateTime?,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
