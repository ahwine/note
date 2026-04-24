import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../constants/app_colors.dart';

class RichToolbar extends StatefulWidget {
  final QuillController controller;
  final bool isDark;

  // Kompatibilitas dengan pemanggilan lama
  final Future<void> Function()? onImageTap;
  final VoidCallback? onVoiceTap;
  final VoidCallback? onDrawTap;
  final VoidCallback? onDrawingTap;
  final VoidCallback? onChecklistTap;

  const RichToolbar({
    super.key,
    required this.controller,
    this.isDark = false,
    this.onImageTap,
    this.onVoiceTap,
    this.onDrawTap,
    this.onDrawingTap,
    this.onChecklistTap,
  });

  @override
  State<RichToolbar> createState() => _RichToolbarState();
}

class _RichToolbarState extends State<RichToolbar> {
  late Map<String, Attribute> _attrs;
  StreamSubscription? _sub;

  VoidCallback? get _effectiveDrawTap =>
      widget.onDrawTap ?? widget.onDrawingTap;

  Color get _defaultForeground =>
      widget.isDark ? Colors.white70 : const Color(0xFF1C1B1A);

  @override
  void initState() {
    super.initState();
    _attrs = widget.controller.getSelectionStyle().attributes;
    _sub = widget.controller.changes.listen((_) {
      if (!mounted) return;
      setState(() {
        _attrs = widget.controller.getSelectionStyle().attributes;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  bool _hasAttr(Attribute attribute) => _attrs.containsKey(attribute.key);

  bool get _isBold => _hasAttr(Attribute.bold);
  bool get _isItalic => _hasAttr(Attribute.italic);
  bool get _isUnderline => _hasAttr(Attribute.underline);
  bool get _isStrike => _hasAttr(Attribute.strikeThrough);

  bool get _isBullet =>
      _attrs[Attribute.list.key]?.value == Attribute.ul.value;

  bool get _isNumbered =>
      _attrs[Attribute.list.key]?.value == Attribute.ol.value;

  bool get _isChecked =>
      _attrs[Attribute.list.key]?.value == Attribute.checked.value;

  void _refreshAttrs() {
    if (!mounted) return;
    setState(() {
      _attrs = widget.controller.getSelectionStyle().attributes;
    });
  }

  void _toggleInline(Attribute attribute, bool active) {
    widget.controller.formatSelection(
      active ? Attribute.clone(attribute, null) : attribute,
    );
    _refreshAttrs();
  }

  void _toggleList(Attribute attribute, bool active) {
    widget.controller.formatSelection(
      active ? Attribute.clone(Attribute.list, null) : attribute,
    );
    _refreshAttrs();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.bgDark2 : AppColors.bgLight2,
        border: Border(
          top: BorderSide(
            color: widget.isDark
                ? Colors.white.withOpacity(.08)
                : Colors.black.withOpacity(.06),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _formatButton(
              icon: Icons.format_bold_rounded,
              active: _isBold,
              onTap: () => _toggleInline(Attribute.bold, _isBold),
            ),
            _formatButton(
              icon: Icons.format_italic_rounded,
              active: _isItalic,
              onTap: () => _toggleInline(Attribute.italic, _isItalic),
            ),
            _formatButton(
              icon: Icons.format_underlined_rounded,
              active: _isUnderline,
              onTap: () => _toggleInline(Attribute.underline, _isUnderline),
            ),
            _formatButton(
              icon: Icons.format_strikethrough_rounded,
              active: _isStrike,
              onTap: () =>
                  _toggleInline(Attribute.strikeThrough, _isStrike),
            ),
            const SizedBox(width: 6),
            _formatButton(
              icon: Icons.format_list_bulleted_rounded,
              active: _isBullet,
              onTap: () => _toggleList(Attribute.ul, _isBullet),
            ),
            _formatButton(
              icon: Icons.format_list_numbered_rounded,
              active: _isNumbered,
              onTap: () => _toggleList(Attribute.ol, _isNumbered),
            ),
            _formatButton(
              icon: Icons.checklist_rounded,
              active: _isChecked,
              onTap: () => _toggleList(Attribute.checked, _isChecked),
            ),
            const SizedBox(width: 6),
            if (widget.onImageTap != null)
              _actionButton(
                icon: Icons.image_outlined,
                onTap: () async {
                  await widget.onImageTap!.call();
                  _refreshAttrs();
                },
              ),
            if (_effectiveDrawTap != null)
              _actionButton(
                icon: Icons.draw_outlined,
                onTap: _effectiveDrawTap,
              ),
            if (widget.onVoiceTap != null)
              _actionButton(
                icon: Icons.mic_none_rounded,
                onTap: widget.onVoiceTap,
              ),
          ],
        ),
      ),
    );
  }

  Widget _formatButton({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor:
          active ? AppColors.primary.withOpacity(.22) : Colors.transparent,
          foregroundColor: active ? AppColors.primary : _defaultForeground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        onPressed: onTap,
        style: IconButton.styleFrom(
          foregroundColor: _defaultForeground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon),
      ),
    );
  }
}