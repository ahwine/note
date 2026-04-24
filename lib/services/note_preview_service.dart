import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

import '../models/note_model.dart';
import '../models/note_preview.dart';

class NotePreviewService {
  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive: false,
  );

  static final Map<String, NotePreview> _cache = {};

  static Future<NotePreview> build(NoteModel note) async {
    final cacheKey = '${note.id}_${note.updatedAt.millisecondsSinceEpoch}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final preview = await _buildInternal(note);
    _cache[cacheKey] = preview;
    return preview;
  }

  static Future<NotePreview> _buildInternal(NoteModel note) async {
    final plainText = _extractPlainText(note);

    if ((note.coverImageUrl ?? '').isNotEmpty) {
      return NotePreview(
        type: NotePreviewType.image,
        imageUrl: note.coverImageUrl,
        title: note.title.trim().isEmpty ? 'Catatan baru' : note.title,
        subtitle: plainText,
      );
    }

    final deltaImage = _extractFirstImage(note);
    if (deltaImage != null && deltaImage.isNotEmpty) {
      return NotePreview(
        type: NotePreviewType.image,
        imageUrl: deltaImage,
        title: note.title.trim().isEmpty ? 'Catatan baru' : note.title,
        subtitle: plainText,
      );
    }

    final firstUrl = _extractFirstUrl(note);
    if (firstUrl != null) {
      final ytThumb = _youtubeThumbnail(firstUrl);
      final uri = Uri.tryParse(firstUrl);
      if (ytThumb != null) {
        return NotePreview(
          type: NotePreviewType.link,
          imageUrl: ytThumb,
          title: note.title.trim().isEmpty ? 'Link tersimpan' : note.title,
          subtitle: plainText,
          url: firstUrl,
          domain: uri?.host,
        );
      }

      return NotePreview(
        type: NotePreviewType.link,
        title: note.title.trim().isEmpty ? 'Link tersimpan' : note.title,
        subtitle: plainText,
        url: firstUrl,
        domain: uri?.host,
      );
    }

    return NotePreview(
      type: NotePreviewType.text,
      title: note.title.trim().isEmpty ? 'Catatan baru' : note.title,
      subtitle: plainText,
    );
  }

  static String _extractPlainText(NoteModel note) {
    try {
      final raw = jsonDecode(note.content);
      final doc = Document.fromJson((raw as List).cast<Map<String, dynamic>>());
      return doc.toPlainText().trim();
    } catch (_) {
      return note.content.trim();
    }
  }

  static String? _extractFirstImage(NoteModel note) {
    try {
      final raw = jsonDecode(note.content);
      final doc = Document.fromJson((raw as List).cast<Map<String, dynamic>>());
      final delta = doc.toDelta();
      for (final op in delta.toList()) {
        final data = op.data;
        if (data is Map && data['image'] != null) {
          return data['image'].toString();
        }
      }
    } catch (_) {}
    return null;
  }

  static String? _extractFirstUrl(NoteModel note) {
    final allText = '${note.title}\n${_extractPlainText(note)}';
    final match = _urlRegex.firstMatch(allText);
    return match?.group(0);
  }

  static String? _youtubeThumbnail(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    String? videoId;
    if (uri.host.contains('youtu.be')) {
      if (uri.pathSegments.isNotEmpty) {
        videoId = uri.pathSegments.first;
      }
    } else if (uri.host.contains('youtube.com')) {
      videoId = uri.queryParameters['v'];
    }

    if (videoId == null || videoId.isEmpty) return null;
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }
}
