import 'package:cloud_firestore/cloud_firestore.dart';

const Object _noteCoverUnset = Object();
const Object _noteReminderUnset = Object();

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
  final bool isArchived;
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
    this.isArchived = false,
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
      'isArchived': isArchived,
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
      'isArchived': isArchived,
      'type': type,
    };
  }

  factory NoteModel.fromMap(Map map) {
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
      isArchived: map['isArchived'] ?? false,
      type: map['type'] ?? 'note',
    );
  }

  factory NoteModel.fromLocalMap(Map map) {
    return NoteModel.fromMap(Map.from(map));
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
    Object? coverImageUrl = _noteCoverUnset,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? reminderAt = _noteReminderUnset,
    bool? isDeleted,
    bool? isArchived,
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
      coverImageUrl: identical(coverImageUrl, _noteCoverUnset)
          ? this.coverImageUrl
          : coverImageUrl as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reminderAt: identical(reminderAt, _noteReminderUnset)
          ? this.reminderAt
          : reminderAt as DateTime?,
      isDeleted: isDeleted ?? this.isDeleted,
      isArchived: isArchived ?? this.isArchived,
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
