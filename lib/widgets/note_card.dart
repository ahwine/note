import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_colors.dart';
import '../models/note_model.dart';

class NoteCard extends StatelessWidget {
  final NoteModel note;
  final String viewMode;
  final VoidCallback onTap;
  final VoidCallback? onMoreTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool selectionMode;

  const NoteCard({
    super.key,
    required this.note,
    required this.viewMode,
    required this.onTap,
    this.onMoreTap,
    this.onLongPress,
    this.selected = false,
    this.selectionMode = false,
  });

  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive: false,
  );

  static final RegExp _audioRegex = RegExp(
    r'((https?:\/\/|file:\/\/|\/)\S+\.(m4a|mp3|wav|aac|ogg|opus|amr))',
    caseSensitive: false,
  );

  Color _cardColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (note.colorIndex == 0) {
      return isDark ? AppColors.bgDark2 : AppColors.bgLight2;
    }
    return AppColors.noteColors[note.colorIndex].withValues(alpha: 0.24);
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

  _ParsedContent get _parsed {
    final raw = note.content.trim();
    String previewText = '';
    String? imageUrl = note.coverImageUrl;
    String? drawingUrl;
    String? voiceUrl;
    String? linkUrl;
    int? voiceDurationSeconds;

    if (raw.isEmpty || raw == '[]') {
      return _ParsedContent(
        previewText: '',
        imageUrl: imageUrl,
        drawingUrl: drawingUrl,
        voiceUrl: voiceUrl,
        linkUrl: linkUrl,
        voiceDurationSeconds: voiceDurationSeconds,
      );
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final buffer = StringBuffer();
        for (final op in decoded) {
          if (op is! Map) continue;
          final insert = op['insert'];
          final attrs = op['attributes'];

          if (insert is String) {
            buffer.write('${insert.replaceAll('\n', ' ')} ');
            linkUrl ??= _urlRegex.firstMatch(insert)?.group(0);
            voiceUrl ??= _audioRegex.firstMatch(insert)?.group(0);
          } else if (insert is Map) {
            final img = insert['image'];
            final draw = insert['drawing'];
            if (imageUrl == null && img is String && img.isNotEmpty) imageUrl = img;
            if (drawingUrl == null && draw is String && draw.isNotEmpty) drawingUrl = draw;

            final voiceCandidates = [
              insert['audio'],
              insert['voice'],
              insert['recording'],
              insert['sound'],
              insert['voiceNote'],
              insert['audioUrl'],
              insert['voiceUrl'],
              insert['notes-audio'],
              insert['file'],
              insert['src'],
              insert['path'],
            ];
            if (voiceUrl == null) {
              for (final candidate in voiceCandidates) {
                if (candidate is String && candidate.isNotEmpty) {
                  final lc = candidate.toLowerCase();
                  if (lc.endsWith('.m4a') ||
                      lc.endsWith('.mp3') ||
                      lc.endsWith('.wav') ||
                      lc.endsWith('.aac') ||
                      lc.endsWith('.ogg') ||
                      lc.endsWith('.opus') ||
                      lc.endsWith('.amr')) {
                    voiceUrl = candidate;
                    break;
                  }
                }
              }
            }

            if (voiceDurationSeconds == null) {
              for (final candidate in [
                insert['duration'],
                insert['audioDuration'],
                insert['voiceDuration'],
                insert['length'],
              ]) {
                if (candidate is int) {
                  voiceDurationSeconds = candidate;
                  break;
                }
                if (candidate is String) {
                  final parsed = int.tryParse(candidate);
                  if (parsed != null) {
                    voiceDurationSeconds = parsed;
                    break;
                  }
                }
              }
            }

            linkUrl ??= _stringCandidate([
              insert['link'],
              insert['url'],
              insert['href'],
            ]);
          }

          if (attrs is Map && linkUrl == null) {
            linkUrl = _stringCandidate([
              attrs['link'],
              attrs['href'],
              attrs['url'],
            ]);
          }
        }
        previewText = buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
      }
    } catch (_) {
      previewText = raw;
      linkUrl = _urlRegex.firstMatch(raw)?.group(0);
      voiceUrl = _audioRegex.firstMatch(raw)?.group(0);
    }

    if (linkUrl != null && linkUrl!.isNotEmpty) {
      previewText = previewText.replaceAll(linkUrl!, '').trim();
      previewText = previewText.replaceAll(_urlRegex, '').trim();
    }
    if (voiceUrl != null && voiceUrl!.isNotEmpty) {
      previewText = previewText.replaceAll(voiceUrl!, '').trim();
    }

    previewText = previewText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (previewText.length > 160) {
      previewText = '${previewText.substring(0, 160)}...';
    }

    return _ParsedContent(
      previewText: previewText,
      imageUrl: imageUrl,
      drawingUrl: drawingUrl,
      voiceUrl: voiceUrl,
      linkUrl: linkUrl,
      voiceDurationSeconds: voiceDurationSeconds,
    );
  }

  String? _stringCandidate(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  Uint8List? _tryDecodeImageFromDataUri(String value) {
    if (!value.startsWith('data:image')) return null;
    try {
      return base64Decode(value.split(',').last);
    } catch (_) {
      return null;
    }
  }

  Widget _imagePlaceholder() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 100),
      color: Colors.grey.shade300,
      child: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Icon(Icons.image_not_supported_outlined, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildFlexibleImage(String url) {
    final bytes = _tryDecodeImageFromDataUri(url);
    if (bytes != null) {
      return Image.memory(
        bytes,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );
    }
    return Image.network(
      url,
      width: double.infinity,
      fit: BoxFit.fitWidth,
      alignment: Alignment.topCenter,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 100),
          alignment: Alignment.center,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _imagePlaceholder(),
    );
  }

  Widget _buildTopPreview(BuildContext context) {
    final parsed = _parsed;
    if (parsed.imageUrl != null && parsed.imageUrl!.isNotEmpty) {
      return _buildFlexibleImage(parsed.imageUrl!);
    }
    if (parsed.drawingUrl != null && parsed.drawingUrl!.isNotEmpty) {
      return _buildFlexibleImage(parsed.drawingUrl!);
    }
    if (parsed.linkUrl != null && parsed.linkUrl!.isNotEmpty) {
      return _SmartLinkPreview(url: parsed.linkUrl!, enabled: !selectionMode);
    }
    if (parsed.voiceUrl != null && parsed.voiceUrl!.isNotEmpty) {
      return _VoicePreviewStrip(
        voiceUrl: parsed.voiceUrl!,
        durationSeconds: parsed.voiceDurationSeconds,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildHeaderRow(
    BuildContext context, {
    required Color textColor,
    required Color subColor,
    required double titleSize,
    required FontWeight titleWeight,
    int titleMaxLines = 2,
    double lockIconSize = 14,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (note.isPinned)
          const Padding(
            padding: EdgeInsets.only(right: 4, top: 1),
            child: Icon(Icons.push_pin, size: 14, color: AppColors.primary),
          ),
        if (note.isLocked)
          Padding(
            padding: const EdgeInsets.only(right: 4, top: 1),
            child: Icon(Icons.lock_outline, size: lockIconSize, color: subColor),
          ),
        Expanded(
          child: Text(
            note.title.isEmpty ? 'Tanpa judul' : note.title,
            style: GoogleFonts.poppins(
              fontSize: titleSize,
              fontWeight: titleWeight,
              color: textColor,
            ),
            maxLines: titleMaxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!selectionMode && onMoreTap != null)
          GestureDetector(
            onTap: onMoreTap,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, top: 1),
              child: Icon(Icons.more_vert, size: 19, color: subColor),
            ),
          ),
      ],
    );
  }

  Widget _wrapCard(BuildContext context, Widget child) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _cardColor(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Colors.white.withValues(alpha: 0.05),
            width: selected ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            child,
            if (selected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 16, color: Colors.black),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    final textColor = AppColors.text(context);
    final subColor = AppColors.textSecondary(context);

    final cardContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopPreview(context),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderRow(
                context,
                textColor: textColor,
                subColor: subColor,
                titleSize: viewMode == 'grid' ? 13 : 14,
                titleWeight: FontWeight.w600,
                titleMaxLines: 2,
                lockIconSize: 13,
              ),
              if (parsed.previewText.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  parsed.previewText,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: subColor,
                    height: 1.4,
                  ),
                  maxLines: viewMode == 'grid' ? 5 : 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _timeText,
                style: GoogleFonts.poppins(fontSize: 10.5, color: subColor),
              ),
            ],
          ),
        ),
      ],
    );

    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: selected ? 0.985 : 1,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: selected ? 0.96 : 1,
        child: _wrapCard(context, cardContent),
      ),
    );
  }
}

class _ParsedContent {
  final String previewText;
  final String? imageUrl;
  final String? drawingUrl;
  final String? voiceUrl;
  final String? linkUrl;
  final int? voiceDurationSeconds;

  const _ParsedContent({
    required this.previewText,
    this.imageUrl,
    this.drawingUrl,
    this.voiceUrl,
    this.linkUrl,
    this.voiceDurationSeconds,
  });
}

class _SmartLinkPreview extends StatefulWidget {
  final String url;
  final bool enabled;

  const _SmartLinkPreview({
    required this.url,
    this.enabled = true,
  });

  @override
  State<_SmartLinkPreview> createState() => _SmartLinkPreviewState();
}

class _SmartLinkPreviewState extends State<_SmartLinkPreview> {
  LinkPreviewData? _data;
  bool _loading = true;

  bool get _isYoutube {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host.contains('youtube.com') || host.contains('youtu.be');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (_isYoutube) {
        await _loadYoutube();
      } else {
        await _loadWebsite();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _data = LinkPreviewData.fallback(widget.url);
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadYoutube() async {
    final encoded = Uri.encodeComponent(widget.url);
    final uri = Uri.parse(
      'https://www.youtube.com/oembed?url=$encoded&format=json',
    );

    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final title = (json['title'] ?? '').toString().trim();
      final thumb = (json['thumbnail_url'] ?? '').toString().trim();
      if (!mounted) return;
      setState(() {
        _data = LinkPreviewData(
          title: title.isEmpty ? 'YouTube' : title,
          subtitle: _hostLabel(widget.url),
          imageUrl: thumb.isEmpty ? _youtubeThumb(widget.url) : thumb,
          isYoutube: true,
          url: widget.url,
        );
        _loading = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _data = LinkPreviewData(
        title: 'YouTube',
        subtitle: _hostLabel(widget.url),
        imageUrl: _youtubeThumb(widget.url),
        isYoutube: true,
        url: widget.url,
      );
      _loading = false;
    });
  }

  Future<void> _loadWebsite() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) {
      if (!mounted) return;
      setState(() {
        _data = LinkPreviewData.fallback(widget.url);
        _loading = false;
      });
      return;
    }

    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    String title = '';
    if (res.statusCode == 200) {
      final match = RegExp(
        r'<title[^>]*>(.*?)<\/title>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(res.body);
      if (match != null) {
        title = match.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
      }
    }

    if (!mounted) return;
    setState(() {
      _data = LinkPreviewData(
        title: title.isEmpty ? _hostLabel(widget.url) : title,
        subtitle: _hostLabel(widget.url),
        imageUrl: null,
        isYoutube: false,
        url: widget.url,
      );
      _loading = false;
    });
  }

  static String _hostLabel(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return 'Link';
    var host = uri.host.toLowerCase();
    if (host.startsWith('www.')) host = host.substring(4);
    return host;
  }

  static String? _youtubeThumb(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    String? videoId;
    if (uri.host.contains('youtu.be')) {
      if (uri.pathSegments.isNotEmpty) videoId = uri.pathSegments.first;
    } else {
      videoId = uri.queryParameters['v'];
    }
    if (videoId == null || videoId.isEmpty) return null;
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }

  Future<void> _openUrl() async {
    if (!widget.enabled) return;
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final subColor = AppColors.textSecondary(context);
    if (_loading && _data == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final data = _data ?? LinkPreviewData.fallback(widget.url);

    final preview = data.isYoutube
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.imageUrl != null && data.imageUrl!.isNotEmpty)
                Image.network(
                  data.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: const Icon(Icons.video_library_outlined),
                  ),
                ),
              _LinkMetaBar(
                iconBuilder: (_) => Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
                ),
                title: data.title,
                subtitle: data.subtitle,
                subColor: subColor,
                enabled: widget.enabled,
                onOpen: _openUrl,
              ),
            ],
          )
        : _LinkMetaBar(
            iconBuilder: (_) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                'https://www.google.com/s2/favicons?sz=64&domain_url=${widget.url}',
                width: 24,
                height: 24,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 24,
                  height: 24,
                  child: Icon(Icons.public, size: 18),
                ),
              ),
            ),
            title: data.title,
            subtitle: data.subtitle,
            subColor: subColor,
            enabled: widget.enabled,
            onOpen: _openUrl,
          );

    if (!widget.enabled) {
      return Opacity(opacity: 0.72, child: preview);
    }
    return InkWell(onTap: _openUrl, child: preview);
  }
}

class _LinkMetaBar extends StatelessWidget {
  final WidgetBuilder iconBuilder;
  final String title;
  final String subtitle;
  final Color subColor;
  final bool enabled;
  final VoidCallback onOpen;

  const _LinkMetaBar({
    required this.iconBuilder,
    required this.title,
    required this.subtitle,
    required this.subColor,
    required this.enabled,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.08)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconBuilder(context),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text(context),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(fontSize: 11, color: subColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (enabled)
            InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.open_in_new, size: 18, color: subColor),
              ),
            ),
        ],
      ),
    );
  }
}

class LinkPreviewData {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final bool isYoutube;
  final String url;

  LinkPreviewData({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.isYoutube,
    required this.url,
  });

  factory LinkPreviewData.fallback(String url) {
    final uri = Uri.tryParse(url);
    var host = uri?.host ?? 'Link';
    if (host.startsWith('www.')) host = host.substring(4);
    return LinkPreviewData(
      title: host,
      subtitle: host,
      imageUrl: null,
      isYoutube: false,
      url: url,
    );
  }
}

class _VoicePreviewStrip extends StatelessWidget {
  final String voiceUrl;
  final int? durationSeconds;

  const _VoicePreviewStrip({
    required this.voiceUrl,
    this.durationSeconds,
  });

  String _formatDuration(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = durationSeconds ?? 48;
    final fileName = voiceUrl.split('/').last.split('?').first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7C3F66), Color(0xFF8B4F73)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mic_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Voice note',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                _formatDuration(total),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _MiniWaveform(),
          const SizedBox(height: 6),
          Text(
            fileName.isEmpty ? 'audio' : fileName,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.88),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MiniWaveform extends StatelessWidget {
  const _MiniWaveform();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: CustomPaint(
        painter: _WavePainter(),
        size: const Size(double.infinity, 16),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final midY = size.height / 2;
    path.moveTo(0, midY);
    for (double x = 0; x <= size.width; x += 6) {
      final y = midY + math.sin(x / 8) * 3.2;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, line);

    final progress = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(0, 1), Offset(size.width, 1), progress);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
