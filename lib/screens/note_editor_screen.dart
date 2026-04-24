import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../constants/app_colors.dart';
import '../models/note_model.dart';
import '../providers/note_provider.dart';
import '../providers/theme_provider.dart';
import '../services/export_service.dart';
import '../services/security_service.dart';
import '../widgets/rich_toolbar.dart';
import 'drawing_screen.dart';

class NoteEditorScreen extends StatefulWidget {
  final NoteModel note;
  final bool isNew;

  const NoteEditorScreen({
    super.key,
    required this.note,
    this.isNew = false,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  static const String _audioEmbedKey = 'notes-audio';

  late QuillController _quillController;
  late TextEditingController _titleController;
  late FocusNode _editorFocusNode;
  late FocusNode _titleFocusNode;
  late ScrollController _scrollController;
  late int _colorIndex;
  late bool _isLocked;

  bool _isSaving = false;
  bool _hasChanges = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _colorIndex = widget.note.colorIndex;
    _isLocked = widget.note.isLocked;
    _titleController = TextEditingController(text: widget.note.title);
    _editorFocusNode = FocusNode();
    _titleFocusNode = FocusNode();

    try {
      final content = widget.note.content;
      if (content.isEmpty || content == '[]') {
        _quillController = QuillController.basic();
      } else {
        final json = jsonDecode(content) as List<dynamic>;
        final doc = Document.fromJson(json);
        _quillController = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } catch (_) {
      _quillController = QuillController.basic();
    }

    _quillController.addListener(_onContentChanged);
    _titleController.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _quillController.removeListener(_onContentChanged);
    _quillController.dispose();
    _titleController.dispose();
    _editorFocusNode.dispose();
    _titleFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Color _getTextColorForBg(BuildContext context) {
    if (_colorIndex == 0) return AppColors.text(context);
    final bg = AppColors.noteColors[_colorIndex];
    final luminance = bg.computeLuminance();
    return luminance > 0.3 ? Colors.black : Colors.white;
  }

  NoteModel _buildCurrentNoteForExport() {
    final title = _titleController.text.trim();
    final contentJson =
        jsonEncode(_quillController.document.toDelta().toJson());

    return widget.note.copyWith(
      title: title,
      content: contentJson,
      colorIndex: _colorIndex,
      isLocked: _isLocked,
    );
  }

  bool _documentHasEmbeds() {
    final delta = _quillController.document.toDelta();
    for (final op in delta.toList()) {
      if (op.data is Map) return true;
    }
    return false;
  }

  bool _noteHasMeaningfulContent() {
    final title = _titleController.text.trim();
    final plainText = _quillController.document.toPlainText().trim();
    return title.isNotEmpty || plainText.isNotEmpty || _documentHasEmbeds();
  }

  Future<void> _saveAndPop() async {
    if (_saved) return;
    _saved = true;

    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;

    setState(() => _isSaving = true);

    try {
      final contentJson = jsonEncode(_quillController.document.toDelta().toJson());

      if (widget.isNew &&
          !_noteHasMeaningfulContent() &&
          _colorIndex == 0 &&
          !_isLocked) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      final updated = widget.note.copyWith(
        title: _titleController.text.trim(),
        content: contentJson,
        colorIndex: _colorIndex,
        isLocked: _isLocked,
      );

      await context.read<NoteProvider>().saveNote(updated);
    } catch (e) {
      debugPrint('Save error: $e');
      _saved = false;
      if (mounted) {
        setState(() => _isSaving = false);
      }
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleBack() async {
    final title = _titleController.text.trim();
    final plainText = _quillController.document.toPlainText().trim();
    final hasEmbed = _documentHasEmbeds();

    if (widget.isNew &&
        title.isEmpty &&
        plainText.isEmpty &&
        !hasEmbed &&
        _colorIndex == 0 &&
        !_hasChanges &&
        !_isLocked) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (!_hasChanges &&
        _colorIndex == widget.note.colorIndex &&
        _isLocked == widget.note.isLocked) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bg2(context),
        title: Text(
          'Simpan catatan?',
          style: GoogleFonts.poppins(
            color: AppColors.text(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Catatan ini belum disimpan.',
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary(context),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(
              'Buang',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text(
              'Simpan',
              style: GoogleFonts.poppins(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

    if (result == 'save') {
      await _saveAndPop();
    } else if (result == 'discard') {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _toggleLock() async {
    if (_isLocked) {
      if (!mounted) return;
      setState(() {
        _isLocked = false;
        _hasChanges = true;
      });

      _showSnackBar('Catatan berhasil dibuka kuncinya');
      return;
    }

    final hasPin = await SecurityService.hasPin();
    if (!hasPin) {
      if (!mounted) return;
      _showSnackBar('Atur PIN terlebih dahulu di Pengaturan');
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLocked = true;
      _hasChanges = true;
    });

    _showSnackBar('Catatan berhasil dikunci');
  }

  Future<void> _shareAsText() async {
    try {
      await ExportService.shareAsText(_buildCurrentNoteForExport());
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Gagal membagikan catatan');
    }
  }

  Future<void> _exportPdf() async {
    try {
      _showSnackBar('Menyiapkan PDF...', seconds: 30);
      await ExportService.sharePdf(_buildCurrentNoteForExport());
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSnackBar('Gagal export PDF');
    }
  }

  Future<void> _exportWord() async {
    try {
      _showSnackBar('Menyiapkan Word...', seconds: 30);
      await ExportService.shareWord(_buildCurrentNoteForExport());
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSnackBar('Gagal export Word');
    }
  }

  void _insertImageToEditor(String url) {
    final index = _quillController.selection.baseOffset;
    final safeIndex = index < 0 ? 0 : index;

    _quillController.replaceText(
      safeIndex,
      0,
      BlockEmbed.image(url),
      TextSelection.collapsed(offset: safeIndex + 1),
    );
    _quillController.replaceText(
      safeIndex + 1,
      0,
      '\n',
      TextSelection.collapsed(offset: safeIndex + 2),
    );

    setState(() => _hasChanges = true);
  }

  void _insertAudioToEditor(String filePath) {
    final index = _quillController.selection.baseOffset;
    final safeIndex = index < 0 ? 0 : index;

    _quillController.replaceText(
      safeIndex,
      0,
      BlockEmbed.custom(CustomBlockEmbed(_audioEmbedKey, filePath)),
      TextSelection.collapsed(offset: safeIndex + 1),
    );
    _quillController.replaceText(
      safeIndex + 1,
      0,
      '\n',
      TextSelection.collapsed(offset: safeIndex + 2),
    );

    setState(() => _hasChanges = true);
  }

  Future<File> _persistAudioLocally(String tempPath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final voiceDir = Directory('${docsDir.path}/voice_notes');

    if (!await voiceDir.exists()) {
      await voiceDir.create(recursive: true);
    }

    final savedPath =
        '${voiceDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    final sourceFile = File(tempPath);
    return sourceFile.copy(savedPath);
  }

  Future<void> _showVoiceRecorderSheet() async {
    final recorder = AudioRecorder();
    Timer? timer;
    String? recordPath;
    Duration elapsed = Duration.zero;

    bool isRecording = false;
    bool isPaused = false;
    bool isSavingAudio = false;
    bool hasRecordedFile = false;

    Future<void> startRecording(StateSetter setSheetState) async {
      final hasPermission = await recorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        _showSnackBar('Izin mikrofon belum diberikan');
        return;
      }

      final tempDir = await getTemporaryDirectory();
      recordPath =
          '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: recordPath!,
      );

      elapsed = Duration.zero;
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setSheetState(() {
          elapsed += const Duration(seconds: 1);
        });
      });

      setSheetState(() {
        isRecording = true;
        isPaused = false;
        hasRecordedFile = false;
      });
    }

    Future<void> pauseRecording(StateSetter setSheetState) async {
      await recorder.pause();
      timer?.cancel();
      setSheetState(() {
        isPaused = true;
      });
    }

    Future<void> resumeRecording(StateSetter setSheetState) async {
      await recorder.resume();
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setSheetState(() {
          elapsed += const Duration(seconds: 1);
        });
      });
      setSheetState(() {
        isPaused = false;
      });
    }

    Future<void> stopRecording(StateSetter setSheetState) async {
      final path = await recorder.stop();
      timer?.cancel();

      if (path != null) {
        recordPath = path;
      }

      setSheetState(() {
        isRecording = false;
        isPaused = false;
        hasRecordedFile = recordPath != null;
      });
    }

    Future<void> deleteRecording(StateSetter setSheetState) async {
      timer?.cancel();

      try {
        await recorder.cancel();
      } catch (_) {}

      if (recordPath != null) {
        final file = File(recordPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      setSheetState(() {
        recordPath = null;
        elapsed = Duration.zero;
        isRecording = false;
        isPaused = false;
        hasRecordedFile = false;
      });
    }

    Future<void> saveRecording(
      BuildContext sheetContext,
      StateSetter setSheetState,
    ) async {
      if (recordPath == null) return;

      setSheetState(() {
        isSavingAudio = true;
      });

      try {
        final savedFile = await _persistAudioLocally(recordPath!);
        _insertAudioToEditor(savedFile.path);

        final tempFile = File(recordPath!);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        timer?.cancel();
        await recorder.dispose();

        if (!sheetContext.mounted) return;
        Navigator.pop(sheetContext);
        _showSnackBar('Voice note berhasil disimpan');
      } catch (_) {
        if (!mounted) return;
        setSheetState(() {
          isSavingAudio = false;
        });
        _showSnackBar('Gagal menyimpan voice note');
      }
    }

    String formatDuration(Duration d) {
      final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 24),
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: AppColors.bg2(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary(context),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: AppColors.primary,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Voice Note',
                  style: GoogleFonts.poppins(
                    color: AppColors.text(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatDuration(elapsed),
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary(context),
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                if (!isRecording && !hasRecordedFile)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => startRecording(setSheetState),
                      icon: const Icon(Icons.fiber_manual_record),
                      label: const Text('Mulai Rekam'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (isRecording) ...[
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: isPaused
                                ? () => resumeRecording(setSheetState)
                                : () => pauseRecording(setSheetState),
                            icon: Icon(
                              isPaused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                            ),
                            label: Text(isPaused ? 'Lanjutkan' : 'Pause'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: () => stopRecording(setSheetState),
                            icon: const Icon(Icons.stop_rounded),
                            label: const Text('Stop'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (hasRecordedFile && !isRecording) ...[
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: isSavingAudio
                                ? null
                                : () => deleteRecording(setSheetState),
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Hapus'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: AppColors.primary.withValues(alpha: 0.7),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              foregroundColor: AppColors.primary,
                              textStyle: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: isSavingAudio
                                ? null
                                : () => saveRecording(sheetContext, setSheetState),
                            icon: isSavingAudio
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_rounded),
                            label: Text(isSavingAudio ? 'Menyimpan...' : 'Simpan'),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );

    timer?.cancel();
    await recorder.dispose();
  }

  void _showSnackBar(String message, {int seconds = 2}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        duration: Duration(seconds: seconds),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final bg2 = AppColors.bg2(context);
    final textColor = AppColors.text(context);

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          ListTile(
            leading: Icon(Icons.camera_alt_outlined, color: textColor),
            title: Text(
              'Ambil Foto',
              style: GoogleFonts.poppins(color: textColor),
            ),
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          ListTile(
            leading: Icon(Icons.photo_outlined, color: textColor),
            title: Text(
              'Pilih Foto',
              style: GoogleFonts.poppins(color: textColor),
            ),
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );

    if (result == null || !mounted) return;

    final XFile? image = result == 'camera'
        ? await picker.pickImage(source: ImageSource.camera, imageQuality: 70)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (image == null || !mounted) return;

    _showSnackBar('Memproses gambar...', seconds: 60);

    try {
      final bytes = await image.readAsBytes();
      final base64Str = base64Encode(bytes);
      final url = 'data:image/jpeg;base64,$base64Str';

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _insertImageToEditor(url);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showSnackBar('Gagal memproses gambar');
      }
    }
  }

  Future<void> _openDrawing() async {
    final Uint8List? imageBytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(builder: (_) => const DrawingScreen()),
    );

    if (imageBytes == null || !mounted) return;

    _showSnackBar('Memproses gambar...', seconds: 60);

    try {
      final base64Str = base64Encode(imageBytes);
      final url = 'data:image/png;base64,$base64Str';

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _insertImageToEditor(url);
        _showSnackBar('Gambar berhasil ditambahkan!');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showSnackBar('Gagal menyimpan gambar');
      }
    }
  }

  Future<bool> _confirmPermanentDelete() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bg2(context),
        title: Text(
          'Hapus Permanen?',
          style: GoogleFonts.poppins(
            color: AppColors.text(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Catatan ini akan dihapus permanen dan tidak bisa dipulihkan lagi.',
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary(context),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Hapus Permanen',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    return result == true;
  }

  void _showShareOptions() {
    final textColor = AppColors.text(context);
    final bg2 = AppColors.bg2(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (shareContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.text_snippet_outlined, color: textColor),
              title: Text(
                'Bagikan sebagai teks',
                style: GoogleFonts.poppins(color: textColor),
              ),
              onTap: () {
                Navigator.pop(shareContext);
                _shareAsText();
              },
            ),
            ListTile(
              leading: Icon(Icons.picture_as_pdf_outlined, color: textColor),
              title: Text(
                'Export PDF',
                style: GoogleFonts.poppins(color: textColor),
              ),
              onTap: () {
                Navigator.pop(shareContext);
                _exportPdf();
              },
            ),
            ListTile(
              leading: Icon(Icons.description_outlined, color: textColor),
              title: Text(
                'Export Word',
                style: GoogleFonts.poppins(color: textColor),
              ),
              onTap: () {
                Navigator.pop(shareContext);
                _exportWord();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showMoreMenu() {
    final noteProvider = context.read<NoteProvider>();
    final note = widget.note;
    final textColor = AppColors.text(context);
    final bg2 = AppColors.bg2(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.share_outlined, color: textColor),
                title: Text(
                  'Bagikan',
                  style: GoogleFonts.poppins(color: textColor),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showShareOptions();
                },
              ),
              ListTile(
                leading: Icon(
                  note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: AppColors.primary,
                ),
                title: Text(
                  note.isPinned ? 'Lepas Sematkan' : 'Sematkan',
                  style: GoogleFonts.poppins(color: textColor),
                ),
                onTap: () {
                  noteProvider.togglePin(note);
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                leading: Icon(
                  _isLocked ? Icons.lock_open_outlined : Icons.lock_outline,
                  color: textColor,
                ),
                title: Text(
                  _isLocked ? 'Buka Kunci' : 'Kunci',
                  style: GoogleFonts.poppins(color: textColor),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _toggleLock();
                },
              ),
              ListTile(
                leading: Icon(Icons.palette_outlined, color: textColor),
                title: Text(
                  'Warna Label',
                  style: GoogleFonts.poppins(color: textColor),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showColorPicker();
                },
              ),
              ListTile(
                leading: Icon(
                  widget.note.isDeleted
                      ? Icons.delete_forever
                      : Icons.delete_outline,
                  color: Colors.red,
                ),
                title: Text(
                  widget.note.isDeleted ? 'Hapus Permanen' : 'Hapus',
                  style: GoogleFonts.poppins(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);

                  if (widget.note.isDeleted) {
                    final confirmed = await _confirmPermanentDelete();
                    if (!confirmed) return;
                    await noteProvider.permanentDelete(widget.note.id);
                  } else {
                    await noteProvider.deleteNote(widget.note.id);
                  }

                  if (mounted) Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setBottomState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Warna Label',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(
                  AppColors.noteColors.length,
                  (i) => GestureDetector(
                    onTap: () {
                      setBottomState(() {});
                      setState(() {
                        _colorIndex = i;
                        _hasChanges = true;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.noteColors[i],
                        shape: BoxShape.circle,
                        border: _colorIndex == i
                            ? Border.all(color: AppColors.primary, width: 3)
                            : Border.all(color: Colors.grey.shade400, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _colorIndex == i
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageEmbed(String imageUrl) {
    return _Base64Image(
      key: ValueKey(imageUrl),
      base64Url: imageUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final textColor = _getTextColorForBg(context);
    final subColor = _colorIndex == 0
        ? AppColors.textSecondary(context)
        : textColor.withValues(alpha: 0.6);

    final backgroundColor = _colorIndex == 0
        ? Theme.of(context).scaffoldBackgroundColor
        : AppColors.noteColors[_colorIndex];

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: textColor),
            onPressed: _handleBack,
          ),
          title: Row(
            children: [
              Text(
                'Catatan',
                style: GoogleFonts.poppins(color: textColor, fontSize: 16),
              ),
              if (_isLocked) ...[
                const SizedBox(width: 8),
                Icon(Icons.lock, color: textColor, size: 18),
              ],
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.undo, color: textColor),
              onPressed: () => _quillController.undo(),
            ),
            IconButton(
              icon: Icon(Icons.redo, color: textColor),
              onPressed: () => _quillController.redo(),
            ),
            IconButton(
              icon: Icon(Icons.more_vert, color: textColor),
              onPressed: _showMoreMenu,
            ),
            IconButton(
              icon: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: textColor,
                      ),
                    )
                  : Icon(Icons.check, color: textColor),
              onPressed: _saveAndPop,
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: TextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                decoration: InputDecoration(
                  hintText: 'Judul',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: subColor,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                onSubmitted: (_) => _editorFocusNode.requestFocus(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: QuillEditor(
                  controller: _quillController,
                  focusNode: _editorFocusNode,
                  scrollController: _scrollController,
                  config: QuillEditorConfig(
                    placeholder: 'Catat sesuatu...',
                    expands: true,
                    padding: EdgeInsets.zero,
                    embedBuilders: [
                      _ImageEmbedBuilder(
                        buildImage: _buildImageEmbed,
                        onImageEdit: (oldUrl, newBytes) {
                          final base64Str = base64Encode(newBytes);
                          final newUrl = 'data:image/png;base64,$base64Str';
                          final doc = _quillController.document;
                          final delta = doc.toDelta();
                          var offset = 0;

                          for (final op in delta.toList()) {
                            if (op.data is Map) {
                              final data = op.data as Map;
                              if (data['image'] == oldUrl) {
                                _quillController.replaceText(
                                  offset,
                                  1,
                                  BlockEmbed.image(newUrl),
                                  null,
                                );
                                setState(() => _hasChanges = true);
                                break;
                              }
                            }

                            if (op.data is String) {
                              offset += (op.data as String).length;
                            } else {
                              offset += 1;
                            }
                          }
                        },
                      ),
                      _AudioEmbedBuilder(keyName: _audioEmbedKey),
                    ],
                    customStyles: DefaultStyles(
                      placeHolder: DefaultTextBlockStyle(
                        GoogleFonts.poppins(fontSize: 15, color: subColor),
                        HorizontalSpacing.zero,
                        VerticalSpacing.zero,
                        VerticalSpacing.zero,
                        null,
                      ),
                      paragraph: DefaultTextBlockStyle(
                        GoogleFonts.poppins(fontSize: 15, color: textColor),
                        HorizontalSpacing.zero,
                        VerticalSpacing.zero,
                        VerticalSpacing.zero,
                        null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            RichToolbar(
              controller: _quillController,
              isDark: isDark,
              onImageTap: _pickImage,
              onDrawTap: _openDrawing,
              onVoiceTap: _showVoiceRecorderSheet,
            ),
          ],
        ),
      ),
    );
  }
}

class _Base64Image extends StatefulWidget {
  final String base64Url;

  const _Base64Image({
    super.key,
    required this.base64Url,
  });

  @override
  State<_Base64Image> createState() => _Base64ImageState();
}

class _Base64ImageState extends State<_Base64Image> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant _Base64Image oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.base64Url != widget.base64Url) {
      _decode();
    }
  }

  void _decode() {
    try {
      final base64Data = widget.base64Url.split(',').last;
      _bytes = base64Decode(base64Data);
    } catch (_) {
      _bytes = null;
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) {
      return Container(
        height: 100,
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          _bytes!,
          fit: BoxFit.fitWidth,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

class _ImageEmbedBuilder extends EmbedBuilder {
  final Widget Function(String url) buildImage;
  final Function(String oldUrl, Uint8List newBytes)? onImageEdit;

  _ImageEmbedBuilder({
    required this.buildImage,
    this.onImageEdit,
  });

  @override
  String get key => BlockEmbed.imageType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final imageUrl = embedContext.node.value.data as String;

    return GestureDetector(
      onTap: () async {
        final action = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: Text(
              'Gambar',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: Text(
                  'Batal',
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'edit'),
                child: Text(
                  'Edit Gambar',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFFC107),
                  ),
                ),
              ),
            ],
          ),
        );

        if (action == 'edit' && context.mounted) {
          Uint8List? initialBytes;

          if (imageUrl.startsWith('data:image')) {
            try {
              final base64Data = imageUrl.split(',').last;
              initialBytes = base64Decode(base64Data);
            } catch (_) {
              initialBytes = null;
            }
          }

          if (context.mounted) {
            final newBytes = await Navigator.push<Uint8List>(
              context,
              MaterialPageRoute(
                builder: (_) => DrawingScreen(initialBytes: initialBytes),
              ),
            );

            if (newBytes != null) {
              onImageEdit?.call(imageUrl, newBytes);
            }
          }
        }
      },
      child: buildImage(imageUrl),
    );
  }
}

class _AudioEmbedBuilder extends EmbedBuilder {
  final String keyName;

  _AudioEmbedBuilder({required this.keyName});

  @override
  String get key => keyName;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final audioPath = embedContext.node.value.data as String;
    return _AudioPlayerCard(audioPath: audioPath);
  }
}

class _AudioPlayerCard extends StatefulWidget {
  final String audioPath;

  const _AudioPlayerCard({required this.audioPath});

  @override
  State<_AudioPlayerCard> createState() => _AudioPlayerCardState();
}

class _AudioPlayerCardState extends State<_AudioPlayerCard> {
  late final AudioPlayer _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  PlayerState _state = PlayerState.stopped;

  bool get _isPlaying => _state == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _state = PlayerState.stopped;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      return;
    }

    if (widget.audioPath.startsWith('http://') ||
        widget.audioPath.startsWith('https://')) {
      await _player.play(UrlSource(widget.audioPath));
    } else {
      await _player.play(DeviceFileSource(widget.audioPath));
    }
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final subColor = AppColors.textSecondary(context);

    final maxMs = _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 1;
    final valueMs = _position.inMilliseconds.clamp(0, maxMs);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: _togglePlay,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice Note',
                      style: GoogleFonts.poppins(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_format(_position)} / ${_format(_duration)}',
                      style: GoogleFonts.poppins(
                        color: subColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Slider(
            value: valueMs.toDouble(),
            max: maxMs.toDouble(),
            onChanged: (value) async {
              await _player.seek(Duration(milliseconds: value.round()));
            },
          ),
        ],
      ),
    );
  }
}