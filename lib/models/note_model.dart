import 'package:cloud_firestore/cloud_firestore.dart';

class NoteModel {
  final String id;
  final String title;
  final String content;
  final String folderId;
  final String userId;
  final int colorIndex;
  final bool isPinned;
  final bool isLocked;
  final String? coverImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? reminderAt;
  final bool isDeleted;
  final String type;

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.folderId,
    required this.userId,
    this.colorIndex = 0,
    this.isPinned = false,
    this.isLocked = false,
    this.coverImageUrl,
    required this.createdAt,
    required this.updatedAt,
    this.reminderAt,
    this.isDeleted = false,
    this.type = 'note',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'folderId': folderId,
      'userId': userId,
      'colorIndex': colorIndex,
      'isPinned': isPinned,
      'isLocked': isLocked,
      'coverImageUrl': coverImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'reminderAt': reminderAt != null ? Timestamp.fromDate(reminderAt!) : null,
      'isDeleted': isDeleted,
      'type': type,
    };
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'folderId': folderId,
      'userId': userId,
      'colorIndex': colorIndex,
      'isPinned': isPinned,
      'isLocked': isLocked,
      'coverImageUrl': coverImageUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'reminderAt': reminderAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'type': type,
    };
  }

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '[]',
      folderId: map['folderId'] ?? 'all',
      userId: map['userId'] ?? '',
      colorIndex: map['colorIndex'] ?? 0,
      isPinned: map['isPinned'] ?? false,
      isLocked: map['isLocked'] ?? false,
      coverImageUrl: map['coverImageUrl'],
      createdAt: _readDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _readDate(map['updatedAt']) ?? DateTime.now(),
      reminderAt: _readDate(map['reminderAt']),
      isDeleted: map['isDeleted'] ?? false,
      type: map['type'] ?? 'note',
    );
  }

  factory NoteModel.fromLocalMap(Map<dynamic, dynamic> map) {
    return NoteModel.fromMap(Map<String, dynamic>.from(map));
  }

  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    String? folderId,
    String? userId,
    int? colorIndex,
    bool? isPinned,
    bool? isLocked,
    String? coverImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? reminderAt,
    bool? isDeleted,
    String? type,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      folderId: folderId ?? this.folderId,
      userId: userId ?? this.userId,
      colorIndex: colorIndex ?? this.colorIndex,
      isPinned: isPinned ?? this.isPinned,
      isLocked: isLocked ?? this.isLocked,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reminderAt: reminderAt ?? this.reminderAt,
      isDeleted: isDeleted ?? this.isDeleted,
      type: type ?? this.type,
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