import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class DrawingScreen extends StatefulWidget {
  final Uint8List? initialBytes; // tambahkan ini
  const DrawingScreen({super.key, this.initialBytes});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingPoint {
  final Offset offset;
  final Paint paint;
  _DrawingPoint(this.offset, this.paint);
}

class _DrawingScreenState extends State<DrawingScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final List<List<_DrawingPoint?>> _strokes = [];
  List<_DrawingPoint?> _currentStroke = [];
  final List<List<_DrawingPoint?>> _undoStack = [];

  Color _currentColor = Colors.black;
  double _strokeWidth = 3.0;
  int _selectedTool = 0;
  ui.Image? _backgroundImage;
  bool _loadingBackground = false;

  final List<Map<String, dynamic>> _tools = [
    {'icon': Icons.edit, 'label': 'Pena'},
    {'icon': Icons.brush, 'label': 'Marker'},
    {'icon': Icons.auto_fix_high, 'label': 'Hapus'},
  ];

  final List<Color> _colors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.brown,
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialBytes != null) {
      _loadBackgroundImage(widget.initialBytes!);
    }
  }

  Future<void> _loadBackgroundImage(Uint8List bytes) async {
    setState(() => _loadingBackground = true);
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      setState(() {
        _backgroundImage = frame.image;
        _loadingBackground = false;
      });
    } catch (e) {
      setState(() => _loadingBackground = false);
    }
  }

  Paint get _currentPaint {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (_selectedTool == 2) {
      paint.color = Colors.white;
      paint.strokeWidth = _strokeWidth * 4;
    } else if (_selectedTool == 1) {
      paint.color = _currentColor.withValues(alpha: 0.4);
      paint.strokeWidth = _strokeWidth * 3;
    } else {
      paint.color = _currentColor;
      paint.strokeWidth = _strokeWidth;
    }
    return paint;
  }

  double get _previewSize {
    if (_selectedTool == 2) return (_strokeWidth * 4).clamp(4, 52);
    if (_selectedTool == 1) return (_strokeWidth * 3).clamp(4, 52);
    return _strokeWidth.clamp(1, 52);
  }

  Color get _previewColor {
    if (_selectedTool == 2) return Colors.grey.shade400;
    if (_selectedTool == 1) return _currentColor.withValues(alpha: 0.4);
    return _currentColor;
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _undoStack.add(_strokes.removeLast()));
  }

  void _redo() {
    if (_undoStack.isEmpty) return;
    setState(() => _strokes.add(_undoStack.removeLast()));
  }

  void _clear() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgDark2,
        title: Text('Bersihkan canvas?',
            style: GoogleFonts.poppins(color: Colors.white)),
        content: Text('Semua gambar akan dihapus.',
            style: GoogleFonts.poppins(
                color: Colors.grey, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal',
                style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _strokes.clear();
                _undoStack.clear();
                _backgroundImage = null;
              });
              Navigator.pop(context);
            },
            child: Text('Hapus',
                style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDrawing() async {
    if (_strokes.isEmpty && _backgroundImage == null) {
      Navigator.pop(context);
      return;
    }

    try {
      final boundary = _canvasKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        Navigator.pop(context);
        return;
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();

      if (bytes != null && mounted) {
        Navigator.pop(context, bytes);
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving drawing: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.initialBytes != null ? 'Edit Gambar' : 'Catatan',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            onPressed: _undo,
          ),
          IconButton(
            icon: const Icon(Icons.redo, color: Colors.white),
            onPressed: _redo,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _clear,
          ),
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: _saveDrawing,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loadingBackground
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      RepaintBoundary(
                        key: _canvasKey,
                        child: GestureDetector(
                          onPanStart: (details) {
                            setState(() {
                              _currentStroke = [
                                _DrawingPoint(details.localPosition,
                                    _currentPaint)
                              ];
                              _undoStack.clear();
                            });
                          },
                          onPanUpdate: (details) {
                            setState(() {
                              _currentStroke.add(_DrawingPoint(
                                  details.localPosition,
                                  _currentPaint));
                            });
                          },
                          onPanEnd: (details) {
                            setState(() {
                              _strokes.add(List.from(_currentStroke));
                              _currentStroke = [];
                            });
                          },
                          child: Container(
                            color: Colors.white,
                            child: CustomPaint(
                              painter: _DrawingPainter(
                                strokes: _strokes,
                                currentStroke: _currentStroke,
                                backgroundImage: _backgroundImage,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                      // Preview ukuran pena
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: Colors.grey.shade300),
                          ),
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              width: _previewSize,
                              height: _previewSize,
                              decoration: BoxDecoration(
                                color: _previewColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          Container(
            color: AppColors.bgDark2,
            padding: const EdgeInsets.symmetric(
                vertical: 8, horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _colors.map((color) {
                    final isSelected = _currentColor == color;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _currentColor = color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin:
                            const EdgeInsets.symmetric(horizontal: 4),
                        width: isSelected ? 28 : 22,
                        height: isSelected ? 28 : 22,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.primary, width: 2.5)
                              : Border.all(
                                  color: Colors.white24, width: 1),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    _tools.length,
                    (i) => GestureDetector(
                      onTap: () =>
                          setState(() => _selectedTool = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTool == i
                              ? AppColors.primary
                                  .withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: _selectedTool == i
                              ? Border.all(color: AppColors.primary)
                              : Border.all(
                                  color: Colors.transparent),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _tools[i]['icon'] as IconData,
                              color: _selectedTool == i
                                  ? AppColors.primary
                                  : Colors.white70,
                              size: 22,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _tools[i]['label'] as String,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: _selectedTool == i
                                    ? AppColors.primary
                                    : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.line_weight,
                        color: Colors.white70, size: 18),
                    Expanded(
                      child: Slider(
                        value: _strokeWidth,
                        min: 1,
                        max: 20,
                        divisions: 19,
                        activeColor: AppColors.primary,
                        inactiveColor: Colors.grey,
                        onChanged: (val) =>
                            setState(() => _strokeWidth = val),
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${_strokeWidth.toInt()}px',
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<List<_DrawingPoint?>> strokes;
  final List<_DrawingPoint?> currentStroke;
  final ui.Image? backgroundImage;

  _DrawingPainter({
    required this.strokes,
    required this.currentStroke,
    this.backgroundImage,
  });

  void _drawStroke(Canvas canvas, List<_DrawingPoint?> stroke) {
    for (int i = 0; i < stroke.length - 1; i++) {
      final p1 = stroke[i];
      final p2 = stroke[i + 1];
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1.offset, p2.offset, p1.paint);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Gambar background image kalau ada
    if (backgroundImage != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        backgroundImage!.width.toDouble(),
        backgroundImage!.height.toDouble(),
      );
      final dst = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(backgroundImage!, src, dst, Paint());
    }

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }
    _drawStroke(canvas, currentStroke);
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}