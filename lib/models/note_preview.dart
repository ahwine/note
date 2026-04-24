enum NotePreviewType { image, link, text }

class NotePreview {
  final NotePreviewType type;
  final String? imageUrl;
  final String title;
  final String subtitle;
  final String? url;
  final String? domain;

  const NotePreview({
    required this.type,
    this.imageUrl,
    required this.title,
    required this.subtitle,
    this.url,
    this.domain,
  });
}
