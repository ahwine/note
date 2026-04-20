import 'package:cloud_firestore/cloud_firestore.dart';

const Object _taskReminderUnset = Object();

class TaskModel {
  final String id;
  final String title;
  final String userId;
  final bool isCompleted;
  final DateTime? reminderAt;
  final DateTime createdAt;

  TaskModel({
    required this.id,
    required this.title,
    required this.userId,
    this.isCompleted = false,
    this.reminderAt,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'userId': userId,
      'isCompleted': isCompleted,
      'reminderAt': reminderAt != null ? Timestamp.fromDate(reminderAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
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
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      userId: map['userId'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      reminderAt: _readDate(map['reminderAt']),
      createdAt: _readDate(map['createdAt']) ?? DateTime.now(),
    );
  }

  factory TaskModel.fromLocalMap(Map<dynamic, dynamic> map) {
    return TaskModel.fromMap(Map<String, dynamic>.from(map));
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? userId,
    bool? isCompleted,
    Object? reminderAt = _taskReminderUnset,
    DateTime? createdAt,
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