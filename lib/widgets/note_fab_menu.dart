import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class NoteFabMenu extends StatefulWidget {
  final VoidCallback onText;
  final VoidCallback onImage;
  final VoidCallback onDrawing;
  final VoidCallback onAudio;

  const NoteFabMenu({
    super.key,
    required this.onText,
    required this.onImage,
    required this.onDrawing,
    required this.onAudio,
  });

  @override
  State<NoteFabMenu> createState() => _NoteFabMenuState();
}

class _NoteFabMenuState extends State<NoteFabMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expand;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _expand = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  Future<void> _run(VoidCallback action) async {
    if (_open) {
      setState(() => _open = false);
      await _controller.reverse();
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_open,
              child: GestureDetector(
                onTap: _toggle,
                child: AnimatedOpacity(
                  opacity: _open ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expand,
            axisAlignment: 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _FabActionPill(
                  icon: Icons.mic_rounded,
                  label: 'Audio',
                  onTap: () => _run(widget.onAudio),
                ),
                const SizedBox(height: 10),
                _FabActionPill(
                  icon: Icons.image_outlined,
                  label: 'Image',
                  onTap: () => _run(widget.onImage),
                ),
                const SizedBox(height: 10),
                _FabActionPill(
                  icon: Icons.brush_outlined,
                  label: 'Drawing',
                  onTap: () => _run(widget.onDrawing),
                ),
                const SizedBox(height: 10),
                _FabActionPill(
                  icon: Icons.notes_rounded,
                  label: 'Text',
                  onTap: () => _run(widget.onText),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          FloatingActionButton(
            heroTag: 'note-fab-main',
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            onPressed: _toggle,
            child: AnimatedRotation(
              turns: _open ? 0.125 : 0,
              duration: const Duration(milliseconds: 220),
              child: Icon(_open ? Icons.close : Icons.add, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _FabActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FabActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(26),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 21),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
