import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/note_model.dart';
import '../constants/app_colors.dart';

class NoteCard extends StatelessWidget {
  final NoteModel note;
  final String viewMode;
  final VoidCallback onTap;
  final VoidCallback? onMoreTap;

  const NoteCard({
    super.key,
    required this.note,
    required this.viewMode,
    required this.onTap,
    this.onMoreTap,
  });

  Color _cardColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (note.colorIndex == 0) {
      return isDark ? AppColors.bgDark2 : AppColors.bgLight2;
    }
    return AppColors.noteColors[note.colorIndex].withValues(alpha: 0.3);
  }

  String get _timeText {
    final now = DateTime.now();
    final diff = now.difference(note.updatedAt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return DateFormat('d MMM yyyy', 'id').format(note.updatedAt);
  }

  // Ambil teks preview — filter base64 dan embed
  String get _previewText {
    try {
      final content = note.content;
      if (content.isEmpty || content == '[]') return '';

      final decoded = jsonDecode(content) as List<dynamic>;
      final buffer = StringBuffer();

      for (final op in decoded) {
        if (op is Map) {
          final insert = op['insert'];
          if (insert is String) {
            // Teks biasa
            buffer.write(insert.replaceAll('\n', ' '));
          }
          // Skip embed (gambar, dll)
        }
      }

      final result = buffer.toString().trim();
      if (result.length > 80) return '${result.substring(0, 80)}...';
      return result;
    } catch (e) {
      return '';
    }
  }

  // Ambil URL gambar pertama dari konten quill
  String? get _firstImageUrl {
    try {
      final content = note.content;
      if (content.isEmpty || content == '[]') return null;

      final decoded = jsonDecode(content) as List<dynamic>;

      for (final op in decoded) {
        if (op is Map) {
          final insert = op['insert'];
          if (insert is Map) {
            final imageUrl = insert['image'] as String?;
            if (imageUrl != null && imageUrl.isNotEmpty) {
              return imageUrl;
            }
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Widget untuk tampilkan gambar (support base64 & network)
  Widget _buildCoverImage(String url, {double height = 120}) {
    if (url.startsWith('data:image')) {
      try {
        final base64Data = url.split(',').last;
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) =>
              _imagePlaceholder(height),
        );
      } catch (e) {
        return _imagePlaceholder(height);
      }
    } else {
      return Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) =>
            _imagePlaceholder(height),
      );
    }
  }

  Widget _imagePlaceholder(double height) {
    return Container(
      height: height,
      color: Colors.grey.shade300,
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (viewMode == 'grid') return _buildGridCard(context);
    if (viewMode == 'card') return _buildCardView(context);
    return _buildListView(context);
  }

  Widget _buildListView(BuildContext context) {
    final textColor = AppColors.text(context);
    final subColor = AppColors.textSecondary(context);
    final imageUrl = _firstImageUrl;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _cardColor(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image kalau ada
            if (imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
                child: _buildCoverImage(imageUrl, height: 100),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (note.isPinned)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.push_pin,
                                    size: 14,
                                    color: AppColors.primary),
                              ),
                            if (note.isLocked)
                              Padding(
                                padding:
                                    const EdgeInsets.only(right: 4),
                                child: Icon(Icons.lock_outline,
                                    size: 14, color: subColor),
                              ),
                            Expanded(
                              child: Text(
                                note.title.isEmpty
                                    ? 'Tanpa judul'
                                    : note.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (_previewText.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _previewText,
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: subColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          _timeText,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: subColor),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onMoreTap,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, top: 2),
                      child: Icon(Icons.more_vert,
                          size: 20, color: subColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardView(BuildContext context) {
    final textColor = AppColors.text(context);
    final subColor = AppColors.textSecondary(context);
    final imageUrl = note.coverImageUrl ?? _firstImageUrl;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _cardColor(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16)),
                child: _buildCoverImage(imageUrl, height: 140),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (note.isPinned)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.push_pin,
                                    size: 14,
                                    color: AppColors.primary),
                              ),
                            Expanded(
                              child: Text(
                                note.title.isEmpty
                                    ? 'Tanpa judul'
                                    : note.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (_previewText.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            _previewText,
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: subColor),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          _timeText,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: subColor),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onMoreTap,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.more_vert,
                          size: 20, color: subColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCard(BuildContext context) {
    final textColor = AppColors.text(context);
    final subColor = AppColors.textSecondary(context);
    final imageUrl = note.coverImageUrl ?? _firstImageUrl;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // penting! ikuti konten
          children: [
            if (imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
                child: _buildCoverImage(imageUrl, height: 100),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          note.title.isEmpty
                              ? 'Tanpa judul'
                              : note.title,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: onMoreTap,
                        child: Icon(Icons.more_vert,
                            size: 18, color: subColor),
                      ),
                    ],
                  ),
                  if (_previewText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _previewText,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: subColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    _timeText,
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: subColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}