import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:docs_gee/docs_gee.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/note_model.dart';

class ExportService {
  static const String _audioEmbedKey = 'notes-audio';

  static List<_ExportBlock> _parseBlocks(String quillJson) {
    try {
      if (quillJson.trim().isEmpty || quillJson.trim() == '[]') {
        return [];
      }

      final json = jsonDecode(quillJson) as List<dynamic>;
      final blocks = <_ExportBlock>[];
      final textBuffer = StringBuffer();

      void flushText() {
        final text = textBuffer.toString();
        if (text.trim().isNotEmpty) {
          blocks.add(_ExportBlock.text(text.trimRight()));
        }
        textBuffer.clear();
      }

      for (final item in json) {
        if (item is! Map<String, dynamic>) continue;

        final insert = item['insert'];

        if (insert is String) {
          textBuffer.write(insert);
          continue;
        }

        if (insert is Map<String, dynamic>) {
          flushText();

          if (insert.containsKey('image')) {
            final imageValue = insert['image'];
            if (imageValue is String && imageValue.trim().isNotEmpty) {
              blocks.add(_ExportBlock.image(imageValue));
            }
            continue;
          }

          if (insert.containsKey(_audioEmbedKey)) {
            blocks.add(_ExportBlock.text('[Voice Note]'));
            continue;
          }

          blocks.add(_ExportBlock.text('[Lampiran]'));
        }
      }

      flushText();
      return blocks;
    } catch (_) {
      try {
        final json = jsonDecode(quillJson) as List<dynamic>;
        final doc = quill.Document.fromJson(json);
        final text = doc.toPlainText().trim();
        if (text.isEmpty) return [];
        return [_ExportBlock.text(text)];
      } catch (_) {
        return [];
      }
    }
  }

  static String extractPlainText(String quillJson) {
    final blocks = _parseBlocks(quillJson);
    if (blocks.isEmpty) return '';

    final parts = <String>[];

    for (final block in blocks) {
      switch (block.type) {
        case _ExportBlockType.text:
          final text = block.text?.trim() ?? '';
          if (text.isNotEmpty) {
            parts.add(text);
          }
          break;
        case _ExportBlockType.image:
          parts.add('[Gambar]');
          break;
      }
    }

    return parts.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  static String buildShareText(NoteModel note) {
    final title = note.title.trim();
    final content = extractPlainText(note.content).trim();

    if (title.isEmpty && content.isEmpty) {
      return 'Catatan kosong';
    }

    if (title.isNotEmpty && content.isNotEmpty) {
      return '$title\n\n$content';
    }

    return title.isNotEmpty ? title : content;
  }

  static Future<void> shareAsText(NoteModel note) async {
    final text = buildShareText(note);
    await Share.share(
      text,
      subject: note.title.trim().isEmpty ? 'Catatan' : note.title.trim(),
    );
  }

  static Future<File> exportPdf(NoteModel note) async {
    final pdf = pw.Document();

    final title = note.title.trim().isEmpty ? 'Tanpa Judul' : note.title.trim();
    final blocks = _parseBlocks(note.content);

    final contentWidgets = <pw.Widget>[];

    if (blocks.isEmpty) {
      contentWidgets.add(
        pw.Text(
          'Catatan kosong',
          style: const pw.TextStyle(fontSize: 12),
        ),
      );
    } else {
      for (final block in blocks) {
        if (block.type == _ExportBlockType.text) {
          final text = block.text?.trim() ?? '';
          if (text.isNotEmpty) {
            contentWidgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  text,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
            );
          }
        } else if (block.type == _ExportBlockType.image) {
          final bytes = await _loadImageBytes(block.imageSource!);

          if (bytes != null) {
            contentWidgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 14),
                child: pw.Center(
                  child: pw.Container(
                    constraints: const pw.BoxConstraints(
                      maxWidth: 480,
                      maxHeight: 320,
                    ),
                    child: pw.Image(
                      pw.MemoryImage(bytes),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
              ),
            );
          } else {
            contentWidgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  '[Gambar]',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
            );
          }
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 16),
          ...contentWidgets,
        ],
      ),
    );

    final directory = await getTemporaryDirectory();
    final safeTitle = _sanitizeFileName(title);
    final file = File('${directory.path}/$safeTitle.pdf');
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }

  static Future<void> sharePdf(NoteModel note) async {
    final file = await exportPdf(note);
    await Share.shareXFiles(
      [XFile(file.path)],
      text:
          'Export PDF: ${note.title.trim().isEmpty ? 'Catatan' : note.title.trim()}',
      subject: note.title.trim().isEmpty ? 'Catatan PDF' : note.title.trim(),
    );
  }

  static Future<File> exportWord(NoteModel note) async {
    final title = note.title.trim().isEmpty ? 'Tanpa Judul' : note.title.trim();
    final blocks = _parseBlocks(note.content);

    final doc = DocxDocument(
      title: title,
      author: 'Notes App',
    );

    doc.addParagraph(
      DocxParagraph.heading(
        title,
        level: 1,
        alignment: DocxAlignment.left,
      ),
    );

    doc.addParagraph(DocxParagraph.text(''));

    if (blocks.isEmpty) {
      doc.addParagraph(DocxParagraph.text('Catatan kosong'));
    } else {
      for (final block in blocks) {
        if (block.type == _ExportBlockType.text) {
          final text = block.text?.trim() ?? '';
          if (text.isEmpty) continue;

          final lines = text.split('\n');
          for (final line in lines) {
            if (line.trim().isEmpty) {
              doc.addParagraph(DocxParagraph.text(''));
            } else {
              doc.addParagraph(DocxParagraph.text(line.trim()));
            }
          }
        } else if (block.type == _ExportBlockType.image) {
          doc.addParagraph(DocxParagraph.text('[Gambar]'));
        }
      }
    }

    final generator = DocxGenerator(
      fontName: 'Arial',
      fontSize: 24,
    );

    final Uint8List bytes = generator.generate(doc);

    final directory = await getTemporaryDirectory();
    final safeTitle = _sanitizeFileName(title);
    final file = File('${directory.path}/$safeTitle.docx');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> shareWord(NoteModel note) async {
    final file = await exportWord(note);
    await Share.shareXFiles(
      [XFile(file.path)],
      text:
          'Export Word: ${note.title.trim().isEmpty ? 'Catatan' : note.title.trim()}',
      subject: note.title.trim().isEmpty ? 'Catatan Word' : note.title.trim(),
    );
  }

  static Future<Uint8List?> _loadImageBytes(String source) async {
    try {
      if (source.startsWith('data:image')) {
        final base64Data = source.split(',').last;
        return base64Decode(base64Data);
      }

      if (source.startsWith('http://') || source.startsWith('https://')) {
        final response = await http.get(Uri.parse(source));
        if (response.statusCode == 200) {
          return response.bodyBytes;
        }
        return null;
      }

      final file = File(source);
      if (await file.exists()) {
        return await file.readAsBytes();
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static String _sanitizeFileName(String input) {
    final sanitized = input.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    if (sanitized.isEmpty) return 'catatan';
    return sanitized;
  }
}

enum _ExportBlockType {
  text,
  image,
}

class _ExportBlock {
  final _ExportBlockType type;
  final String? text;
  final String? imageSource;

  const _ExportBlock._({
    required this.type,
    this.text,
    this.imageSource,
  });

  factory _ExportBlock.text(String text) {
    return _ExportBlock._(
      type: _ExportBlockType.text,
      text: text,
    );
  }

  factory _ExportBlock.image(String source) {
    return _ExportBlock._(
      type: _ExportBlockType.image,
      imageSource: source,
    );
  }
}